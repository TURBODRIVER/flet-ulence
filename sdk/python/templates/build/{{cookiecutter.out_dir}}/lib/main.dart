import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flet/flet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:serious_python/serious_python.dart';
import 'package:window_manager/window_manager.dart';

import "python.dart";

{% for dep in cookiecutter.flutter.dependencies %}
import 'package:{{ dep }}/{{ dep }}.dart' as {{ dep }};
{% endfor %}

/*
{% set python_asset_path = get_pyproject("tool.flet." ~ cookiecutter.options.config_platform ~ ".app.asset_path")
                        or get_pyproject("tool.flet.app.asset_path") %}
{% set boot_screen_message = get_pyproject("tool.flet." ~ cookiecutter.options.config_platform ~ ".app.boot_screen.message")
                        or get_pyproject("tool.flet.app.boot_screen.message") %}
{% set hide_window_on_start = get_pyproject("tool.flet." ~ cookiecutter.options.config_platform ~ ".app.hide_window_on_start")
                        or get_pyproject("tool.flet.app.hide_window_on_start") %}

python_asset_path : {{ python_asset_path }}
boot_screen_message: {{ boot_screen_message }}
hide_window_on_start: {{ hide_window_on_start }}
*/

const bool isRelease = bool.fromEnvironment('dart.vm.product');

const assetPath = '{{ python_asset_path | default("app/app.zip", true) }}';
const pythonModuleName = "{{ cookiecutter.python_module_name }}";
const appBootScreenMessage = '{{ boot_screen_message | default("Preparing the App...", true) }}';
final hideWindowOnStart = bool.tryParse("{{ hide_window_on_start }}".toLowerCase()) ?? false;

List<FletExtension> extensions = [
{% for dep in cookiecutter.flutter.dependencies %}
{{ dep }}.Extension(),
{% endfor %}
];

String outLogFilename = "";

// global vars
List<String> _args = [];
String pageUrl = "";
String assetsDir = "";
String appDir = "";
Map<String, String> environmentVariables = Map.from(Platform.environment);

void main(List<String> args) async {

  _args = List<String>.from(args);

  for (var ext in extensions) {
    ext.ensureInitialized();
  }

  // TODO: Add project toml variables for base theme
  // TODO: Add project toml variable to force theme mode

  final ThemeData _appBaseTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFFFFFF),
    cardColor: const Color(0xFFFFFFFF),
    colorScheme: const ColorScheme.light(
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF797876),
      primary: Color(0xFF142AFA),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF142AFA),
    ),
    textTheme: const TextTheme(
      bodySmall: TextStyle(color: Color(0xFF797876)),
      bodyMedium: TextStyle(color: Color(0xFF797876)),
    ),
  );

  // TODO: Add project toml variables for light theme
  // TODO: Add project toml variables for dark theme

  runApp(Theme(
    data: _appBaseTheme,
    child: MaterialApp(
      theme: _appBaseTheme,
      darkTheme: _appBaseTheme,
      themeMode: ThemeMode.light,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            platformBrightness: Brightness.light,
          ),
          child: child!,
        );
      },
      home: FutureBuilder(
        future: prepareApp(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData) {
            return _PythonAppLoader(args: _args.cast<String>());
          } else if (snapshot.hasError) {
            return ErrorScreen(
                title: "Error starting app",
                text: snapshot.error.toString()
            );
          } else {
            return BootScreen();
          }
        }
      ),
    ),
  ));

}

class _PythonAppLoader extends StatefulWidget {
  final List<String> args;
  const _PythonAppLoader({required this.args});

  @override
  State<_PythonAppLoader> createState() => _PythonAppLoaderState();
}

class _PythonAppLoaderState extends State<_PythonAppLoader> {
  late final Future<String?> _pythonFuture;
  bool _showFlet = false;

