part of WebServer.webServer;

class WebSocketRequestPayload {
  final int cmd;
  final dynamic data;
  final String responseId;
  final WebSocket responseWebSocket;
  final HttpRequest httpRequest;

  const WebSocketRequestPayload(final int this.cmd,
      final String this.responseId,
      final dynamic this.data,
      final WebSocket this.responseWebSocket,
      final HttpRequest this.httpRequest);
}