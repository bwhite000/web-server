library WebServer.webServer;

import "dart:io";
import "dart:async";
import "dart:convert" show JSON;
import "dart:typed_data";
import "package:event_listener/event_listener.dart";
import "package:path/path.dart" as path;
import "package:server_logger/server_logger.dart" as ServerLogger;

part "src/web_server/http_server_request_handler.dart";
part "src/web_server/web_socket_request_payload.dart";
part "src/web_server/web_socket_server_request_handler.dart";

class WebServer {
  final InternetAddress address;
  final int port;
  final bool hasHttpServer;
  final bool hasWebSocketServer;
  final bool isSecure;
  _HttpServerRequestHandler httpServerHandler;
  _WebSocketServerRequestHandler webSocketServerHandler;
  final List<String> allowedMethods;
  final Duration responseDeadline;

  WebServer(final InternetAddress this.address, final int this.port, {
    final bool this.hasHttpServer: false,
    final bool this.hasWebSocketServer: false,
    final bool enableCompression: true,
    final bool this.isSecure: false,
    final String certificateName,
    final List<String> this.allowedMethods: const <String>['GET', 'POST'],
    final Duration this.responseDeadline: const Duration(seconds: 20)
  }) {
    if (this.hasHttpServer == false && this.hasWebSocketServer == false) {
      return;
    }

    if (this.hasHttpServer) {
      this.httpServerHandler = new _HttpServerRequestHandler();
    }

    if (this.hasWebSocketServer) {
      this.webSocketServerHandler = new _WebSocketServerRequestHandler();
    }

    if (this.isSecure) {
      throw "Secure server binding is not supported at this time.";

      SecureSocket.initialize(useBuiltinRoots: true);

      HttpServer.bindSecure(address, port, certificateName: certificateName).then((final HttpServer httpServer) {
        httpServer.autoCompress = enableCompression; // Enable GZIP

        httpServer.listen(this._onRequest);
      });
    } else {
      HttpServer.bind(address, port).then((final HttpServer httpServer) {
        httpServer.autoCompress = enableCompression; // Enable GZIP

        httpServer.listen(this._onRequest);
      });
    }
  }

  void _onRequest(final HttpRequest httpRequest) {
    if (httpRequest.method == null ||
        httpRequest.method.isEmpty ||
        httpRequest.method.length > 16 ||
        this.allowedMethods.contains(httpRequest.method) == false)
    {
      httpRequest.response
          ..statusCode = HttpStatus.FORBIDDEN
          ..close();
      return;
    }

    // Add a response deadline length (amount of time for response to complete by)
    httpRequest.response.deadline = this.responseDeadline;

    if (this.hasWebSocketServer && WebSocketTransformer.isUpgradeRequest(httpRequest)) { // Is WebSocket server allowed?
      WebSocketTransformer.upgrade(httpRequest).then((final WebSocket webSocket) {
        this.webSocketServerHandler._onUpgrade(httpRequest, webSocket);
      });
    } else if (this.hasHttpServer) { // Is http server allowed?
      this.httpServerHandler._onHttpRequest(httpRequest);
    } else {
      httpRequest.response
          ..statusCode = HttpStatus.FORBIDDEN
          ..close();
    }
  }
}