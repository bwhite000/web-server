import "dart:io";
import "dart:async";
import "package:web_server/web_server.dart" as webServer;

Future<Null> main(final List<String> args) async {
  const int port = 8080;
  final webServer.WebServer localWebServer = new webServer.WebServer(InternetAddress.ANY_IP_V4, port, hasHttpServer: true);

  stdout.writeln('WebServer started at port $port');

  stdout.writeln('Caching files recursively from this directory...');
  await localWebServer.httpServerHandler.serveStaticVirtualDirectory(Directory.current.path, shouldPreCache: true);
  stdout.writeln('Done caching files recursively from this directory!');

  // Handle errors
  localWebServer.httpServerHandler
      ..onErrorDocument(HttpStatus.NOT_FOUND, (final HttpRequest httpRequest) {
        // Use the helper method from this WebServer package
        webServer.HttpServerRequestHandler.sendPageNotFoundResponse(httpRequest,
            '<h1>${HttpStatus.NOT_FOUND} - Page not found</h1>');
      })
      ..onErrorDocument(HttpStatus.INTERNAL_SERVER_ERROR, (final HttpRequest httpRequest) {
        // Use the helper method from this WebServer package
        webServer.HttpServerRequestHandler.sendInternalServerErrorResponse(httpRequest,
            '<h1>${HttpStatus.INTERNAL_SERVER_ERROR} - Internal Server Error</h1>');
      });
}