// lib/services/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketService {
  final String roomCode;
  final String participantId;
  final Function(Map<String, dynamic>) onMessage;

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  int _reconnectDelay = 2; // detik

  static String get _baseWsUrl {
    // Ganti https → wss untuk WebSocket
    const base = 'https://retrace-credible-upstate.ngrok-free.dev';
    return base
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }

  WebSocketService({
    required this.roomCode,
    required this.participantId,
    required this.onMessage,
  });

  void connect() {
    _shouldReconnect = true;
    _connect();
  }

  void _connect() {
    try {
      final uri = Uri.parse('$_baseWsUrl/ws/$roomCode/$participantId');

      _channel = IOWebSocketChannel.connect(uri);

      _isConnected = true;
      _reconnectDelay = 2; // reset delay setelah berhasil connect
      debugPrint('WebSocket connected: $roomCode');

      _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            onMessage(message);
          } catch (e) {
            debugPrint('WebSocket parse error: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          debugPrint('WebSocket closed: $roomCode');
          _scheduleReconnect();
        },
        onError: (error) {
          _isConnected = false;
          debugPrint('WebSocket error: $error');
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isConnected = false;
      debugPrint('WebSocket connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      if (_shouldReconnect) {
        debugPrint('WebSocket reconnecting... (delay: ${_reconnectDelay}s)');
        _reconnectDelay = (_reconnectDelay * 2).clamp(2, 30); // max 30 detik
        _connect();
      }
    });
  }

  void send(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('WebSocket send error: $e');
      }
    }
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
    debugPrint('WebSocket disconnected: $roomCode');
  }

  bool get isConnected => _isConnected;
}
