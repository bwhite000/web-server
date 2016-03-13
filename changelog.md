WebServer Changelog
===================

v2.0.0+3 (3.5.2016)
-------------------

### Tool Changes

* `web_server` - pub global
  * The developer can now pass a `--port=<port-number>` argument to the executable in the command line to
    specify a specific port, not just the default 8080, for the web server to bind itself to; e.g.
    `web_server --port=80`
  * Added an interpretation of the `--help` or `-h` argument to output details into the terminal about the
    executable and its functionality.
  * Minor understandability improvement to the output terminal log when the server is started.
  * Added another optional developer command line argument for `--host=<address>` to allow binding to a
    specific address, such as only `127.0.0.1`; the default value is `0.0.0.0`.
    
### Documentation/Example Changes
* ReadMe
  * Changed the filename to uppercase to be more inline with README file naming formats.
  * Updated the examples to reflect the new parameters in the web_server tool.
  * Added the very important details about reminding developers to run `pub global activate` on the package
    every once and a while to get the latest updates; also included details about easily checking for breaking
    changes before updating; hopefully the details will make it not-so-scary to update.
* ChangeLog
  * Changed the filename to uppercase to be more inline with CHANGELOG file naming formats.
* Code Example Files
  * `virtual_directory.dart` - (Issue #5) Updated the InternetAddress.LOOPBACK_IP_V4 to be ANY_IP_V4 in the
    example to help out developers new to the package with avoiding the frustration of not catching that they
    were binding only to a local host address when they try out their code on a remote machine and try to access
    their web server.

v2.0.0+2 (1.13.2016)
--------------------

### Tool Changes

* `web_server` - pub global
  * `shouldPreCache` has been changed to false since the Dart language seems to not be closing out filesystem
    connections, even when explicitly coded to, and will error when setting up to serve directories with more
    files than the computer's maximum file connection limit; will now cache as the files are requested instead
    of in advance.

v2.0.0+1 (12.22.2015)
---------------------

### Library Changes
  
* `HttpServerRequestHandler`
  * Added better comments to some methods for the DartDocs generator to make better use of.
  * Removed the need for the '.' in the supportedFileExtensions extension list in `serveStaticVirtualDirectory`
    that was unintentionally introduced in the previous release; functionality still behaved like before,
    but the dot was needed; not anymore now.

### Documentation/Example Changes

* ReadMe
  * Updated some code examples and section information to be easier to understand.
  * Added a code example of preprocessing using the `html` Dart package to show that a developer can modify
    web pages as richly and complexly as they could on the client side, but before even serving the page; this
    way, the developer can have code templates in their web page's HTML, use it on the server like client side
    DOM to fill it with data and clone it, if wanted, then return the built page to the client.
  
* Code Example Files
  * Cleaned-up and fixed the code to be efficiently and aesthetically better; e.g. added the `final` keyword
    in a few missing spots.

* Changelog
  * Made the markdown data easier to read by dividing common change areas into sections; inspired by the
    Changelog pattern in the main Dart SDK GitHub.

v2.0.0 (12.20.2015)
-------------------

### Library Changes

* `WebServer`
  * Added a new constructor for binding a secure server and switched the syntax to using the new Dart 1.13
  BoringSSL format instead of the old NSS method; use the `new WebServer.secure()` constructor to support this.
  * Removed the 'GET' and 'POST' allowedMethods default value so that any type of request header will be
    allowed by default; the developer will no longer have to specify every type of allowed request method.
  * Bumped the default wait time for a response to generate from the server code (response deadline) from
    20 seconds to 30 seconds to allow for more complex response generation to not catch the developer off
    guard as quickly in case the developer isn't coding with this deadline in mind.

* `HttpServerRequestHandler`
  * Added content types for .mp3, .ogg, .oga, .ogv.
  * Changed the \_fileExtensions content types over to using the ContentType Object instead of a List<String>
    and having to build the ContentType Object for every request; also, removed the declaration of it being a
    'const' so that a developer using the server would be able to add their own new content types
    programatically.
  * Some code clean-up and optimizations for the occasional variable reuse optimization or the similar.
  * Created a new format for listening for webpage path requests to make it easier to understand and more
    intuitive by making the event format similar to binding DOM events on a webpage, like, for example, the
    format of `querySelector('...').onClick.listen((_) {})`.
  * Added a method and structures for opening the ability for developers using this package to add their own
    custom error code handlers using `.onErrorDocument()`.
  * Deprecated `serveVirtualDirectory()` in favor of the clearer and having more features, like being dynamic,
    `serveStaticVirtualDirectory()` and `serveDynamicVirtualDirectory()` (arriving eventually; a.k.a. coming
    soon).
  * Renamed the `UrlData` Class to `UrlPath` to make it easier to understand what the Object is representing.
  * `serveStaticVirtualDirectory`
    * Made the requirement of providing a whitelist of supported file extensions
      an optional parameter to allow for serving an entire directory, or a directory with flexible file types,
      simple and not requiring a server restart; also, this makes it possible for the pub global `web_server`
      command to operate with any directory's files.
    * Removed a loop that was checking file extensions on every file entity for a match in the
      `serveStaticVirtualDirectory` and is now doing a `.contains()` on the List to be much faster and loop
      less.
    * Removed the redundant `isRelativePath` parameter.
    * Now, there is a parameter to enable pre-caching for files in this static Directory to make reads pull
      from memory instead of the FileSystem, which will be much faster and economical.
  * Improved the helper methods for sending 404 and 500 errors easily with `sendPageNotFoundResponse()` and
    `sendInternalServerErrorResponse()`; will now use the supplied custom error response HTML from the developer,
    if provided.
  * `serveStaticFile:` Automatically detects relative file paths and more efficiently resolves the relative path
    to access the static file; removed the redundant `isRelativePath` parameter.
    
* Improved some of the verbose error logging by including the name of the Class and method in the error text to
  make debugging easier (especially if manually working with a forked version of this repo and learning how it
  works).

### Tool Changes

* `web_server`
  * Added an `bin/` directory and an executable rule to the Pubspec to enable using this package with `pub global
    activate` and running a server right from a directory using the command line without even having to write any
    code! It's as simple as the `web_server` command from the terminal, and it will serve that directory as a
    `serveStaticVirtualDirectory()` command.

### Documentation/Example Changes

* ReadMe
  * Updates for the new methods and features; clarified and demonstrated features that might not have been as
    well-known or exemplified before; added a testimonial for my work using this package in many side projects
    and work-requested projects at Ebates.
  * Added a section asking other developers to let me know if they are making something exciting using my Dart
    package.
  * Clarification to some of the code examples and section titles; added details about SocialFlare to the
    "Who is using this package?" section.
    
* Code Example Files
  * Updated the code examples directory files to reflect the new API changes and additions from this release.
    
* LICENSE
  * Added a LICENSE file to allow other developers to use this code and for compatibility with the Dart Pub
    requirements.

v1.1.4 (5.14.2015)
------------------
* Found that HttpRequest paths were not matching serveVirtualDirectory() generated paths on
  Windows machines because the Url would be something like: '/main.dart' and Windows would
  provide and store a path segment with the opposite separator at '\main.dart' resulting in
  the String comparison to fail; this has been resolved.

v1.1.3 (5.9.2015)
-----------------
* Added a handleRequestsStartingWith() method for intercepting requests starting with a specified
  string; this is useful for handling everything in API patterns such as starting with '/api/';
  added an example to the examples folder in "example/web_server.dart".

v1.1.2 (5.5.2015)
-----------------
* Removed a single inefficient .runtimeType use.
* Changed a mimetype definition and added more.
* Images and some binary sources were loading incorrectly, so switching to directly piping the
  file contents into the HttpResponse, instead of reading, then adding.
* Fixed issue with the file extension not matching in serveVirtualDirectory if the extension
  was not all lowercase.
* Solved issue with file and directory path building that would assemble incorrectly on Windows
  machines.
* Changed the serveVirtualDirectory() parameter for "includeDirNameInPath" to
  "includeContainerDirNameInPath" for parameter meaning clarity.
* Fixed a broken try/catch when loading a virtual file for a request.
* Made _VirtualDirectoryFileData easier to use by adding getters with clearer meaning such as
  .absoluteFileSystemPath and .httpRequestPath.
* Greatly improved the efficiency of serveStandardFile for certain binary file formats and nicely
  improved speed and memory for all binary file formats.
* Removed UTF-8 from being the default charset for non-matched mimetypes in binary files.
* Removed diffent handling in serveStandardFile based on the mimetype and now all use the same
  piping to the HttpResponse.
* Included another log into shouldBeVerbose guide.
* Nicely clarified some confusing parts of the code.

v1.1.1 (4.26.2015)
-----------------
* Removing the default UTF-8 charset requirement in the response header to allow for different
  file encodings; will re-add the charset soon when encoding detection (appears to be difficult
  at the moment) is implemented.
* Handling for non-UTF8 file encoding by piping the file bytes directly into the response without
  passing through a string decoder first; last release, I understood this differently and the
  behavior was not what I wanted it to behave as; stinkin' byte encoding detection.
* Will re-add the byte encoding to the content-type header soon; I really don't like leaving this
  out in requests, but don't want to prevent clients from serving non-UTF8 files until this can
  be determined.

v1.1.0 (4.25.2015)
------------------
* Renamed the WebServer.webServer library to just WebServer.
* Renamed the WebServer.webSocketConnectionManager library to just WebSocketConnectionManager.
* Added tons more docs, comments, and inline code examples; published Docs online using Jennex
  as the host and placed the link in the Pubspec.
* Implemented the URI Object to make relative file path resolution more accurate.
* Possibly solved issue that appears on Windows when resolving relative paths in
  serveVirtualDirectory() and serverStaticFile().
* Added better honoring of the shouldBeVerbose parameter and changed to static property
  [breaking API change].
* UTF8 encoding was required for files to be read before, but now it will work with any
  encoding and convert it to UTF8 during file read.

v1.0.9 (4.16.2015)
--------------------
* Added a new example for creating virtual directories at "example/virtual_directory.dart".
* Removed some logging that may have been misleading.
* Using a relative sub-directory path in `serveVirtualDirectory()` could lead to incorrect
  path following if the developer did not execute their script from the terminal in the project's
  root directory (such as using an Editor where it goes from the SDK's bin/ folder); fixed this
  by building an absolute directory path using `Platform.script.path` and getting the parent folder
  for the main execution, then building the relative path from there; this will prevent a lot of
  potential confusion for future developers using this Dart package; also added this to
  `serveStaticFile()`.
* Improved some of the comments and code in the example files.
* Added an option to switch off recursive indexing in `serveVirtualDirectory()`.

v1.0.8 (4.15.2015)
------------------
* Added the ApiResponse and ApiErrorResponse classes to help make sending API data easier and
  with consistent formatting.
* Updated the "example/web_server.dart" file to show uses of the new ApiResponse class.

v1.0.7 (4.15.2015)
--------------------
* Added built-in support for basic authentication path registering.
* Code clean-up and DRY clean-up.
* Basic security improvements.
* New public helper methods for returning error pages.
* Helper function for changing "{{...}}" variables in a text file using a key/value Map.
* Updated some namespacing of the libraries.
* (Again) Cleaned-up some files by removing redundant sub-files with the same name as the library
  (e.g. "lib/src/web_server/web_server.dart" -> "lib/src/web_server.dart" - already existed
  to include the sub-file by the same name).
* Initial GitHub package commit!!!

v1.0.6 (4.11.2015)
-----------------
* Cleaned-up some files by removing redundant sub-files with the same name as the library
  (e.g. "lib/src/web_server/web_server.dart" -> "lib/src/web_server.dart" - already existed
  to include the sub-file by the same name).
* Added locking of only certain methods, such as 'GET' or 'POST', at the WebServer level,
  otherwise, a 403 FORBIDDEN status code will be returned.
* Put some limits in for blocking attempts at overloading the server with certain data in an attack.

v1.0.5 (4.2.2015)
-----------------
* Enabled GZIP compression - jeez was that an excellent discovery and improvement!!
* Added a serveVirtualDirectory method.

v1.0.4 (late 2014-early 2015)
-----------------
* Created a folder with examples for how to use the web server.
* Removed access to .on[] for the HttpServerHandler in favor of using .registerUrl().
* An error will be thrown when attempting to create a secure server until the API is completed for
  that feature.
* Renamed .registerUrl() to .registerFile().
* Added .registerDirectory() to allow for manual handling of all immediate sub-items in a directory
  by a single event.

v1.0.3 (12.16.2014)
-------------------
* Original improvements and creation brought over from another of my projects; development that
  started back in June 2014.
* Structure for creating servers bound securely using a security certificate (still not sure how
  to get this fully working, though).