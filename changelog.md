WebServer
=========

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