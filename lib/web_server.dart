/**
 * A powerful WebServer package to make getting reliable, strong servers
 * running quickly with many features.
 */
library WebServer;

import "dart:io";
import "dart:async";
import "dart:typed_data";
import "package:cache/cache.dart";
import 'package:dart2_constant/convert.dart' as convert;
import 'package:dart2_constant/io.dart' as io;
import "package:event_listener/event_listener.dart";
import "package:path/path.dart" as path;
import "package:server_logger/server_logger.dart" as ServerLogger;

part "src/web_server/api_response.dart";
part "src/web_server/http_server_request_handler.dart";
part "src/web_server/web_socket_request_payload.dart";
part "src/web_server/web_socket_server_request_handler.dart";

/**
 * The base class for all of the WebServer functionality.
 */
class WebServer {
  final InternetAddress address;
  final int port;
  final bool hasHttpServer;
  final bool hasWebSocketServer;
  final bool isSecure;
  HttpServerRequestHandler httpServerHandler;
  _WebSocketServerRequestHandler webSocketServerHandler;
  final List<String> allowedMethods;
  final Duration responseDeadline;

  WebServer(final InternetAddress this.address, final int this.port, {
    final bool this.hasHttpServer: false,
    final bool this.hasWebSocketServer: false,
    final bool enableCompression: true,
    final List<String> this.allowedMethods,
    final Duration this.responseDeadline: const Duration(seconds: 30)
  }) : this.isSecure = false {
    if (this.hasHttpServer == false && this.hasWebSocketServer == false) {
      return;
    }

    if (this.hasHttpServer) {
      this.httpServerHandler = new HttpServerRequestHandler();
    }

    if (this.hasWebSocketServer) {
      this.webSocketServerHandler = new _WebSocketServerRequestHandler();
    }

    HttpServer.bind(address, port).then((final HttpServer httpServer) {
      httpServer.autoCompress = enableCompression; // Enable GZIP?

      httpServer.listen(this._onRequest);
    });
  }

  WebServer.secure(final InternetAddress this.address, final int this.port, final SecurityContext securityContext, {
    final bool this.hasHttpServer: false,
    final bool this.hasWebSocketServer: false,
    final bool enableCompression: true,
    final List<String> this.allowedMethods,
    final Duration this.responseDeadline: const Duration(seconds: 30)
  }) : this.isSecure = true {
    if (this.hasHttpServer == false && this.hasWebSocketServer == false) {
      return;
    }

    if (this.hasHttpServer) {
      this.httpServerHandler = new HttpServerRequestHandler();
    }

    if (this.hasWebSocketServer) {
      this.webSocketServerHandler = new _WebSocketServerRequestHandler();
    }

    HttpServer.bindSecure(address, port, securityContext).then((final HttpServer httpServer) {
      httpServer.autoCompress = enableCompression; // Enable GZIP?

      httpServer.listen(this._onRequest);
    });
  }

  void _onRequest(final HttpRequest httpRequest) {
    if (httpRequest.method == null ||
        httpRequest.method.isEmpty ||
        httpRequest.method.length > 16 ||
        (this.allowedMethods != null && this.allowedMethods.contains(httpRequest.method) == false))
    {
      httpRequest.response
          ..statusCode = io.HttpStatus.forbidden
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
          ..statusCode = io.HttpStatus.forbidden
          ..close();
    }
  }
}