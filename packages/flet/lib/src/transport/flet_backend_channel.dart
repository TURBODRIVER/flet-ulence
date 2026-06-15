import '../protocol/message.dart';
import 'flet_backend_channel_mock.dart';
import 'flet_backend_channel_socket.dart';
import 'flet_backend_channel_web_socket.dart';

typedef FletBackendChannelOnDisconnectCallback = void Function();
typedef FletBackendChannelOnMessageCallback = void Function(Message message);

abstract class FletBackendChannel {
  factory FletBackendChannel(
      {required String address,
      required Map<String, dynamic> args,
      required FletBackendChannelOnDisconnectCallback onDisconnect,
      required FletBackendChannelOnMessageCallback onMessage}) {
    if (address.startsWith("http://") ||
        address.startsWith("https://")) {
      // WebSocket
      return FletWebSocketBackendChannel(
          address: address, onDisconnect: onDisconnect, onMessage: onMessage);
    } else if (address == "mock") {
      // Mock
      return FletMockBackendChannel(
          address: address, onDisconnect: onDisconnect, onMessage: onMessage);
    } else {
      // TCP or UDS
      return FletSocketBackendChannel(
          address: address, onDisconnect: onDisconnect, onMessage: onMessage);
    }
  }

  Future connect();
  bool get isLocalConnection;
  int get defaultReconnectIntervalMs;
  void send(Message message);
  void disconnect();
}
