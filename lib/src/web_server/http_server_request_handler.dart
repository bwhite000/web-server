part of WebServer;

typedef ErrorPageListenerFn(HttpRequest httpRequest);

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
  final List<UrlPath> _urlPathStartString = <UrlPath>[];

  /// The message text that will be returned in the response when a BasicAuth request fails.
  final String strForUnauthorizedError = '401 - Unauthorized';

  static Map<String, ContentType> _fileExtensions = <String, ContentType>{
    ".html": new ContentType("text", "html"),
    ".css": new ContentType("text", "css"),
    ".js": new ContentType("text", "javascript"),
    ".dart": new ContentType("application", "dart"),
    ".txt": new ContentType("text", "plain"),
    ".png": new ContentType("image", "png"),
    ".jpg": new ContentType("image", "jpeg"),
    ".jpeg": new ContentType("image", "jpeg"),
    ".gif": new ContentType("image", "gif"),
    ".ico": new ContentType("image", "x-icon"),
    ".webp": new ContentType("image", "webp"),
    ".mp3": new ContentType("audio", "mpeg3"),
    ".oga": new ContentType("audio", "ogg"),
    ".ogv": new ContentType("video", "ogg"),
    ".ogg": new ContentType("application", "ogg"),
    ".svg": new ContentType("image", "svg+xml"),
    ".otf": new ContentType("font", "otf"),
    ".woff": new ContentType("font", "woff"),
    ".woff2": new ContentType("font", "woff2"),
    ".ttf": new ContentType("font", "ttf"),
    ".rar": new ContentType("application", "x-rar-compressed"),
    ".zip": new ContentType("application", "zip")
  };
  static bool shouldBeVerbose = false;
  // The int is the HttpStatus
  final Map<int, ErrorPageListenerFn> _errorCodeListenerFns = <int, ErrorPageListenerFn>{};

  HttpServerRequestHandler();

  // Getter
  void onErrorDocument(final int httpStatus, ErrorPageListenerFn errorPageListenerFn) {
    this._errorCodeListenerFns[httpStatus] = errorPageListenerFn;
  }

  void _callListenerForErrorDocument(final int httpStatus, final HttpRequest httpRequest) {
    if (this._errorCodeListenerFns.containsKey(httpStatus)) {
      // Set the default status code, but the developer is welcome to override it in their error handler function
      httpRequest.response.statusCode = httpStatus;

      this._errorCodeListenerFns[httpStatus](httpRequest);
    } else { // Default handler
      httpRequest.response
          ..statusCode = httpStatus
          ..headers.contentType = new ContentType('text', 'plain', charset: 'utf-8')
          ..write('$httpStatus Error')
          ..close();
    }
  }

  // Util
  Future<Null> _onHttpRequest(final HttpRequest httpRequest) async {
    if (HttpServerRequestHandler.shouldBeVerbose) {
      ServerLogger.log('_HttpServerRequestHandler.onRequest()');
      ServerLogger.log('Requested Url: ${httpRequest.uri.path}');
    }

    final String requestPath = httpRequest.uri.path;

    // Is there basic auth needed for this path.
    if (this._doesThisPathRequireAuth(requestPath)) { // BasicAuth IS required
      final _PathDataWithAuth pathDataWithAuthForPath = this._getAcceptedCredentialsForPath(requestPath);
      final _AuthCheckResults authCheckResults = this._checkAuthFromRequest(httpRequest, pathDataWithAuthForPath);

      if (authCheckResults.didPass) {
        final int urlId = this._possibleFiles[requestPath];

        this._functionStore.runEvent(urlId, httpRequest);
      } else {
        HttpServerRequestHandler.sendRequiredBasicAuthResponse(httpRequest, this.strForUnauthorizedError);
      }

      return;
    } else { // BasicAuth is NOT required
      // Is this a 'startsWith' registered path?
      for (UrlPath _urlData in this._urlPathStartString) {
        if (requestPath.startsWith(_urlData.path)) {
          this._functionStore.runEvent(_urlData.id, httpRequest);

          return;
        }
      }

      // Check if the URL matches a registered file and that a URL ID is in the FunctionStore
      // NOTE: This format is being deprecated in favor of using the RequestPath Object.
      if (this._possibleFiles.containsKey(requestPath) &&
          this._functionStore.fnStore.containsKey(this._possibleFiles[requestPath]))
      {
        if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('Url has matched to a file. Routing to it...');

        final int urlId = this._possibleFiles[requestPath];

        this._functionStore.runEvent(urlId, httpRequest);
      } else if (RequestPath._possibleUrlDataFormats.containsKey(requestPath) &&
          RequestPath._functionStore.fnStore.containsKey(RequestPath._possibleUrlDataFormats[requestPath]))
      {
        if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('Url has matched to a file in RequestPath Object. Routing to it...');

        final int urlId = RequestPath._possibleUrlDataFormats[requestPath];

        RequestPath._functionStore.runEvent(urlId, httpRequest);
      } else {
        bool wasVirtualFileMatched = false;

        // Look for the request path in the registered virtual file list
        for (_VirtualDirectoryFileData virtualFilePathData in this._virtualDirectoryFiles) {
          // If the requested path matches a virtual path
          if (requestPath == virtualFilePathData.httpRequestPath) {
            wasVirtualFileMatched = true;

            final String fileContents = await Cache.matchFile(new Uri.file(virtualFilePathData.absoluteFileSystemPath));

            // If the fileContents are not empty, then the file must be present in the Cache;
            // otherwise, read the file and serve it as a standard served file.
            if (fileContents != null) {
              final String extension = path.extension(virtualFilePathData.absoluteFileSystemPath);

              // Check if the file extension matches a registered one, then add the Http response header for it, if it matches.
              if (HttpServerRequestHandler._fileExtensions.containsKey(extension)) {
                httpRequest.response.headers.contentType = HttpServerRequestHandler._fileExtensions[extension];
              }

              httpRequest.response
                  ..write(fileContents)
                  ..close();
            } else {
              // Serve the matched virtual file
              this._serveStandardFile('${virtualFilePathData.containerDirectoryPath}${virtualFilePathData.filePathFromContainerDirectory}', httpRequest).catchError(ServerLogger.error);
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
            if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('Url has matched to a directory. Routing to it...');

            final int urlId = this._possibleDirectories[possibleDirectoryPath];

            this._functionStore.runEvent(urlId, httpRequest);
          } else { // Respond with 404 error because nothing was matched.
            if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('No registered url match found.');

            this._callListenerForErrorDocument(HttpStatus.NOT_FOUND, httpRequest);
          }
        }
      }
    }
  }

  /**
   * Register a file and return a Stream for adding a listeners to when that filepath is requested.
   *
   * DEPRECATED: Please begin using forUrlData(UrlData).onRequest.listen() instead.
   */
  @deprecated
  Stream<HttpRequest> registerFile(final UrlPath urlData) {
    this._possibleFiles[urlData.path] = urlData.id;

    return this._functionStore[urlData.id];
  }

  RequestPath forRequestPath(final UrlPath urlPath) {
    return new RequestPath(urlPath);
  }

  /**
   * Require basic authentication by the client to view this Url path.
   *
   * [pathToRegister] - The path that will navigated to in order to call this; e.g. "/support/client/contact-us"
   * [authUserList] - A list of
   */
  Stream<HttpRequest> registerPathWithBasicAuth(final UrlPath pathToRegister, final List<AuthUserData> authUserList) {
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

  /// Helper for sending an HTTP 401 Auth required response
  static void sendRequiredBasicAuthResponse(final HttpRequest httpRequest, final String errMessage) {
    httpRequest.response
        ..statusCode = HttpStatus.UNAUTHORIZED
        ..headers.add(HttpHeaders.WWW_AUTHENTICATE, 'Basic realm="Enter credentials"')
        ..write(errMessage)
        ..close();
  }

  /// Helper for sending a HTTP 404 response with an optional custom HTML error message.
  static void sendPageNotFoundResponse(final HttpRequest httpRequest, [final String responseVal = '404 - Page not found']) {
    httpRequest.response
        ..statusCode = HttpStatus.NOT_FOUND
        ..headers.contentType = new ContentType('text', 'html', charset: 'utf-8')
        ..write(responseVal)
        ..close();
  }

  /// Helper for sending an HTTP 500 response with an optional custom HTML error message.
  static void sendInternalServerErrorResponse(final HttpRequest httpRequest, [final String responseVal = '500 - Internal Server Error']) {
    httpRequest.response
        ..statusCode = HttpStatus.INTERNAL_SERVER_ERROR
        ..headers.contentType = new ContentType('text', 'html', charset: 'utf-8')
        ..write(responseVal)
        ..close();
  }

  Stream<HttpRequest> registerDirectory(final UrlPath urlData) {
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
   */
  Future<Null> serveStaticFile(final UrlPath urlData, String pathToFile, {
    final bool enableCaching: true
  }) async {
    // Is the provided path a relative path that needs to be made absolute?
    if (path.isRelative(pathToFile)) {
      pathToFile = path.join(Directory.current.path, pathToFile);

      if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('Resolved the Uri to be: ($pathToFile)');
    }

    // Checking the file system for the file
    final File file = new File(pathToFile);

    if (await file.exists()) {
      // The file exists, lets configure the http request and serve it

      String _fileContents; // The contents of the file, if caching is enabled

      final ContentType _contentType = getContentTypeForFilepathExtension(pathToFile);

      this._possibleFiles[urlData.path] = urlData.id;

      this._functionStore[urlData.id].listen((final HttpRequest httpRequest) async {

        String _localFileContents;

        if (enableCaching == true) {
          // Use a cached file, or initialize the cached file, if enabled

          _fileContents = await Cache.matchFile(new Uri.file(pathToFile));

          if (_fileContents == null) {
            // If a version has not been cached before
            _fileContents = await file.readAsString();
            if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('adding $pathToFile to cache');
            // Store the file in the cache for serving next load
            Cache.addFile(new Uri.file(pathToFile, windows: Platform.isWindows));
          }

          _localFileContents = _fileContents;
        } else if (enableCaching == false) {
          // Read freshly, if caching is not enabled
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

  // Deprecating in favor of serverStaticVirtualDirectory and serveDynamicVirtualDirectory
  @deprecated
  Future<Null> serveVirtualDirectory(String pathToDirectory, final List<String> supportedFileExtensions, {
    final bool includeContainerDirNameInPath: false,
    final bool shouldFollowLinks: false,
    final String prefixWithPseudoDirName: '',
    final bool isRelativeDirPath: true,
    final bool parseForFilesRecursively: true
  }) {
    return this.serveStaticVirtualDirectory(pathToDirectory,
        supportedFileExtensions: supportedFileExtensions,
        includeContainerDirNameInPath: includeContainerDirNameInPath,
        shouldFollowLinks: shouldFollowLinks,
        prefixWithPseudoDirName: prefixWithPseudoDirName,
        parseForFilesRecursively: parseForFilesRecursively);
  }

  /**
   * Serve this entire directory automatically, but only for the allowed file extensions. Parses the
   * files in the Directory when the server is started, and will reflect changes to those files, but
   * will not serve files newly added to the directory after the static scraping has happened.
   *
   * [pathToDirectory] - The path to this directory to server files recursively from.
   * [supportedFileExtensions] - A list of file extensions (without the "." before the extension name) that are allowed to be served from this directory.
   * [includeContainerDirNameInPath] - Should the folder being served also have it's name in the browser navigation path; such as serving a 'js/' folder while retaining 'js/' in the browser Url; default is false.
   * [shouldFollowLinks] - Should SymLinks be treated as they are in this directory and, therefore, served?
   * [prefixWithPseudoDirName]
   * [parseForFilesRecursively]
   *
   *     new WebServer().serveVirtualDirectory('web/js',
   *       supportedFileExtensions: ['html', 'dart', 'js', 'css'],
   *       shouldPreCache: true,
   *       parseForFilesRecursively: false);
   */
  Future<Null> serveStaticVirtualDirectory(String pathToDirectory, {
    final List<String> supportedFileExtensions: null,
    final bool shouldPreCache: false,
    final bool includeContainerDirNameInPath: false,
    final bool shouldFollowLinks: false,
    final String prefixWithPseudoDirName: '',
    final bool parseForFilesRecursively: true
  }) async {
    if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('_HttpServerRequestHandler.serveVirtualDirectory(String, List, {bool}) -> Future<Null>');

    final Completer<Null> completer = new Completer<Null>();

    // Make sure that more than zero supported file extensions were supplied, if a List was supplied.
    if (supportedFileExtensions != null && supportedFileExtensions.length == 0) {
      throw 'There were no supported file extensions set in the List. Nothing would have been included from this directory.';
    }

    // Is the provided directory path for virtualizing a relative path that needs to be made absolute?
    if (path.isRelative(pathToDirectory)) {
      pathToDirectory = path.join(Directory.current.path, pathToDirectory);

      if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('Resolved the Uri to be: ($pathToDirectory)');
    }

    // Get the directory for virtualizing.
    final Directory dir = new Directory(pathToDirectory);

    // If the directory exists
    if (await dir.exists()) {
      // The directory entity looper will not hold this method from returning when using `await`,
      // so this List must be used to add all of the Futures to and wait for them to complete.
      final List<Future> _queueOfCacheEventsToWaitFor = <Future>[];

      // Loop through all of the entities in this directory and determine which ones to make serve later.
      dir.list(recursive: parseForFilesRecursively, followLinks: shouldFollowLinks).listen((final FileSystemEntity entity) async {
        final FileStat fileStat = await entity.stat();

        // Don't process if this is not a file.
        if (fileStat.type != FileSystemEntityType.FILE) {
          return;
        }

        // Does this Filesystem entity need to be filtered by its file extension?
        if (supportedFileExtensions != null) {
          // Change the returned '.html' to 'html', for example, to match the supportedFileExtensions list.
          final String _extWithoutDot = path.extension(entity.path).replaceFirst(new RegExp(r'^\.'), '');

          if (supportedFileExtensions.contains(_extWithoutDot)) {
            _addFileToVirtualDirectoryListing(entity, pathToDirectory, includeContainerDirNameInPath, prefixWithPseudoDirName);

            if (shouldPreCache) {
              _queueOfCacheEventsToWaitFor.add(Cache.addFile(entity.uri, shouldPreCache: true));
            }
          }
        } else {
          _addFileToVirtualDirectoryListing(entity, pathToDirectory, includeContainerDirNameInPath, prefixWithPseudoDirName);

          if (shouldPreCache) {
            _queueOfCacheEventsToWaitFor.add(Cache.addFile(entity.uri, shouldPreCache: true));
          }
        }
      }, onDone: () {
        // If there are files to wait for to add to Cache, wait for all of these to return.
        if (_queueOfCacheEventsToWaitFor.isNotEmpty) {
          Future.wait(_queueOfCacheEventsToWaitFor).then((_) {
            completer.complete();
          });
        } else {
          completer.complete();
        }
      });
    } else {
      ServerLogger.error('The directory path supplied was not found in the filesystem at: (${dir.path})');

      completer.complete();
    }

    return completer.future;
  }

  void _addFileToVirtualDirectoryListing(final FileSystemEntity entity,
      final String pathToDirectory,
      final bool includeContainerDirNameInPath,
      final String prefixWithPseudoDirName)
  {
    final String _containerDirectoryPath = pathToDirectory;
    final String _filePathFromContainerDirectory = entity.path.replaceFirst(_containerDirectoryPath, '');
    String _optPrefix = (includeContainerDirNameInPath) ? path.basename(_containerDirectoryPath) : '';

    if (prefixWithPseudoDirName != null &&
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

    if (HttpServerRequestHandler.shouldBeVerbose) {
      ServerLogger.log('Adding virtual file: ' + _virtualFileData.absoluteFileSystemPath + ' at Url: ' + _virtualFileData.httpRequestPath);
    }

    this._virtualDirectoryFiles.add(_virtualFileData);
  }

  // Coming soon! (commented at 12.20.2015 during v2.0.0 development)
  //Future<Null> serveDynamicVirtualDirectory() async {}

  /**
   * All HTTP requests starting the the specified [UrlPath] path String parameter will be
   * forwarded to the attached event listener.
   *
   * This is a useful method for catching all API prefixed path requests and handling them
   * in your own style:
   *
   *     .handleRequestsStartingWith(new UrlData('/api/')).listen(apiRouter);
   */
  Stream<HttpRequest> handleRequestsStartingWith(final UrlPath urlPathStartData) {
    this._urlPathStartString.add(urlPathStartData);

    return this._functionStore[urlPathStartData.id];
  }

  // Arriving eventually!
  // void serveVirtualDirectoryWithAuth() {}

  /**
   * Serve the file with zero processing done to it.
   */
  Future<Null> _serveStandardFile(final String pathToFile, final HttpRequest httpRequest) async {
    try {
      if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.log('_HttpServerRequestHandler::_serveStandardFile(String, HttpRequest) -> Future<Null>');

      final File standardFile = new File(pathToFile);

      // Does the file exist?
      if (await standardFile.exists()) {
        final String fileExtension = path.extension(standardFile.path);

        // Determine the content-type to send, if possible
        if (HttpServerRequestHandler._fileExtensions.containsKey(fileExtension)) {
          httpRequest.response.headers.contentType = HttpServerRequestHandler._fileExtensions[fileExtension];
        }

        // Read the file, and send it to the client
        await standardFile.openRead().pipe(httpRequest.response);
      } else { // File not found
        if (HttpServerRequestHandler.shouldBeVerbose) ServerLogger.error('_HttpServerRequestHandler::_serveStandardFile(String, HttpRequest) - File not found at path: ($pathToFile)');

        this._callListenerForErrorDocument(HttpStatus.NOT_FOUND, httpRequest);
      }
    } catch(err, stackTrace) {
      ServerLogger.error(err);
      ServerLogger.error(stackTrace);
    } finally {
      httpRequest.response.close();
    }
  }

  /**
   * Add a new content type to the server that didn't come prepackaged with the server.
   */
  static void addContentType(final String fileExtension, final ContentType contentType) {
    HttpServerRequestHandler._fileExtensions[fileExtension] = contentType;
  }
}

class RequestPath {
  static final FunctionStore _functionStore = new FunctionStore();
  static final Map<String, int> _possibleUrlDataFormats = <String, int>{};
  UrlPath urlData;

  RequestPath(final UrlPath this.urlData);

  Stream<HttpRequest> get onRequest {
    RequestPath._possibleUrlDataFormats[urlData.path] = urlData.id;

    return RequestPath._functionStore[urlData.id];
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
    return HttpServerRequestHandler._fileExtensions[extension];
  }

  return null;
}

class _VirtualDirectoryFileData {
  final String containerDirectoryPath; // e.g. "/Users/Test/home/server_project/web"
  final String filePathFromContainerDirectory; // e.g. "dart/index_page/main.dart"
  String _slashSafeFilePathFromContainerDirectoryForHttpRequests; // e.g. the [filePathFromContainerDirectory] with '\' converted to '/' for Url path matching (Windows quirk)
  final String _optPrefix; // Optional prefix before the file path in the public Url path

  _VirtualDirectoryFileData(final String this.containerDirectoryPath, final String this.filePathFromContainerDirectory, [final String this._optPrefix = '']) {
    if (path.separator == '\\' && this.filePathFromContainerDirectory.startsWith(path.separator)) {
      this._slashSafeFilePathFromContainerDirectoryForHttpRequests = this.filePathFromContainerDirectory.replaceAll(path.separator, '/');
    } else {
      this._slashSafeFilePathFromContainerDirectoryForHttpRequests = this.filePathFromContainerDirectory;
    }
  }

  String get absoluteFileSystemPath {
    return this.containerDirectoryPath + this.filePathFromContainerDirectory;
  }

  String get httpRequestPath {
    if (this._optPrefix != null &&
        this._optPrefix.isNotEmpty)
    {
      // The this.filePathFromContainerDirectory has a leading "/", add another one if there is an optional prefix
      return "/${this._optPrefix}${this._slashSafeFilePathFromContainerDirectoryForHttpRequests}";
    }

    return this._slashSafeFilePathFromContainerDirectoryForHttpRequests;
  }
}

/**
 * Factory for creating UrlData holder with a dynamically generated reference ID.
 *
 * This is most often used for telling the server what the navigation Url will
 * be for a method to register at.
 */
class UrlPath {
  static int _pageCounterIndex = 0;
  final int id;
  final String path;

  factory UrlPath(final String urlPath) {
    return new UrlPath._internal(UrlPath._pageCounterIndex++, urlPath);
  }

  const UrlPath._internal(final int this.id, final String this.path);
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