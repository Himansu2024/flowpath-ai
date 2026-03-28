// lib/services/socket_service.dart
// Socket.IO client for real-time signal updates, congestion alerts, rerouting.

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService {
  IO.Socket? _socket;

  // WebSocket URL — update to your deployed server in production
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  bool get isConnected => _socket?.connected ?? false;

  /// Connect to Socket.IO server and join the user's room.
  void connect(String userId) {
    if (_socket != null && isConnected) return;

    _socket = IO.io(wsUrl, IO.OptionBuilder()
      .setTransports(['websocket', 'polling'])
      .enableAutoConnect()
      .setTimeout(10000)
      .setReconnectionAttempts(5)
      .setReconnectionDelay(2000)
      .build());

    _socket!.onConnect((_) {
      debugPrint('✅ Socket connected: ${_socket!.id}');
      _socket!.emit('join:user', {'userId': userId});
    });

    _socket!.onDisconnect((reason) {
      debugPrint('⚠️ Socket disconnected: $reason');
    });

    _socket!.onConnectError((err) {
      debugPrint('❌ Socket connect error: $err');
    });

    _socket!.onReconnect((_) {
      debugPrint('🔄 Socket reconnected');
      _socket!.emit('join:user', {'userId': userId});
    });
  }

  /// Join admin monitoring room (for dashboard use).
  void joinAdmin(String adminToken) {
    _socket?.emit('join:admin', {'token': adminToken});
  }

  // ── Emit events (client → server) ───────────────────────────

  /// Send live GPS position to server.
  void emitLocation({
    required double lat,
    required double lon,
    required double speedKmh,
    required double heading,
    String? userId,
    String? routeId,
  }) {
    _socket?.emit('vehicle:location', {
      'userId': userId,
      'lat': lat,
      'lon': lon,
      'speedKmh': speedKmh,
      'heading': heading,
      if (routeId != null) 'routeId': routeId,
    });
  }

  /// Notify server that navigation has started.
  void joinNavigation(String routeId, {String? userId}) {
    _socket?.emit('navigation:start', {
      'userId': userId,
      'routeId': routeId,
    });
  }

  /// Notify server that navigation has ended.
  void leaveNavigation(String routeId, {String? userId, Map? stats}) {
    _socket?.emit('navigation:end', {
      'userId': userId,
      'routeId': routeId,
      if (stats != null) 'stats': stats,
    });
  }

  // ── Listen events (server → client) ─────────────────────────

  /// Listen for signal phase updates (emitted every 1 second).
  void onSignalsUpdate(Function(Map<String, dynamic>) callback) {
    _socket?.on('signals:update', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  /// Listen for congestion alerts.
  void onCongestionAlert(Function(Map<String, dynamic>) callback) {
    _socket?.on('congestion:alert', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  /// Listen for rerouting trigger (server detected off-route).
  void onRerouting(Function(Map<String, dynamic>) callback) {
    _socket?.on('navigation:rerouting', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  /// Listen for vehicle position updates (admin dashboard only).
  void onVehicleUpdate(Function(Map<String, dynamic>) callback) {
    _socket?.on('vehicle:update', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  /// Remove a specific event listener.
  void off(String event) => _socket?.off(event);

  /// Disconnect and clean up.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
