part of WebServer;

typedef String FunctionBinaryParam(Uint32List encodeMessage, HttpRequest httpRequest, WebSocket ws);

class _WebSocketServerRequestHandler {
  final FunctionStore _functionStore = new FunctionStore();
  final StreamController<WebSocketConnectionData> _onOpenStreamController = new StreamController<WebSocketConnectionData>();
  final StreamController<WebSocket> _onErrorStreamController = new StreamController<WebSocket>();
  final StreamController<WebSocket> _onCloseStreamController = new StreamController<WebSocket>();
  FunctionBinaryParam customDecodeMessage = (final Uint32List str, final HttpRequest hR, final WebSocket ws) {};

  _WebSocketServerRequestHandler();

  // Getters
  FunctionStore get on {
    return this._functionStore;
  }

  Stream<WebSocketConnectionData> get onConnectionOpen {
    return this._onOpenStreamController.stream;
  }

  Stream<WebSocket> get onConnectionError {
    return this._onErrorStreamController.stream;
  }

  Stream<WebSocket> get onConnectionClose {
    return this._onCloseStreamController.stream;
  }

  // Util
  void _onUpgrade(final HttpRequest httpRequest, final WebSocket webSocket) {
    ServerLogger.log('Connected to client via WebSocket: (${httpRequest.connectionInfo.remoteAddress.address})');

    // Send the event for when a connection is opened; onConnectionOpen stream
    this._onOpenStreamController.add(new WebSocketConnectionData(httpRequest, webSocket));

    webSocket.map((final dynamic message) {
      if ((message is String) == false) {
        return convert.json.decode(this.customDecodeMessage(message, httpRequest, webSocket));
      }

      return convert.json.decode(message);
    }).listen((final dynamic json) {
      if (json is Map<String, dynamic>) {
        this.onMessage(json, httpRequest, webSocket);
      }
    }, onError: (final dynamic err) {
      ServerLogger.error(err);

      // Send the onConnectionError event
      this._onErrorStreamController.add(webSocket);
    }, onDone: () {
      ServerLogger.log('Connection to WebSocket closed');
      webSocket.close();

      // Send the onConnectionClose event
      this._onCloseStreamController.add(webSocket);
    });
  }

  void onMessage(final Map<String, dynamic> json, final HttpRequest httpRequest, final WebSocket webSocket) {
    final WebSocketRequestPayload wsRequestPayload = new WebSocketRequestPayload(json['cmd'], json['responseId'], json['data'], webSocket, httpRequest);

    this._functionStore.runEvent(wsRequestPayload.cmd, wsRequestPayload);
  }
}

class WebSocketConnectionData {
  final HttpRequest httpRequest;
  final WebSocket webSocket;

  WebSocketConnectionData(final HttpRequest this.httpRequest, final WebSocket this.webSocket);
}