  @override
  void initState() {
    super.initState();
    _pythonFuture = runPythonApp(widget.args).then((result) {
      return result;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showFlet = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _pythonFuture,
      builder: (context, snapshot) {

        if (snapshot.hasData || snapshot.hasError) {
          return ErrorScreen(
            title: "Error running app",
            text: snapshot.data ?? snapshot.error.toString(),
          );
        }

        if (_showFlet) {
          return FletApp(
            pageUrl: pageUrl,
            assetsDir: assetsDir,
            extensions: extensions,
          );
        }

        return const BootScreen();
      },
    );
  }
}

Future prepareApp() async {
  if (!_args.contains("--debug") && isRelease) {
    // ignore: avoid_returning_null_for_void
    debugPrint = (String? message, {int? wrapWidth}) => null;
  } else {
    _args.remove("--debug");
  }

  await setupDesktop(hideWindowOnStart: hideWindowOnStart);

  if (_args.isNotEmpty && isDesktopPlatform()) {
    // developer mode
    debugPrint("Flet app is running in Developer mode");
    pageUrl = _args[0];
    if (_args.length > 1) {
      var pidFilePath = _args[1];
      debugPrint("Args contain a path to PID file: $pidFilePath}");
      var pidFile = await File(pidFilePath).create();
      await pidFile.writeAsString("$pid");
    }
    if (_args.length > 2) {
      assetsDir = _args[2];
      debugPrint("Args contain a path assets directory: $assetsDir}");
    }
  } else {
    // production mode
    // extract app from asset
    final supportDir = await path_provider.getApplicationSupportDirectory();
    final targetPath = Directory(path.normalize(path.join(supportDir.path, 'flet'))).path;
    appDir = await extractAssetZip(assetPath, targetPath: targetPath, checkHash: true);

    // set current directory to app path
    Directory.current = appDir;

    assetsDir = path.join(appDir, "assets");

    // configure apps DATA and TEMP directories
    WidgetsFlutterBinding.ensureInitialized();

    environmentVariables.putIfAbsent("FLET_APP_STORAGE_DATA", () => appDir);
    environmentVariables.putIfAbsent("FLET_APP_STORAGE_TEMP", () => appDir);

    outLogFilename = path.join(appDir, "console.log");
    environmentVariables.putIfAbsent("FLET_APP_CONSOLE", () => outLogFilename);

    environmentVariables.putIfAbsent(
        "FLET_PLATFORM", () => defaultTargetPlatform.name.toLowerCase());

    if (defaultTargetPlatform == TargetPlatform.windows) {
      // use TCP on Windows
      var tcpPort = await getUnusedPort();
      pageUrl = "tcp://localhost:$tcpPort";
      environmentVariables.putIfAbsent("FLET_SERVER_PORT", () => tcpPort.toString());
    } else {
      // use UDS on other platforms
      pageUrl = "flet_$pid.sock";
      environmentVariables.putIfAbsent("FLET_SERVER_UDS_PATH", () => pageUrl);
    }
  }

  if (assetsDir.isNotEmpty) {
    environmentVariables.putIfAbsent("FLET_ASSETS_DIR", () => assetsDir);
  }

  return "";
}

Future<String?> runPythonApp(List<String> args) async {
  var argvItems = args.map((a) => "\"${a.replaceAll('"', '\\"')}\"");
  var argv = "[${argvItems.isNotEmpty ? argvItems.join(',') : '""'}]";
  var script = pythonScript
      .replaceAll("{outLogFilename}", outLogFilename.replaceAll("\\", "\\\\"))
      .replaceAll('{module_name}', pythonModuleName)
      .replaceAll('{argv}', argv);

  var completer = Completer<String>();

  ServerSocket outSocketServer;
  String socketAddr = "";
  StringBuffer pythonOut = StringBuffer();

  if (defaultTargetPlatform == TargetPlatform.windows) {
    var tcpAddr = "127.0.0.1";
    outSocketServer = await ServerSocket.bind(tcpAddr, 0);
    debugPrint(
        'Python output TCP Server is listening on port ${outSocketServer.port}');
    socketAddr = "$tcpAddr:${outSocketServer.port}";
  } else {
    socketAddr = "stdout_$pid.sock";
    if (await File(socketAddr).exists()) {
      await File(socketAddr).delete();
    }
    outSocketServer = await ServerSocket.bind(
        InternetAddress(socketAddr, type: InternetAddressType.unix), 0);
    debugPrint('Python output Socket Server is listening on $socketAddr');
  }

  environmentVariables.putIfAbsent("FLET_PYTHON_CALLBACK_SOCKET_ADDR", () => socketAddr);

  void closeOutServer() async {
    outSocketServer.close();

    int exitCode = int.tryParse(pythonOut.toString().trim()) ?? 0;

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

  outSocketServer.listen((client) {
    debugPrint(
        'Connection from: ${client.remoteAddress.address}:${client.remotePort}');
    client.listen((data) {
      var s = String.fromCharCodes(data);
      pythonOut.write(s);
    }, onError: (error) {
      client.close();
      closeOutServer();
    }, onDone: () {
      client.close();
      closeOutServer();
    });
  });

  // run python async
  SeriousPython.runProgram(path.join(appDir, "$pythonModuleName.pyc"),
      script: script, environmentVariables: environmentVariables);

  // wait for client connection to close
  return completer.future;
}

class ErrorScreen extends StatelessWidget {
  final String title;
  final String text;

  const ErrorScreen({super.key, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                )
              ],
            ),
            Expanded(
                child: SingleChildScrollView(
              child: SelectableText(text,
                  style: Theme.of(context).textTheme.bodySmall),
            ))
          ],
        ),
      )),
    );
  }
}

class BootScreen extends StatelessWidget {
  const BootScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(appBootScreenMessage, style: Theme.of(context).textTheme.bodyMedium,)
          ],
        ),
      ),
    );
  }
}

Future<int> getUnusedPort() {
  return ServerSocket.bind("127.0.0.1", 0).then((socket) {
    var port = socket.port;
    socket.close();
    return port;
  });
}
