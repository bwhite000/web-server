import "dart:io";
import "package:web_server/web_server.dart";

void main() {
  // Initialize the WebServer
  final WebServer localWebServer = new WebServer(InternetAddress.LOOPBACK_IP_V4, 8080,
      hasHttpServer: true, hasWebSocketServer: true);

  // Log out some of the connection information
  print('Private web server started at: (http://${localWebServer.address.address}:${localWebServer.port})'); // http://127.0.0.1:8080

  // Attach HttpServer pages and event handlers
  localWebServer.httpServerHandler
      // Gain handling of navigations to "/index.html"
      ..registerFile(new UrlData('/index.html')).listen((final HttpRequest httpRequest) { /*...*/ })

      // Gain handling to any sub-item in the directory
      ..registerDirectory(new UrlData('/img/profile_pics/80/')).listen((final HttpRequest httpRequest) { /*...*/ })

      // Automatically parse for indexing and serve all recursive items in this directory matching the accepted file types.
      ..serveVirtualDirectory('/web/', const <String>['html', 'css', 'dart', 'js'])

      // Automatically handle serving this file, with optional in-memory caching
      ..serveStaticFile(new UrlData('/static_page'), '/web/static_page.html', enableCaching: false)

      // Handle requiring Basic Authentication on the specified Url, allowing only the users in the authentication list.
      // The required credentials are "user:password" (from the BasicAuth base64 encoded -> 'dXNlcjpwYXNzd29yZA==')
      ..registerPathWithBasicAuth(new UrlData('/api/auth/required/dateTime'),
            const <AuthUserData>[const AuthUserData('username', 'dXNlcjpwYXNzd29yZA==')]).listen((final HttpRequest httpRequest)
            {
              // Create a new ApiResponse object for returning the API data
              final ApiResponse apiResponse = new ApiResponse()
                  ..addData('dateTime', '${new DateTime.now()}'); // Add the DateTime

              // Respond to the Url request
              httpRequest.response
                  ..headers.contentType = ContentType.JSON
                  ..write(apiResponse.toJsonEncoded())
                  ..close();
            });

  // Attach WebSocket command listeners and base events
  localWebServer.webSocketServerHandler
      ..on[0].listen((final WebSocketRequestPayload requestPayload) { /*...*/ })
      ..onConnectionOpen.listen((final WebSocketConnectionData connectionData) { /*...*/ })
      ..onConnectionError.listen((final WebSocket webSocket) { /*...*/ })
      ..onConnectionClose.listen((final WebSocket webSocket) { /*...*/ });
}