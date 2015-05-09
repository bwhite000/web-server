part of WebServer;

/**
 * This is part of the WebServer object used for setting up HttpRequest
 * handlers.
 */
class HttpServerRequestHandler {
  final FunctionStore _functionStore = new FunctionStore();
  final Map<String, int> _possibleFiles = <String, int>{};
  final Map<String, int> _possibleDirectories = <String, int>{};
  final List<_VirtualDirectoryFileData> _virtualDirectoryFiles = <_VirtualDirectoryFileData>[];
  final List<_PathDataWithAuth> _pathDataForAuthList = <_PathDataWithAuth>[];
  final List<UrlData> _urlPathStartString = <UrlData>[];

  /// The message text that will be returned in the response when a BasicAuth request fails.
  final String strForUnauthorizedError = '401 - Unauthorized';

  static const Map<String, List<String>> _fileExtensions = const <String, List<String>>{
    ".html": const <String>["text", "html"],
    ".css": const <String>["text", "css"],
    ".js": const <String>["text", "javascript"],
    ".dart": const <String>["application", "dart"],
    ".txt": const <String>["text", "plain"],
    ".png": const <String>["image", "png"],
    ".jpg": const <String>["image", "jpeg"],
    ".jpeg": const <String>["image", "jpeg"],
    ".gif": const <String>["image", "gif"],
    ".ico": const <String>["image", "x-icon"],
    ".webp": const <String>["image", "webp"],
    ".svg": const <String>["image", "svg+xml"],
    ".otf": const <String>["font", "otf"],
    ".woff": const <String>["font", "woff"],
    ".woff2": const <String>["font", "woff2"],
    ".ttf": const <String>["font", "ttf"],
    ".rar": const <String>["application", "x-rar-compressed"],
    ".zip": const <String>["application", "zip"]
  };
  static bool shouldBeVerbose = false;

  HttpServerRequestHandler();

  // Util
  void _onHttpRequest(final HttpRequest httpRequest) {
    if (HttpServerRequestHandler.shouldBeVerbose) {
      ServerLogger.log('_HttpServerRequestHandler.onRequest()');
      ServerLogger.log('Requested Url: ${httpRequest.uri.path}');
    }

    final String path = httpRequest.uri.path;

    // Is there basic auth needed for this path.
    if (this._doesThisPathRequireAuth(path)) { // BasicAuth IS required
      final _PathDataWithAuth pathDataWithAuthForPath = this._getAcceptedCredentialsForPath(path);
      final _AuthCheckResults authCheckResults = this._checkAuthFromRequest(httpRequest, pathDataWithAuthForPath);

      if (authCheckResults.didPass) {
        final int urlId = this._possibleFiles[path];
        this._functionStore.runEvent(urlId, httpRequest);
      } else {
        HttpServerRequestHandler.sendRequiredBasicAuthResponse(httpRequest, this.strForUnauthorizedError);
      }

      return;
    } else { // BasicAuth is NOT required
      // Is this a 'startsWith' registered path?
      for (UrlData _urlData in this._urlPathStartString) {
        if (path.startsWith(_urlData.path)) {
          this._functionStore.runEvent(_urlData.id, httpRequest);
          return;
        }
      }

      // Check if the URL matches a registered file and that a URL ID is in the FunctionStore
      if (this._possibleFiles.containsKey(path) &&
          this._functionStore.fnStore.containsKey(this._possibleFiles[path]))
      {
        if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('Url has matched to a file. Routing to it...');

        final int urlId = this._possibleFiles[path];

        this._functionStore.runEvent(urlId, httpRequest);
      } else {
        bool wasVirtualFileMatched = false;

        for (_VirtualDirectoryFileData virtualFilePathData in this._virtualDirectoryFiles) {
          // If the requested path matches a virtual path
          if (httpRequest.uri.path == virtualFilePathData.httpRequestPath) {
            wasVirtualFileMatched = true;

            // Serve the matched virtual file
            HttpServerRequestHandler._serveStandardFile('${virtualFilePathData.containerDirectoryPath}${virtualFilePathData.filePathFromContainerDirectory}', httpRequest).catchError(ServerLogger.error);

            break;
          }
        }

        // Continue only if a virtual file wasn't already matched
        if (wasVirtualFileMatched == false) {
          String possibleDirectoryPath = '/';

          // Remove the file from the path to see if parent directory matches.
          // e.g. "/profile_pics/80/bob.jpg" -> "/profile_pics/80/"
          for (int i = 0, lenMinusOne = httpRequest.uri.pathSegments.length - 1; i < lenMinusOne; i++) {
            possibleDirectoryPath += '${httpRequest.uri.pathSegments[i]}/';
          }

          // Check if the URL matches a registered directory and that a URL ID is in the FunctionStore
          if (this._possibleDirectories.containsKey(possibleDirectoryPath) &&
              this._functionStore.fnStore.containsKey(this._possibleDirectories[possibleDirectoryPath]))
          {
            if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('Url has matched to a directory. Routing to it...');

            final int urlId = this._possibleDirectories[possibleDirectoryPath];

            this._functionStore.runEvent(urlId, httpRequest);
          } else { // Respond with 404 error because nothing was matched.
            if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('No registered url match found.');

            httpRequest.response
                ..statusCode = HttpStatus.NOT_FOUND
                ..headers.contentType = new ContentType("text", "plain", charset: "utf-8")
                ..close();
          }
        }
      }
    }
  }

