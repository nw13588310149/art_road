import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// iOS / Android：启用 ping 保活，避免系统很快挂掉「静默」长连接。
WebSocketChannel connectChatWebSocket(Uri uri) {
  return IOWebSocketChannel.connect(
    uri,
    pingInterval: const Duration(seconds: 25),
  );
}
