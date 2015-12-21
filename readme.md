WebServer
=========

An efficient server library for quickly creating a WebServer and handling HTTP requests, WebSocket
connections, and routing API requests using the Dart language.

Includes extra nice features, such as setting a parameter to require Basic Authentication for a Url,
with all of the difficult auth checking and responding taken care of by the server, plus much more!

#### Who is using this package?

__[Ebates, Inc.](http://www.ebates.com/)__
- For a handful of internal tools for organizing data and serving stat pages.
- Used to serve a realtime Purchases Stat information webpage to merchant representatives at the __Ebates MAX Conference__
  built around this package.

Use Example (for no coding needed)
--------------------------------------------------------------

You can use this WebServer to serve files without even having to code a single line. Using Dart's
`pub global activate` feature, you can add the WebServer package as an executable to call from the
command line in any directory and serve files from it.

~~~bash
# Activate the WebServer globally.
pub global activate web_server
~~~

~~~bash
# Navigate to the Directory that you want to serve files from.
cd /path/to/directory

# Activate the WebServer on that Directory. Defaults to port 8080.
# http://127.0.0.1:8080/path/to/file
web_server
~~~

Features & Use Example (for coders)
------------------------

Please check out the ["example/"](example/) folder in this package for full details.

### For processing HTML like PHP

Use Angular-like variables, which will be converted using a helper method from this package (see Dart
code below).

*--- index.html ---*
~~~html
<body>
  <h1>Welcome, {{username}}!</h1>

  <p>The date today is: {{todayDate}}.</p>
</body>
~~~

Then, process variables like PHP on the Dart server side.

*--- main.dart ---*
~~~dart
import "dart:io";
import "package:web_server/web_server.dart" as webServer;

void main() {
  // Initialize the WebServer  
  final webServer.WebServer localWebServer = new webServer.WebServer(InternetAddress.ANY_IP_V4, 8080,
        hasHttpServer: true);
        
  localWebServer.httpServerHandler
    .forRequestPath(new webServer.UrlPath('/index.html')).onRequested.listen((final HttpRequest httpRequest) async {
      String indexFileContents = await new File('path/to/index.html').readAsString();
      
      // Apply the Dart variables to the HTML file's variables like
      // AngularJS/AngularDart
      indexFileContents = webServer.applyVarModifiers(indexFileContents, {
        "username": "mrDude",
        "todayDate": '${new DateTime.now()}'
      });
      
      httpRequest.response
          ..headers.contentType = new ContentType('text', 'html', charset: 'utf-8')
          ..write(indexFileContents)
          ..close();
    });
}
~~~

### For Hosting APIs

Filter every request starting with a certain Url pattern into a request handler.

~~~dart
import "dart:io";
import "package:web_server/web_server.dart" as webServer;

void main() {
  // Initialize the WebServer  
  final webServer.WebServer localWebServer = new webServer.WebServer(InternetAddress.ANY_IP_V4, 8080,
        hasHttpServer: true);
        
  localWebServer.httpServerHandler
      // NOTE: ApiHandler would be a Class or namespace created by you in your code, for example
      ..handleRequestsStartingWith(new webServer.UrlPath('/api/categories')).listen(ApiHandler.forCategories)
      ..handleRequestsStartingWith(new webServer.UrlPath('/api/products')).listen(ApiHandler.forProducts)
      ..handleRequestsStartingWith(new webServer.UrlPath('/api/users')).listen(ApiHandler.forUserInfo);
}
~~~

### Static File Implementation/Basic

~~~dart
import "dart:io";
import "dart:async";
import "package:web_server/web_server.dart" as webServer;

Future<Null> main() async {
  // Initialize the WebServer  
  final webServer.WebServer localWebServer = new webServer.WebServer(InternetAddress.ANY_IP_V4, 8080,
        hasHttpServer: true);
        
  // Attach HttpServer pages and event handlers
  await localWebServer.httpServerHandler
      // Automatically recursively parse and serve all items in this
      // directory matching the accepted file types (optional parameter).
      .serveStaticVirtualDirectory('web',
          supportedFileExtensions: const <String>['html', 'css', 'dart', 'js'],
          shouldPreCache: true);
}
~~~

### WebSocket Server

Let the WebServer automatically handle upgrading and connecting to WebSockets from the client
side. The WebServer will forward data related to important events and automatically call your
event listeners if you send data through a WebSocket from the client with the "cmd" parameter
in the payload's Map Object.

~~~dart
import "dart:io";
import "package:web_server/web_server.dart" as webServer;

void main() {
  // Initialize the WebServer with the hasWebSocketServer parameter
  final webServer.WebServer localWebServer = new webServer.WebServer(InternetAddress.ANY_IP_V4, 8080,
          hasHttpServer: true, hasWebSocketServer: true);
  
  // Attach WebSocket command listeners and base events
  localWebServer.webSocketServerHandler
      // For automatically routing handling of data sent through a WebSocket with this pattern of "cmd":
      // {"cmd": 0, "data": { "pokemonCount": 151 }}
      ..on[0].listen((final webServer.WebSocketRequestPayload requestPayload) { /*...*/ })
      ..onConnectionOpen.listen((final webServer.WebSocketConnectionData connectionData) { /*...*/ })
      ..onConnectionError.listen((final WebSocket webSocket) { /*...*/ })
      ..onConnectionClose.listen((final WebSocket webSocket) { /*...*/ });
}
~~~

### Add a custom ContentType

Allows the server to automatically pick up on this file extension as the supplied ContentType parameter
when it is handling serving files.

~~~dart
HttpServerRequestHandler.addContentType('.html', new ContentType('text', 'html', charset: 'utf-8'));
~~~

Features and bugs
-----------------

Please file feature requests and bugs using the GitHub issue tracker for this repository.

Using this package? Let me know!
--------------------------------

I am excited to see if other developers are able to make something neat with this package.
If you have a project using it, please send me a quick email at the email address listed on
[my GitHub's main page](https://github.com/bwhite000). Thanks a bunch!
