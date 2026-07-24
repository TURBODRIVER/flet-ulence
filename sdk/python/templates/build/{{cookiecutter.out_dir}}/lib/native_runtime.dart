// Native-only embedded-Python runtime: PythonBridge transport,
// SeriousPython.runProgram, exit-bridge wiring.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flet/flet.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:serious_python/bridge.dart';
import 'package:serious_python/serious_python.dart';

import 'python.dart';

// In production (embedded) mode the Flet protocol flows over an in-process
// PythonBridge — no socket file, no TCP. `_exitBridge` is a separate bridge
// dedicated to Python's exit-code transmission (replaces the legacy stdout-
// callback socket). Both stay null until [initBridges] runs.
PythonBridge? _bridge;
PythonBridge? _exitBridge;

/// Allocate the protocol + exit bridges, stamp the required env vars onto
/// [envVars], and return the `dartbridge://<port>` page URL.
///
/// Also fires `dart_bridge_signal_dart_session` unconditionally. On a fresh
/// start where libdart_bridge hasn't initialized Python yet, the call is a
/// cheap no-op inside the C library.
String initBridges(Map<String, String> envVars) {
  _bridge = PythonBridge();
  _exitBridge = PythonBridge();

  // Signal the running Python (if any) about the new Dart native ports.
  // The labels here match what `serious_python_run` reconstructs from
  // env vars on its own reuse path — keep in sync.
  DartBridge.instance.signalDartSession({
    "protocol": _bridge!.port,
    "exit": _exitBridge!.port,
  });

  envVars.putIfAbsent("FLET_DART_BRIDGE_PORT", () => _bridge!.port.toString());
  envVars.putIfAbsent(
    "FLET_DART_BRIDGE_EXIT_PORT",
    () => _exitBridge!.port.toString(),
  );
  return "dartbridge://${_bridge!.port}";
}

bool get bridgesActive => _bridge != null;

/// True when libdart_bridge already has an embedded CPython up from a
/// previous Dart VM in the same OS process.
bool get pythonAlreadyRunning => DartBridge.instance.isPythonInitialized;

/// Wraps `SeriousPython.prepareApp()` so main.dart doesn't have to import the
/// FFI-touching package directly.
Future<String> getAppDir() => SeriousPython.prepareApp();

/// FletApp's `channelBuilder` for the embedded-Python protocol — wraps the
/// in-process [PythonBridge] in a [FletBackendChannel]. Returns null until
/// [initBridges] has run.
FletBackendChannelBuilder? get channelBuilder => _bridge == null
    ? null
    : ({
        required FletBackendChannelOnPacketCallback onPacket,
        required FletBackendChannelOnDisconnectCallback onDisconnect,
      }) => _DartBridgeBackendChannel(
        _bridge!,
        onPacket: onPacket,
        onDisconnect: onDisconnect,
      );

/// FletApp's `dataChannelFactory` for high-throughput byte channels —
/// each `open()` mints a fresh [PythonBridge] (dedicated native port).
DataChannelFactory? get dataChannelFactory => _PythonBridgeDataChannelFactory();

/// Boot the embedded interpreter and wait for it to exit. Returns the
/// captured console output on error exit; calls `exit(code)` directly on
/// normal exit codes.
Future<String?> runPython({
  required String moduleName,
  required String appDir,
  required String outLogFilename,
  required Map<String, String> environmentVariables,
  required List<String> args,
}) async {
  // JSON literals are valid Python literals, so every dynamic value is
  // spliced into the boot script through jsonEncode: it correctly escapes
  // backslashes (Windows paths), quotes, and non-ASCII.
  var script = pythonScript
      .replaceAll('{outLogFilename}', jsonEncode(outLogFilename))
      .replaceAll('{module_name}', jsonEncode(moduleName))
      .replaceAll('{argv}', jsonEncode(args.isNotEmpty ? args : [""]))
      .replaceAll('{host_executable}', jsonEncode(Platform.resolvedExecutable));

  var completer = Completer<String>();

  // Subscribe to the exit-code bridge. Python's `sys.exit(code)` is patched
  // (in python.dart) to encode `code` as raw UTF-8 bytes and post them via
  // `dart_bridge.send_bytes(FLET_DART_BRIDGE_EXIT_PORT, ...)`. We don't need
  // a streaming codec here — the channel only ever carries a single short
  // payload, then Python tears down.
  StringBuffer pythonExitBuf = StringBuffer();
  StreamSubscription<Uint8List>? exitSub;

  void onExitSignal() async {
    await exitSub?.cancel();
    int exitCode = int.tryParse(pythonExitBuf.toString().trim()) ?? 0;
    if (exitCode == errorExitCode) {
      var out = "";
      if (await File(outLogFilename).exists()) {
        out = await File(outLogFilename).readAsString();
      }
      completer.complete(out);
    } else {
      exit(exitCode);
    }
  }

  exitSub = _exitBridge!.messages.listen(
    (data) {
      pythonExitBuf.write(String.fromCharCodes(data));
      onExitSignal();
    },
    onError: (error) {
      debugPrint('Exit bridge error: $error');
      onExitSignal();
    },
    onDone: onExitSignal,
    cancelOnError: false,
  );

  SeriousPython.runProgram(
    path.join(appDir, "$moduleName.pyc"),
    script: script,
    environmentVariables: environmentVariables,
  );

  return completer.future;
}

