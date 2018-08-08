/**
 * An additional library for managing WebSocket connections that works
 * very well with the WebServer library.
 */
library WebSocketConnectionManager;

import "dart:io";
import "package:dart2_constant/convert.dart" as convert;
import "package:server_logger/server_logger.dart" as ServerLogger;

part 'src/web_socket_connection_manager/web_socket_object_store.dart';
part 'src/web_socket_connection_manager/ws_connection.dart';

abstract class WebSocketConnectionManager {
  static final WebSocketObjectStore objectStore = new WebSocketObjectStore();

  static void broadcastMessageToAllIdentified(final Map<String, dynamic> message) {
    ServerLogger.log('WebSocketConnectionManager::broadcastMessageToAllIdentified()');
    ServerLogger.log('Broadcasting message to (${WebSocketConnectionManager.objectStore.length}) clients: \n$message');

    WebSocketConnectionManager.objectStore.values.forEach((final WebSocketConnection webSocketConnection) {
      webSocketConnection.webSocket.add(convert.json.encode(message));
    });
  }
}