  /**
   * Register a file and return a Stream for adding a listeners to when that filepath is requested.
   */
  Stream<HttpRequest> registerFile(final UrlData urlData) {
    this._possibleFiles[urlData.path] = urlData.id;

    return this._functionStore[urlData.id];
  }

  /**
   * Require basic authentication by the client to view this Url path.
   *
   * [pathToRegister] - The path that will navigated to in order to call this; e.g. "/support/client/contact-us"
   * [authUserList] - A list of
   */
  Stream<HttpRequest> registerPathWithBasicAuth(final UrlData pathToRegister, final List<AuthUserData> authUserList) {
    if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('HttpServerRequestHandler.registerPathWithAuth() -> Stream<HttpRequest>');

    if (authUserList.length == 0) {
      throw 'There are no users in the list of authorized users.';
    }

    final _PathDataWithAuth pathDataWithAuth = new _PathDataWithAuth(pathToRegister.path, authUserList);

    this._pathDataForAuthList.add(pathDataWithAuth);
    this._possibleFiles[pathToRegister.path] = pathToRegister.id;

    return this._functionStore[pathToRegister.id];
  }

  /// Does this request path need to be handled by the authentication engine?
  bool _doesThisPathRequireAuth(final String pathName) {
    for (_PathDataWithAuth pathDataWithAuth in this._pathDataForAuthList) {
      // Do the paths match?
      if (pathDataWithAuth.urlPath == pathName) {
        return true;
      }
    }

    return false;
  }

  _PathDataWithAuth _getAcceptedCredentialsForPath(final String pathName) {
    for (_PathDataWithAuth pathDataWithAuth in this._pathDataForAuthList) {
      // Do the paths match?
      if (pathDataWithAuth.urlPath == pathName) {
        return pathDataWithAuth;
      }
    }

    return null;
  }

  _AuthCheckResults _checkAuthFromRequest(final HttpRequest httpRequest, final _PathDataWithAuth acceptedCredentialsPathData) {
    // If no auth header supplied
    if (httpRequest.headers.value(HttpHeaders.AUTHORIZATION) == null) {
      return const _AuthCheckResults(false);
    }

    const int MAX_ALLOWED_CHARACTER_RANGE = 256;
    final String authHeaderStr = httpRequest.headers.value(HttpHeaders.AUTHORIZATION); // Get the provided auth info
    final int trimRange = (authHeaderStr.length <= MAX_ALLOWED_CHARACTER_RANGE) ? authHeaderStr.length : MAX_ALLOWED_CHARACTER_RANGE; // Determine subStr amt
    final String clientProvidedAuthInfo = authHeaderStr.substring(0, trimRange).replaceFirst(new RegExp('^Basic '), ''); // Remove the prefixed "Basic " from auth header

    if (acceptedCredentialsPathData.doCredentialsMatch(clientProvidedAuthInfo)) {
      return new _AuthCheckResults(true, acceptedCredentialsPathData.getUsernameForCredentials(clientProvidedAuthInfo));
    }

    return const _AuthCheckResults(false);
  }

  /// Send an HTTP 401 Auth required response
  static void sendRequiredBasicAuthResponse(final HttpRequest httpRequest, final String errMessage) {
    httpRequest.response
        ..statusCode = HttpStatus.UNAUTHORIZED
        ..headers.add(HttpHeaders.WWW_AUTHENTICATE, 'Basic realm="Enter credentials"')
        ..write(errMessage)
        ..close();
  }

