WebServer Changelog
===================

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