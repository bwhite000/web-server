part of WebServer.webServer;

class _HttpServerRequestHandler {
  final FunctionStore _functionStore = new FunctionStore();
  final Map<String, int> _possibleFiles = <String, int>{};
  final Map<String, int> _possibleDirectories = <String, int>{};
  final List<_VirtualDirectoryFileData> _virtualDirectoryFiles = <_VirtualDirectoryFileData>[];
  final List<PathDataWithAuth> _pathDataForAuthList = <PathDataWithAuth>[];
  final String strForUnauthorizedError = '401 - Unauthorized';

  static const Map<String, List<String>> _fileExtensions = const <String, List<String>>{
    ".html": const <String>["text", "html"],
    ".css": const <String>["text", "css"],
    ".js": const <String>["text", "javascript"],
    ".dart": const <String>["application", "dart"],
    ".txt": const <String>["text", "plain"],
    ".png": const <String>["image", "png"],
    ".jpg": const <String>["image", "jpg"],
    ".gif": const <String>["image", "gif"],
    ".webp": const <String>["image", "webp"],
    ".svg": const <String>["image", "svg+xml"],
    ".otf": const <String>["font", "otf"],
    ".woff": const <String>["font", "woff"],
    ".woff2": const <String>["font", "woff2"],
    ".ttf": const <String>["font", "ttf"],
    ".rar": const <String>["application", "x-rar-compressed"],
    ".zip": const <String>["application", "zip"]
  };
  bool shouldBeVerbose = false;

  _HttpServerRequestHandler();