  static void sendPageNotFoundResponse(final HttpRequest httpRequest, final String errMessage) {
    httpRequest.response
        ..statusCode = HttpStatus.NOT_FOUND
        ..write('404 - Page not found')
        ..close();
  }

  static void sendInternalServerErrorResponse(final HttpRequest httpRequest, final String errMessage) {
    httpRequest.response
        ..statusCode = HttpStatus.INTERNAL_SERVER_ERROR
        ..write('500 - Internal Server Error')
        ..close();
  }

  Stream<HttpRequest> registerDirectory(final UrlData urlData) {
    if (urlData.path.endsWith('/') == false) {
      throw 'Urls registered as directories must end with a trailing forward slash ("/"); e.g. "/profile_pics/80/".';
    }

    this._possibleDirectories[urlData.path] = urlData.id;

    return this._functionStore[urlData.id];
  }

  /**
   * Serve a static file, with optional caching.
   *
   * [urlData] - The path to navigate to in your browser to load this file.
   * [pathToFile] - The path on your computer to read the file contents from.
   * [enableCaching] (opt) - Should this file be cached in memory after it is first read? Default is true.
   * [isRelativeFilePath] (opt) - Is the [pathToFile] value a relative path? Default is true.
   */
  Future<Null> serveStaticFile(final UrlData urlData, String pathToFile, {
    final bool enableCaching: true,
    final bool isRelativeFilePath: true
  }) async {
    if (path.isRelative(pathToFile) && isRelativeFilePath) {
      final Uri _scriptRuntimeUri = Uri.parse(Platform.script.path);
      final Uri _absoluteUriAfterResolving = _scriptRuntimeUri.resolve(pathToFile);

      pathToFile = _absoluteUriAfterResolving.toFilePath();
    }

    final File file = new File(pathToFile);

    if (await file.exists()) {
      String _fileContents; /// The contents of the file, if caching is enabled
      final ContentType _contentType = getContentTypeForFilepathExtension(pathToFile);

      this._possibleFiles[urlData.path] = urlData.id;

      this._functionStore[urlData.id].listen((final HttpRequest httpRequest) async {
        String _localFileContents;

        if (enableCaching == true) { // Use a cached file, or initialize the cached file, if enabled
          if (_fileContents == null) { // If a version has not been cached before
            _fileContents = await file.readAsString();
          }

          _localFileContents = _fileContents;
        } else if (enableCaching == false) { // Read freshly, if caching is not enabled
          _localFileContents = await file.readAsString();
        }

        if (_contentType != null) {
          httpRequest.response.headers.contentType = _contentType;
        }

        httpRequest.response
            ..write(_localFileContents)
            ..close();
      });
    } else {
      if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.error('The file at path ($pathToFile) was not found in the filesystem; unable to serve it.');
    }
  }

  /**
   * Automatically handle serving this path, after handling required basic authentication.
   *
   * [pathToFile] - The filesystem path to locate the file to serve.
   * [varModifiers] - A key/value map of modifiers to automatically replace in the file
   * [enableCaching] - Should the file be cached in-memory; updates the cache when a newer copy is found.
   */
  /*
  static Future<Null> serveFileWithAuth(final String pathToFile, {
    final Map<String, dynamic> varModifiers: const <String, dynamic>{},
    final bool enableCaching: false
  }) async {
    final File file = new File(pathToFile);

    if (await file.exists()) {
      //
    } else {
      ServerLogger.error('The file at path ($pathToFile) was not found in the filesystem; unable to serve it.');
    }
  }
  */

