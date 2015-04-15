part of WebServer.webSocketConnectionManager;

class WebSocketObjectStore {
  final Map<String, WebSocketConnection> _mainObjectStore = <String, WebSocketConnection>{};
  final Map<WebSocket, String> _webSocketToUsernameIndex = <WebSocket, String>{};
  final List<WebSocket> _unidentifiedWebSockets = <WebSocket>[];

  WebSocketObjectStore();

  // Getters
  Iterable<String> get keys {
    return this._mainObjectStore.keys;
  }

  Iterable<WebSocketConnection> get values {
    return this._mainObjectStore.values;
  }

  int get length {
    return this._mainObjectStore.length;
  }

  // Util
  void add(final WebSocket webSocket) {
    ServerLogger.log('WebSocketObjectStore.add(WebSocket)');

    this._unidentifiedWebSockets.add(webSocket);
  }

  void remove(final WebSocket webSocketToRemove) {
    ServerLogger.log('WebSocketObjectStore.remove(WebSocket)');

    // If identified, remove using this route
    if (this._webSocketToUsernameIndex.containsKey(webSocketToRemove)) {
      // Get the username that this WebSocket belongs to
      final String usernameToRemove = this._webSocketToUsernameIndex[webSocketToRemove];

      this._webSocketToUsernameIndex.remove(webSocketToRemove);
      this._mainObjectStore.remove(usernameToRemove);
    } else { // Remove if unidentified
      this._unidentifiedWebSockets.remove(webSocketToRemove);
    }
  }

  bool identifyWebSocket(final String username, final WebSocket webSocketToId) {
    ServerLogger.log('WebSocketObjectStore.identifyWebSocket(String, WebSocket)');

    // Verify that the supplied username is valid before registering it
    if (username == null || username.isEmpty || username == "undefined" || username == "null") {
      throw new InvalidConnectionIdException('The username provided is invalid');
    }

    WebSocketConnection connectionData;

    // After searching the List, delete the webSocket at this index
    final bool containsWebSocket = this._unidentifiedWebSockets.contains(webSocketToId);

    // If the WebSocket attempting to identify itself is in the unidentified list
    if (containsWebSocket) {
      ServerLogger.log('WebSocket connection matched from the unidentified connection list.');
      ServerLogger.log('Identifying the connection as: $username');

      // Disconnect the old connection if it is being overridden
      // TODO: Message the old one that it is being overriden and that it shouldn't continue to retry connecting.
      if (this._mainObjectStore.containsKey(username)) {
        ServerLogger.log('The WebSocket connection was already in existence and identified. Closing the old one in preparation to be replaced.');

        this._mainObjectStore[username].webSocket.close(); // Close the old WebSocket connection
        this.remove(this._mainObjectStore[username].webSocket); // Delete the old WebSocket from the object stores
      }

      connectionData = new WebSocketConnection(webSocketToId);

      // Move the WebSocket from unidentified to the identified list with a username as its key
      this._mainObjectStore[username] = connectionData;

      // Create an index of the WebSocket to the username for when removing via WebSocket as key
      this._webSocketToUsernameIndex[webSocketToId] = username;

      this._unidentifiedWebSockets.remove(webSocketToId); // Remove from the unidentified list

      ServerLogger.log('WebSocket connection successfully identified.');

      return true;
    }

    ServerLogger.log('No unidentified WebSocket connection could be matched for identifying');
    return false;
  }

  void clear() {
    ServerLogger.log('WebSocketObjectStore.clear()');

    this._mainObjectStore.values.forEach((final WebSocketConnection webSocketConnection) {
      webSocketConnection.webSocket.close();
    });

    this._unidentifiedWebSockets.forEach((final WebSocket webSocket) {
      webSocket.close();
    });

    this._mainObjectStore.clear();
    this._webSocketToUsernameIndex.clear();
    this._unidentifiedWebSockets.clear();
  }

  String getUsernameForSocket(final WebSocket webSocket) {
    ServerLogger.log('WebSocketObjectStore.getUsernameForSocket(WebSocket)');

    if (this._webSocketToUsernameIndex.containsKey(webSocket)) {
      return this._webSocketToUsernameIndex[webSocket];
    }

    return null;
  }

  WebSocketConnection getWebSocketConnectionForUsername(final String username) {
    ServerLogger.log('WebSocketObjectStore.getWebSocketForUsername(String)');

    if (this._mainObjectStore.containsKey(username)) {
      return this._mainObjectStore[username];
    }

    return null;
  }

  // Operators
  WebSocketConnection operator[] (final String usernameKey) {
    if (this._mainObjectStore.containsKey(usernameKey)) {
      return this._mainObjectStore[usernameKey];
    }

    return null;
  }
}

/**
 * Custom error for when a connection attempts to identify itself using an invalid username
 * format.
 */
class InvalidConnectionIdException implements Exception {
  final String message;

  InvalidConnectionIdException(final String this.message);

  @override
  String toString() {
    return 'InvalidConnectionIdException: ${this.message}';
  }
}