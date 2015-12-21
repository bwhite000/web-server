import "dart:io";
import "dart:async";
import "package:web_server/web_server.dart" as webServer;

Future<Null> main() async {
  // Initialize the WebServer
  final webServer.WebServer localWebServer = new webServer.WebServer(InternetAddress.LOOPBACK_IP_V4, 8080,
      hasHttpServer: true);

  // Log out some of the connection information.
  stdout.writeln('Local web server started at: (http://${localWebServer.address.address}:${localWebServer.port})'); // http://127.0.0.1:8080

  // Automatically parse for indexing and serve all recursive items in this directory matching the accepted file extensions.
  await localWebServer.httpServerHandler.serveStaticVirtualDirectory('test_dir', shouldPreCache: true);
}