/// `FletBackendChannel` implementation backed by a [PythonBridge]. Bytes
/// flow Dart↔Python entirely in-process; no Unix socket, no kernel context
/// switch. Each PythonBridge `send` is one complete packet on the wire —
/// `[type:u8][payload]`. No framing layer needed (the bridge preserves
/// message boundaries).
class _DartBridgeBackendChannel implements FletBackendChannel {
  _DartBridgeBackendChannel(
    this._bridge, {
    required FletBackendChannelOnPacketCallback onPacket,
    required FletBackendChannelOnDisconnectCallback onDisconnect,
  }) : _onPacket = onPacket,
       _onDisconnect = onDisconnect;

  final PythonBridge _bridge;
  final FletBackendChannelOnPacketCallback _onPacket;
  final FletBackendChannelOnDisconnectCallback _onDisconnect;
  StreamSubscription<Uint8List>? _subscription;

  @override
  Future connect() async {
    _subscription = _bridge.messages.listen(
      _onPacket,
      onError: (error, stack) {
        debugPrint("PythonBridge stream error: $error");
        _onDisconnect();
      },
      onDone: () {
        debugPrint("PythonBridge stream closed.");
        _onDisconnect();
      },
      cancelOnError: false,
    );
  }

  @override
  void send(Uint8List packet) {
    // Retry loop covers the brief startup window where Python hasn't yet
    // called `dart_bridge.set_enqueue_handler_func` — bridge.send returns
    // false in that case. Once Flet's app.py registers the handler (which
    // happens before `runpy.run_module` is dispatched), bridge.send returns
    // true synchronously.
    if (_bridge.send(packet)) return;
    _retrySend(packet);
  }

  void _retrySend(Uint8List packet) {
    const interval = Duration(milliseconds: 50);
    const deadline = Duration(seconds: 30);
    final start = DateTime.now();
    Timer.periodic(interval, (timer) {
      if (_bridge.send(packet)) {
        timer.cancel();
      } else if (DateTime.now().difference(start) > deadline) {
        timer.cancel();
        debugPrint(
          "PythonBridge send timed out: Python handler never registered.",
        );
      }
    });
  }

  @override
  bool get isLocalConnection => true;

  @override
  int get defaultReconnectIntervalMs => 0;

  @override
  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// [DataChannel] backed by a dedicated [PythonBridge] — fast path for
/// embedded native mode. Each open() mints a fresh bridge with its own
/// native port; the bridge's `port` becomes the channel id we propagate
/// to Python (via the widget's `data_channel_open` event).
class _PythonBridgeDataChannel implements DataChannel {
  _PythonBridgeDataChannel(this._bridge);
  final PythonBridge _bridge;
  bool _closed = false;

  @override
  int get id => _bridge.port;

  @override
  Stream<Uint8List> get messages => _bridge.messages;

  @override
  bool send(Uint8List bytes) {
    if (_closed) return false;
    return _bridge.send(bytes);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _bridge.close();
  }
}

class _PythonBridgeDataChannelFactory implements DataChannelFactory {
  @override
  DataChannel open() => _PythonBridgeDataChannel(PythonBridge());
}