  /**
   * Serve this entire directory automatically, but only for the allowed file extensions.
   *
   * [pathToDirectory] - The path to this directory to server files recursively from.
   * [supportedFileExtensions] - A list of file extensions (without the "." before the extension name) that are allowed to be served from this directory.
   * [includeContainerDirNameInPath] - Should the folder being served also have it's name in the browser navigation path; such as serving a 'js/' folder while retaining 'js/' in the browser Url; default is false.
   * [shouldFollowLinks] - Should SymLinks be treated as they are in this directory and, therefore, served?
   *
   *     new WebServer().serveVirtualDirectory('web/js', ['.js'],
   *       parseForFilesRecursively: false);
   */
  Future<Null> serveVirtualDirectory(String pathToDirectory, final List<String> supportedFileExtensions, {
    final bool includeContainerDirNameInPath: false,
    final bool shouldFollowLinks: false,
    final String prefixWithPseudoDirName: '',
    final bool isRelativeDirPath: true,
    final bool parseForFilesRecursively: true
  }) async {
    if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('_HttpServerRequestHandler.serveVirtualDirectory(String, List, {bool}) -> Future<Null>');

    // Make sure that supported file extensions were supplied.
    if (supportedFileExtensions == null || supportedFileExtensions.length == 0) {
      throw 'There were no supported file extensions set. Nothing would have been included from this directory.';
    }

    if (path.isRelative(pathToDirectory) && isRelativeDirPath) {
      final Uri _scriptRuntimeUri = Uri.parse(Platform.script.path);
      final Uri _absoluteUriAfterResolving = _scriptRuntimeUri.resolve(pathToDirectory);

      pathToDirectory = _absoluteUriAfterResolving.toFilePath();

      if (HttpServerRequestHandler.shouldBeVerbose) {
        ServerLogger.log('Resolved the Uri to be: ($pathToDirectory)');
      }
    }

    // Get the directory for virtualizing
    final Directory dir = new Directory(pathToDirectory);

    // If the directory exists
    if (await dir.exists()) {
      // Loop through all of the entities in this directory and determine which ones to make serve later.
      dir.list(recursive: parseForFilesRecursively, followLinks: shouldFollowLinks).listen((final FileSystemEntity entity) async {
        final FileStat fileStat = await entity.stat();

        for (String supportedFileExtension in supportedFileExtensions) {
          // If this is a file AND ends with a supported file extension
          if (fileStat.type == FileSystemEntityType.FILE && entity.path.toLowerCase().endsWith('.$supportedFileExtension')) {
            final String _containerDirectoryPath = pathToDirectory;
            final String _filePathFromContainerDirectory = entity.path.replaceFirst(_containerDirectoryPath, '');
            String _optPrefix = (includeContainerDirNameInPath) ? path.basename(_containerDirectoryPath) : '';

            if (prefixWithPseudoDirName is String &&
                prefixWithPseudoDirName.isNotEmpty)
            {
              if (_optPrefix.isNotEmpty) {
                _optPrefix = prefixWithPseudoDirName + '/' + _optPrefix; // 'psuedoPrefix' + '/' + 'web';
              } else {
                _optPrefix = prefixWithPseudoDirName; // 'pseudoPrefix';
              }
            }

            final _VirtualDirectoryFileData _virtualFileData = new _VirtualDirectoryFileData(
                _containerDirectoryPath,
                _filePathFromContainerDirectory,
                _optPrefix
              );

            if (shouldBeVerbose) {
              ServerLogger.log('Adding virtual file: ' + _virtualFileData.absoluteFileSystemPath + ' at Url: ' + _virtualFileData.httpRequestPath);
            }

            this._virtualDirectoryFiles.add(_virtualFileData);

            break;
          }
        }
      });
    } else {
      ServerLogger.error('The directory path supplied was not found in the filesystem at: (${dir.path})');
    }
  }

  /**
   * All HTTP requests starting the the specified [UrlData] path String parameter will be
   * forwarded to the attached event listener.
   *
   * This is a useful method for catching all API prefixed path requests and handling them
   * in your own style:
   *
   *     .handleRequestsStartingWith(new UrlData('/api/')).listen(apiRouter);
   */
  Stream<HttpRequest> handleRequestsStartingWith(final UrlData urlPathStartData) {
    this._urlPathStartString.add(urlPathStartData);

    return this._functionStore[urlPathStartData.id];
  }

  /*void serveVirtualDirectoryWithAuth() {}*/

  /**
   * Serve the file with zero processing done to it.
   */
  static Future<Null> _serveStandardFile(final String pathToFile, final HttpRequest httpRequest) async {
    try {
      if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('_HttpServerRequestHandler::_serveStandardFile(String, HttpRequest) -> Future<Null>');

      final File standardFile = new File(pathToFile);

      // Does the file exist?
      if (await standardFile.exists()) {
        final String fileExtension = path.extension(standardFile.path);

        // Determine the content-type to send, if possible
        if (HttpServerRequestHandler._fileExtensions.containsKey(fileExtension)) {
          final List<String> _mimeTypePieces = HttpServerRequestHandler._fileExtensions[path.extension(standardFile.path)];

          httpRequest.response.headers.contentType = new ContentType(_mimeTypePieces[0], _mimeTypePieces[1]);
        }

        // Read the file, and send it to the client
        await standardFile.openRead().pipe(httpRequest.response);
      } else { // File not found
        if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.error('File not found at path: ($pathToFile)');

        httpRequest.response
            ..statusCode = HttpStatus.NOT_FOUND
            ..headers.contentType = new ContentType("text", "plain", charset: "utf-8");
      }
    } catch(err) {
      ServerLogger.error(err);
    } finally {
      httpRequest.response.close();
    }
  }
}

