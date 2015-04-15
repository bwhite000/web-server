part of WebServer.webServer;

/**
 * Create this class and pass the toJsonEncoded() as an API respones for a successful API response.
 */
class ApiResponse {
  final Map<String, dynamic> _dataToAdd = {};

  ApiResponse();

  void addData(final String keyName, final dynamic value) {
    this._dataToAdd[keyName] = value;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> response = <String, dynamic>{
      "success": true
    };

    this._dataToAdd.forEach((final String keyName, final dynamic value) {
      response[keyName] = value;
    });

    return response;
  }

  String toJsonEncoded() {
    return JSON.encode(this.toJson());
  }
}

/**
 * Create this class and pass the toJsonEncoded() as an API response for something that went wrong.
 */
class ApiErrorResponse {
  String errorMessage;
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
    return JSON.encode(this.toJson());
  }
}