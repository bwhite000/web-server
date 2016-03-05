import "dart:io";
import "dart:async";
import "package:web_server/web_server.dart" as webServer;
import "dart:convert";

/**
 * Accepted command line arguments:
 *    > --port=<port-number>
 */
Future<Null> main(final List<String> args) async {
  const Map<String, String> SHORTHAND_TO_FULL_CMD_LINE_ARG_KEYS = const <String, String>{
    "h": "help"
  };
  final Map<String, dynamic> cmdLineArgsMap = _parseCmdLineArgs(args, SHORTHAND_TO_FULL_CMD_LINE_ARG_KEYS);
  InternetAddress hostAddr = InternetAddress.ANY_IP_V4;
  int portNumber = 8080; // Default value.

  if (cmdLineArgsMap.containsKey('help')) {
    _outputHelpDetails();
    exit(0);
  }

  // Interpret the command line arguments if needed.
  if (cmdLineArgsMap.containsKey('host') && cmdLineArgsMap['host'] is String) {
    final RegExp _ipv4AddrRegExp = new RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');

    if (_ipv4AddrRegExp.hasMatch(cmdLineArgsMap['host'])) {
      hostAddr = new InternetAddress(cmdLineArgsMap['host']);
    } else {
      stderr.writeln('The specified (--host=${cmdLineArgsMap['host']}) argument is invalid; only IPV4 addresses are accepted right now (e.g. --host=127.0.0.1).');
      exit(1);
    }
  }

  if (cmdLineArgsMap.containsKey('port')) {
    if (cmdLineArgsMap['port'] is int) {
      portNumber = cmdLineArgsMap['port'];
    } else {
      stderr.writeln('The specified (--port=${cmdLineArgsMap['port']}) argument is invalid; must be an integer value (e.g. --port=8080).');
      exit(1);
    }
  }

  final webServer.WebServer localWebServer = new webServer.WebServer(hostAddr, portNumber, hasHttpServer: true);

  stdout.writeln('WebServer started and listening for HTTP requests at the address: ${localWebServer.isSecure ? 'https' : 'http'}://${localWebServer.address.host}:$portNumber');

  await localWebServer.httpServerHandler.serveStaticVirtualDirectory(Directory.current.path, shouldPreCache: false);

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

Map<String, dynamic> _parseCmdLineArgs(final List<String> cmdLineArgsList, [final Map<String, String> argKeyMappingIndex = null]) {
  final Map<String, dynamic> cmdLineArgsMap = <String, dynamic>{};
  final RegExp leadingDashesRegExp = new RegExp(r'^\-{1,2}');
  final RegExp keyValArgRegExp = new RegExp(r'^\-{1,2}[A-z]+\=\S+');
  final RegExp intValRegExp = new RegExp(r'^\-?\d+$');

  cmdLineArgsList.forEach((final String cmdLineArg) {
    if (cmdLineArg.startsWith(new RegExp('^\-{1,2}'))) {
      if (cmdLineArg.startsWith(keyValArgRegExp)) {
        final List<String> _keyValPieces = cmdLineArg.split('=');
        String _argKey = _keyValPieces[0].replaceFirst(leadingDashesRegExp, '');
        dynamic _argVal = _keyValPieces[1];

        if (intValRegExp.hasMatch(_argVal)) {
          _argVal = int.parse(_argVal);
        }

        // Map the keyname, if needed.
        if (argKeyMappingIndex != null && argKeyMappingIndex.containsKey(_argKey)) {
          _argKey = argKeyMappingIndex[_argKey];
        }

        cmdLineArgsMap[_argKey] = _argVal;
      } else {
        String _argKey = cmdLineArg.replaceFirst(leadingDashesRegExp, '');

        // Map the keyname, if needed.
        if (argKeyMappingIndex != null && argKeyMappingIndex.containsKey(_argKey)) {
          _argKey = argKeyMappingIndex[_argKey];
        }

        cmdLineArgsMap[_argKey] = true;
      }
    }
  });

  return cmdLineArgsMap;
}

void _outputHelpDetails() {
  final String outputHelpDetails = '''
WebServer is a Dart package for serving files from a directory.

Usage: web_server [arguments]

Global options:
-h, --help                Prints this usage information.
    --host=<address>      Bind the web server to the specified host address; the default is 0.0.0.0 (any available addresses).
    --port=<port-number>  Uses the provided port number to bind the web server to; the default is 8080.

See https://github.com/bwhite000/web-server for package details.''';

  stdout.writeln(outputHelpDetails);
}