/**
 * Replace String variable in an AngularJS style of {{...}} and using a Map to
 * determine the values to replace with. By default, it will switch all variables
 * without a conversion value to an empty String value (e.g. ""), or in Layman's
 * terms, nothing.
 *
 *     // Returns with the variables replaced:
 *     // --> "My name is Bobert Robertson."
 *     applyVarModifiers('My name is {{firstName}} {{lastName}}.', {
 *       "firstName": "Bobert",
 *       "lastName": "Robertson"
 *     });
 */
String applyVarModifiers(String fileContents, final Map<String, dynamic> varModifiers, {final bool clearUnusedVars: true}) {
  varModifiers.forEach((final String key, final dynamic value) {
    fileContents = fileContents.replaceAll('{{$key}}', '$value');
  });

  if (clearUnusedVars) {
    final RegExp _unclaimedVarRegExp = new RegExp(r'{{\S+}}');
    fileContents = fileContents.replaceAll(_unclaimedVarRegExp, '');
  }

  return fileContents;
}

/**
 * Get the ContentType back based on the type of the file path.
 *
 *     // --> ContentType("application", "dart");
 *     final ContentType contentType  =
 *         getContentTypeForFilepathExtension('/dart/modules/unittest.dart');
 */
ContentType getContentTypeForFilepathExtension(final String filePath) {
  final String extension = new RegExp(r'\.\S+$').firstMatch(filePath).group(0);

  if (HttpServerRequestHandler._fileExtensions.containsKey(extension)) {
    final List<String> _fileExtensionData = HttpServerRequestHandler._fileExtensions[extension];

    return new ContentType(_fileExtensionData[0], _fileExtensionData[1]);
  }

  return null;
}

class _VirtualDirectoryFileData {
  final String containerDirectoryPath;
  final String filePathFromContainerDirectory;
  final String optPrefix;

  _VirtualDirectoryFileData(final String this.containerDirectoryPath, final String this.filePathFromContainerDirectory, [final String this.optPrefix = '']);

  String get absoluteFileSystemPath {
    return this.containerDirectoryPath + this.filePathFromContainerDirectory;
  }

  String get httpRequestPath {
    if (this.optPrefix is String &&
        this.optPrefix.isNotEmpty)
    {
      // The this.filePathFromContainerDirectory has a leading "/", add one if there is an optional prefix
      return "/${this.optPrefix}${this.filePathFromContainerDirectory}";
    }

    return this.filePathFromContainerDirectory;
  }
}

/**
 * Factory for creating UrlData holder with a dynamically generated reference ID.
 *
 * This is most often used for telling the server what the navigation Url will
 * be for a method to register at.
 */
class UrlData {
  static int _pageIndex = 0;
  final int id;
  final String path;

  factory UrlData(final String url) {
    return new UrlData._internal(UrlData._pageIndex++, url);
  }

  const UrlData._internal(final int this.id, final String this.path);
}

class _AuthCheckResults {
  final bool didPass;
  final String username;

  const _AuthCheckResults(final bool this.didPass, [final String this.username = null]);
}

/**
 * A user:password base64 encoded auth data.
 *
 * The username parameter is solely for an alias to the specific
 * [AuthUserData]. It does not need to be the same as the [encodedAuth]
 * parameter's username, but most often will be.
 *
 * The [encodedAuth] parameter will be the "user:password" String after having
 * been base64 encoded. These will be used for checking credentials on the server.
 */
class AuthUserData {
  final String username;
  final String encodedAuth;

  const AuthUserData(final String this.username, final String this.encodedAuth);
}

/**
 * Path data for storing with the required auth data.
 */
class _PathDataWithAuth {
  final String urlPath;
  final List<AuthUserData> _authUsersList;

  _PathDataWithAuth(final String this.urlPath, final List<AuthUserData> authUsersList) : this._authUsersList = authUsersList;

  bool doCredentialsMatch(final String encodedAuth) {
    for (AuthUserData authUserData in this._authUsersList) {
      if (authUserData.encodedAuth == encodedAuth) {
        return true;
      }
    }

    return false;
  }

  String getUsernameForCredentials(final String encodedAuth) {
    for (AuthUserData authUserData in this._authUsersList) {
      if (authUserData.encodedAuth == encodedAuth) {
        return authUserData.username;
      }
    }

    return null;
  }
}