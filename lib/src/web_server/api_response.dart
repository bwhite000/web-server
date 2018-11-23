part of WebServer;

/**
 * An output generator for successful API responses.
 *
 *     // Create the Object for the response
 *     final ApiResponse apiResponse = new ApiResponse()
 *         ..addData('foodType', 'ice cream') // Add data
 *         ..addData('flavor', 'vanilla')
 *         ..addData('alternateFlavors', 5); // Add numeric values, too!
 *
 *     // Send the data back through to the request
 *     httpRequest.response
 *         // Set to "application/json; charset=utf-8"
 *         ..headers.contentType = ContentType.JSON
 *
 *         // Stringify the JSON output, then send to client
 *         ..write(apiResponse.toJsonEncoded())
 *
 *         ..close();
 */
class ApiResponse {
  final Map<String, dynamic> _dataToAdd = {};

  /// Default constructor.
  ApiResponse();

  /**
   * Add data to the response message.
   *
   *     apiResponse.addData('animal', 'cat'); // Add Strings,
   *
   *     apiResponse.addData('numberOfCats', 3); // numbers,
   *
   *     // Lists, too,
   *     apiResponse.addData('furTypes', [
   *         'long', 'medium', 'short'
   *     ]);
   *
   *     // and Maps!
   *     apiResponse.addData('catData', {
   *         "name": "Mr. Fluffle",
   *         "age": 3
   *     });
   */
  void addData(final String keyName, final dynamic value) {
    this._dataToAdd[keyName] = value;
  }

  /**
   * Output as Json.
   *
   *     // Returns from the [addData] example above:
   *     {
   *       "success": true, // <-- For a 'false' value, use [ApiErrorResponse] Object
   *       "animal": "cat",
   *       "numberOfCats": 3,
   *       "furTypes": ["long", "medium", "short"],
   *       "catData": {
   *         "name": "Mr. Fluffle",
   *         "age": 3
   *       }
   *     }
   */
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> response = <String, dynamic>{
      "success": true
    };

    this._dataToAdd.forEach((final String keyName, final dynamic value) {
      response[keyName] = value;
    });

    return response;
  }

  /**
   * Calls [toJson], then processes it through [JSON.encode()] before returning.
   */
  String toJsonEncoded() {
    return convert.json.encode(this.toJson());
  }
}

/**
 * An output generator for API responses where something went wrong, such as forgetting
 * a parameter or something erring server-side while generating the values.
 */
class ApiErrorResponse {
  /// An optional message about the error.
  String errorMessage;

  /// An optional error code.
  String errorCode;

  ApiErrorResponse([final String this.errorMessage, final String this.errorCode]);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> response = <String, dynamic>{
      "success": false
    };

    if (this.errorMessage != null) {
      response['errorMessage'] = this.errorMessage;
    }

    if (this.errorCode != null) {
      response['errorCode'] = this.errorCode;
    }

    return response;
  }

  String toJsonEncoded() {
    return convert.json.encode(this.toJson());
  }
}