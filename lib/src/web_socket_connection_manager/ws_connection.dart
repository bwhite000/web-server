part of WebServer.webSocketConnectionManager;

class WebSocketConnection {
  final WebSocket webSocket;
  final List<WebSocket> webSockets = <WebSocket>[];
  String chromeExtensionVersion;
  int connectionRole;

  WebSocketConnection(final WebSocket this.webSocket);
}