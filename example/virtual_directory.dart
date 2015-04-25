import "dart:io";
import "package:web_server/web_server.dart";

void main() {
  // Initialize the WebServer
  final WebServer localWebServer = new WebServer(InternetAddress.LOOPBACK_IP_V4, 8989,
      hasHttpServer: true, hasWebSocketServer: true);

  // Log out some of the connection information
  print('Local web server started at: (http://${localWebServer.address.address}:${localWebServer.port})'); // http://127.0.0.1:8080

  // Automatically parse for indexing and serve all recursive items in this directory matching the accepted file extensions.
  localWebServer.httpServerHandler.serveVirtualDirectory('test_dir', const <String>['html', 'css', 'dart', 'js']);
}