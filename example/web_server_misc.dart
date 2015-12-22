import "dart:io";
import "package:web_server/web_server.dart";

void main() {
  // Initialize and bind the HTTP and WebSocket WebServer
  final WebServer localWebServer = new WebServer(InternetAddress.LOOPBACK_IP_V4, 8080,
      hasHttpServer: true, hasWebSocketServer: true);

  // Log out some of the connection information
  stdout.writeln('Local web server started at: (http://${localWebServer.address.address}:${localWebServer.port})'); // http://127.0.0.1:8080

  HttpServerRequestHandler.shouldBeVerbose = true;

  // Attach HttpServer pages and event handlers
  localWebServer.httpServerHandler
      // Gain handling of navigations to "/index.html"
      ..forRequestPath(new UrlPath('/index.html')).onRequest.listen((final HttpRequest httpRequest) { /*...*/ })

      // Gain handling to ANY immediate sub-item in the directory;
      // serveVirtualDirectory() is preferred over this unless you need fine grain controls
      ..registerDirectory(new UrlPath('/img/profile_pics/80/')).listen((final HttpRequest httpRequest) { /*...*/ })

      // Automatically parse for indexing and serve all recursive items in this directory matching the accepted file extensions.
      ..serveStaticVirtualDirectory('lib/web_demo', supportedFileExtensions: const <String>['html', 'css', 'dart', 'js'])

      // Automatically handle serving this file at navigation to '/static_page', with optional in-memory caching
      ..serveStaticFile(new UrlPath('/static_page'), 'web_demo/static_page.html', enableCaching: false)

      // Gain handling of all API requests, for example; catches all paths starting with the String in UrlData
      ..handleRequestsStartingWith(new UrlPath('/api/')).listen((final HttpRequest httpRequest) {/*...*/})

      // Handle requiring Basic Authentication on the specified Url, allowing only the users in the authentication list.
      // The required credentials are "user:password" (from the BasicAuth base64 encoded -> 'dXNlcjpwYXNzd29yZA==')
      ..registerPathWithBasicAuth(new UrlPath('/api/auth/required/dateTime'), const <AuthUserData>[
            const AuthUserData('username', 'dXNlcjpwYXNzd29yZA==') // user:password --> Base64
          ]).listen((final HttpRequest httpRequest) {
            // Create a new ApiResponse object for returning the API data;
            // Value --> {"sucess": true, "dateTime": "XXXX-XX-XX XX:XX:XX.XXX"}
            final ApiResponse apiResponse = new ApiResponse()
                ..addData('dateTime', '${new DateTime.now()}'); // Add the DateTime

            // Respond to the Url request
            httpRequest.response
                ..headers.contentType = ContentType.JSON // Set the 'content-type' header as JSON
                ..write(apiResponse.toJsonEncoded()) // Export as a JSON encoded string
                ..close();
          })

      // Add a custom function for handling the request in case of the error code supplied as the parameter.
      ..onErrorDocument(HttpStatus.NOT_FOUND, (final HttpRequest httpRequest) {
        httpRequest.response
            ..statusCode = HttpStatus.NOT_FOUND
            ..headers.contentType = new ContentType('text', 'html', charset: 'utf-8')
            ..write('<h1>404 Error accessing: ${httpRequest.requestedUri.path}</h1>')
            ..close();
      });

  // Attach WebSocket command listeners and base events
  localWebServer.webSocketServerHandler
      ..on[0].listen((final WebSocketRequestPayload requestPayload) { /*...*/ })
      ..onConnectionOpen.listen((final WebSocketConnectionData connectionData) { /*...*/ })
      ..onConnectionError.listen((final WebSocket webSocket) { /*...*/ })
      ..onConnectionClose.listen((final WebSocket webSocket) { /*...*/ });
}