  // Util
  void _onHttpRequest(final HttpRequest httpRequest) {
    ServerLogger.log('_HttpServerRequestHandler.onRequest()');
    ServerLogger.log('Requested Url: ${httpRequest.uri.path}');

    final String path = httpRequest.uri.path;

    // Is there basic auth needed for this path.
    if (this._doesThisPathRequireAuth(path)) { // BasicAuth IS required
      final PathDataWithAuth pathDataWithAuthForPath = this._getAcceptedCredentialsForPath(path);
      final AuthCheckResults authCheckResults = this._checkAuthFromRequest(httpRequest, pathDataWithAuthForPath);

      if (authCheckResults.didPass) {
        final int urlId = this._possibleFiles[path];
        this._functionStore.runEvent(urlId, httpRequest);
      } else {
        _HttpServerRequestHandler.sendRequiredBasicAuthResponse(httpRequest, this.strForUnauthorizedError);
      }

      return;
    } else { // BasicAuth is NOT required
      // Check if the URL matches a registered file and that a URL ID is in the FunctionStore
      if (this._possibleFiles.containsKey(path) &&
          this._functionStore.fnStore.containsKey(this._possibleFiles[path]))
      {
        ServerLogger.log('Url has matched to a file. Routing to it...');

        final int urlId = this._possibleFiles[path];

        this._functionStore.runEvent(urlId, httpRequest);
      } else {
        bool wasVirtualFileMatched = false;

        for (_VirtualDirectoryFileData virtualFilePathData in this._virtualDirectoryFiles) {
          // If the requested path matches a virtual path
          if (httpRequest.uri.path == virtualFilePathData.virtualFilePathWithPrefix) {
            wasVirtualFileMatched = true;
            try {
              // Serve the matched virtual file
              _HttpServerRequestHandler._serveStandardFile('${virtualFilePathData.directoryPath}${virtualFilePathData.virtualFilePath}', httpRequest);
            } catch (err) {
              ServerLogger.error(err);
            }

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
            ServerLogger.log('Url has matched to a directory. Routing to it...');

            final int urlId = this._possibleDirectories[possibleDirectoryPath];

            this._functionStore.runEvent(urlId, httpRequest);
          } else { // Respond with 404 error because nothing was matched.
            ServerLogger.log('No registered url match found.');

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
    ServerLogger.log('HttpServerRequestHandler.registerPathWithAuth() -> Stream<HttpRequest>');

    if (authUserList.length == 0) {
      throw 'There are no users in the list of authorized users.';
    }

    final PathDataWithAuth pathDataWithAuth = new PathDataWithAuth(pathToRegister.path, authUserList);

    this._pathDataForAuthList.add(pathDataWithAuth);
    this._possibleFiles[pathToRegister.path] = pathToRegister.id;

    return this._functionStore[pathToRegister.id];
  }

  /// Does this request path need to be handled by the authentication engine?
  bool _doesThisPathRequireAuth(final String pathName) {
    for (PathDataWithAuth pathDataWithAuth in this._pathDataForAuthList) {
      // Do the paths match?
      if (pathDataWithAuth.urlPath == pathName) {
        return true;
      }
    }

    return false;
  }

  PathDataWithAuth _getAcceptedCredentialsForPath(final String pathName) {
    for (PathDataWithAuth pathDataWithAuth in this._pathDataForAuthList) {
      // Do the paths match?
      if (pathDataWithAuth.urlPath == pathName) {
        return pathDataWithAuth;
      }
    }

    return null;
  }

  AuthCheckResults _checkAuthFromRequest(final HttpRequest httpRequest, final PathDataWithAuth acceptedCredentialsPathData) {
    // If no auth header supplied
    if (httpRequest.headers.value(HttpHeaders.AUTHORIZATION) == null) {
      return const AuthCheckResults(false);
    }

    const int MAX_ALLOWED_CHARACTER_RANGE = 256;
    final String authHeaderStr = httpRequest.headers.value(HttpHeaders.AUTHORIZATION); // Get the provided auth info
    final int trimRange = (authHeaderStr.length <= MAX_ALLOWED_CHARACTER_RANGE) ? authHeaderStr.length : MAX_ALLOWED_CHARACTER_RANGE; // Determine subStr amt
    final String clientProvidedAuthInfo = authHeaderStr.substring(0, trimRange).replaceFirst(new RegExp('^Basic '), ''); // Remove the prefixed "Basic " from auth header

    if (acceptedCredentialsPathData.doCredentialsMatch(clientProvidedAuthInfo)) {
      return new AuthCheckResults(true, acceptedCredentialsPathData.getUsernameForCredentials(clientProvidedAuthInfo));
    }

    return const AuthCheckResults(false);
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
    if (isRelativeFilePath) {
      pathToFile = '${path.dirname(Platform.script.path)}/$pathToFile'.replaceAll('%20', ' ');
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
      ServerLogger.error('The file at path ($pathToFile) was not found in the filesystem; unable to serve it.');
    }
  }

  /**
   * Automatically handle serving this path, after handling required basic authentication.
   *
   * [pathToFile] - The filesystem path to locate the file to serve.
   * [varModifiers] - A key/value map of modifiers to automatically replace in the file
   * [enableCaching] - Should the file be cached in-memory; updates the cache when a newer copy is found.
   */
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

  /**
   * Serve this entire directory automatically, but only for the allowed file extensions.
   *
   * [pathToDirectory] - The path to this directory to server files recursively from.
   * [supportedFileExtensions] - A list of file extensions (without the "." before the extension name) that are allowed to be served from this directory.
   * [includeDirNameInPath] - Should the folder being served also have it's name in the browser navigation path; such as serving a 'js/' folder while retaining 'js/' in the browser Url; default is false.
   * [shouldFollowLinks] - Should SymLinks be treated as they are in this directory and, therefore, served?
   */
  Future<Null> serveVirtualDirectory(String pathToDirectory, final List<String> supportedFileExtensions, {
    final bool includeDirNameInPath: false,
    final bool shouldFollowLinks: false,
    final String prefixWithDirName: '',
    final bool isRelativeDirPath: true,
    final bool parseForFilesRecursively: true
  }) async {
    ServerLogger.log('_HttpServerRequestHandler.serveVirtualDirectory(String, List, {bool}) -> Future<Null>');

    // Make sure that supported file extensions were supplied.
    if (supportedFileExtensions == null || supportedFileExtensions.length == 0) {
      throw 'There were no supported file extensions set. Nothing would have been included from this directory.';
    }

    if (isRelativeDirPath) {
      pathToDirectory = '${path.dirname(Platform.script.path)}/$pathToDirectory'.replaceAll('%20', ' ');
    }

    // Get the directory for virtualizing
    final Directory dir = new Directory(pathToDirectory);
    final String thisDirName = path.basename(pathToDirectory);
    final RegExp matchThisDirNameAtEnd = new RegExp('/' + thisDirName + r'$');
    final RegExp matchPathToDirectoryAtStart = new RegExp(r'^' + pathToDirectory);

    // If the directory exists
    if (await dir.exists()) {
      // Loop through all of the entities in this directory and determine which ones to make serve later.
      dir.list(recursive: parseForFilesRecursively, followLinks: shouldFollowLinks).listen((final FileSystemEntity entity) async {
        final FileStat fileStat = await entity.stat();

        for (String supportedFileExtension in supportedFileExtensions) {
          // If this is a file AND ends with a supported file extension
          if (fileStat.type == FileSystemEntityType.FILE && entity.path.endsWith('.$supportedFileExtension')) {
            final _VirtualDirectoryFileData _virtualFileData = new _VirtualDirectoryFileData(
                (includeDirNameInPath) ? pathToDirectory.replaceFirst(matchThisDirNameAtEnd, '') : pathToDirectory,
                prefixWithDirName + ((includeDirNameInPath) ? '/$thisDirName' : '') + entity.path.replaceFirst(matchPathToDirectoryAtStart, ''),
                ((includeDirNameInPath) ? '/$thisDirName' : '') + entity.path.replaceFirst(matchPathToDirectoryAtStart, '')
              );

            if (shouldBeVerbose) {
              ServerLogger.log('Adding virtual file: ' + _virtualFileData.directoryPath + _virtualFileData.virtualFilePath + ' at Url: ' + _virtualFileData.virtualFilePath);
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

  static void serveVirtualDirectoryWithAuth() {}

  /**
   * Serve the file with zero processing done to it.
   */
  static Future<Null> _serveStandardFile(final String pathToFile, final HttpRequest httpRequest) async {
    try {
      ServerLogger.log('_HttpServerRequestHandler::_serveStandardFile(String, HttpRequest) -> Future<Null>');

      final File standardFile = new File(pathToFile);

      // Does the file exist?
      if (await standardFile.exists()) {
        final String fileExtension = path.extension(standardFile.path);
        dynamic contentsOfFile;

        // If the file needs to be read as bytes
        if (fileExtension == '.png' ||
            fileExtension == '.jpg' ||
            fileExtension == '.gif' ||
            fileExtension == '.webp' ||
            fileExtension == '.otf' ||
            fileExtension == '.woff' ||
            fileExtension == '.woff2' ||
            fileExtension == '.ttf' ||
            fileExtension == '.rar' ||
            fileExtension == '.zip')
        {
          contentsOfFile = await standardFile.readAsBytes();

          // Determine the content type to send
          if (_HttpServerRequestHandler._fileExtensions.containsKey(fileExtension)) {
            final List<String> _mimeTypePieces = _HttpServerRequestHandler._fileExtensions[path.extension(standardFile.path)];

            httpRequest.response.headers.contentType = new ContentType(_mimeTypePieces[0], _mimeTypePieces[1]);
          } else {
            httpRequest.response.headers.contentType = new ContentType("text", "plain", charset: "utf-8");
          }

          // Do the bytes need to be converted back to characters?
          // (not sure if this is necessary, but readAsString() would otherwise fail for these types - probably charset?)
          if (fileExtension == '.otf' ||
              fileExtension == '.woff' ||
              fileExtension == '.woff2' ||
              fileExtension == '.ttf' ||
              fileExtension == '.zip')
          {
            httpRequest.response.write(new String.fromCharCodes(contentsOfFile));
          } else {
            httpRequest.response.write(contentsOfFile);
          }
        } else {
          contentsOfFile = await standardFile.readAsString();

          // Determine the content type to send
          if (_HttpServerRequestHandler._fileExtensions.containsKey(fileExtension)) {
            final List<String> _mimeTypePieces = _HttpServerRequestHandler._fileExtensions[path.extension(standardFile.path)];

            httpRequest.response.headers.contentType = new ContentType(_mimeTypePieces[0], _mimeTypePieces[1], charset: "utf-8");
          } else {
            httpRequest.response.headers.contentType = new ContentType("text", "plain", charset: "utf-8");
          }

          httpRequest.response.write(contentsOfFile);
        }
      } else { // File not found
        ServerLogger.error('File not found at path: ($pathToFile)');

        httpRequest.response
            ..statusCode = HttpStatus.NOT_FOUND
            ..headers.contentType = new ContentType("text", "plain", charset: "utf-8")
            ..write(r'404 - Page not found')
            ..close();
      }
    } catch(err) {
      ServerLogger.error(err);
    } finally {
      httpRequest.response.close();
    }
  }
}

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

/// Get the ContentType back based on the type of file path;
/// e.g. hello_world.html -> ContentType("text", "html")
ContentType getContentTypeForFilepathExtension(final String filePath) {
  final String extension = new RegExp(r'\.\S+$').firstMatch(filePath).group(0);

  if (_HttpServerRequestHandler._fileExtensions.containsKey(extension)) {
    final List<String> _fileExtensionData = _HttpServerRequestHandler._fileExtensions[extension];

    return new ContentType(_fileExtensionData[0], _fileExtensionData[1]);
  }

  return null;
}

class _VirtualDirectoryFileData {
  final String directoryPath;
  final String virtualFilePathWithPrefix;
  final String virtualFilePath;

  _VirtualDirectoryFileData(final String this.directoryPath, final String this.virtualFilePathWithPrefix, final String this.virtualFilePath);
}

/**
 * Factory for creating UrlData holder with a dynamically generated ID.
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

class AuthCheckResults {
  final bool didPass;
  final String username;

  const AuthCheckResults(final bool this.didPass, [final String this.username = null]);
}

class AuthUserData {
  final String username;
  final String encodedAuth;

  const AuthUserData(final String this.username, final String this.encodedAuth);
}

/**
 * Path data for storing with the required auth data.
 */
class PathDataWithAuth {
  final String urlPath;
  final List<AuthUserData> _authUsersList;

  PathDataWithAuth(final String this.urlPath, final List<AuthUserData> authUsersList) : this._authUsersList = authUsersList;

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