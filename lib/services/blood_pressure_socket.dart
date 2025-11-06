import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
// import 'package:medplus/services/auth_service.dart';

/// Message types for WebSocket communication (optional)
enum MessageType { connection, new_reading, success, error, ping, pong, unknown }

/// Blood pressure reading model
class BloodPressureReading {
  final String id;
  final int systolic;
  final int diastolic;
  final int? pulse;
  final DateTime timestamp;
  final String severity;

  BloodPressureReading({
    required this.id,
    required this.systolic,
    required this.diastolic,
    this.pulse,
    DateTime? timestamp,
    this.severity = 'normal',
  }) : timestamp = timestamp ?? DateTime.now();

  factory BloodPressureReading.fromJson(Map<String, dynamic> json) {
    return BloodPressureReading(
      id: (json['id'] ?? '').toString(),
      systolic: (json['systolic'] as num).toInt(),
      diastolic: (json['diastolic'] as num).toInt(),
      pulse: json['pulse'] == null ? null : (json['pulse'] as num).toInt(),
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : DateTime.now(),
      severity: (json['severity'] ?? 'normal').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'systolic': systolic,
        'diastolic': diastolic,
        if (pulse != null) 'pulse': pulse,
        'timestamp': timestamp.toIso8601String(),
        'severity': severity,
      };
}

class BloodPressureSocket {
  // Use the local WebSocket endpoint
  static String get _baseWsUrl {
    // For ngrok, we need to use wss://
    return 'wss://multistratified-puppyishly-latrina.ngrok-free.dev/blood-pressure/ws';
  }

  final String token;
  final Duration connectionTimeout;
  final Duration reconnectDelay;
  final int maxReconnectAttempts;

  WebSocket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  Timer? _heartbeatTimer;
  Timer? _pongTimer;
  Timer? _reconnectTimer;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  BloodPressureSocket({
    required this.token,
    this.connectionTimeout = const Duration(seconds: 10),
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 5,
  });

  /// Streams
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Stream<BloodPressureReading> get readingsStream => messageStream
      .where((m) => m['type'] == 'new_reading' && m['data'] != null)
      .map((m) => BloodPressureReading.fromJson(Map<String, dynamic>.from(m['data'])));

  Stream<bool> get connectionStatusStream =>
      messageStream.where((m) => m['type'] == 'connection' || m['type'] == 'disconnected').map((m) => m['type'] == 'connection');

  /// State
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  int get reconnectAttempts => _reconnectAttempts;

  String get _wsUrlWithToken => '$_baseWsUrl?token=$token';

  Future<void> connect() async {
    if (_isDisposed || _isConnecting) return;

    _isConnecting = true;
    try {
      // Close any old socket first
      await _safeClose();

      // Exponential backoff between attempts
      if (_reconnectAttempts > 0) {
        final delay = Duration(seconds: min(_reconnectAttempts * 2, 30));
        developer.log('⏳ Reconnect delay ${delay.inSeconds}s', name: 'BloodPressureSocket');
        await Future.delayed(delay);
      }

      if (_isDisposed) return;

      _emitMessage('connection', {
        'message': 'Connecting...',
        'attempt': _reconnectAttempts + 1,
        'max_attempts': maxReconnectAttempts,
      });

      final url = _wsUrlWithToken;
      developer.log('🔌 Connecting to $url', name: 'BloodPressureSocket');
      
      _socket = await WebSocket.connect(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Origin': 'https://multistratified-puppyishly-latrina.ngrok-free.dev',
        },
      ).timeout(connectionTimeout, onTimeout: () {
        throw TimeoutException('Connection timeout after ${connectionTimeout.inSeconds}s');
      });

      if (_isDisposed) {
        await _safeClose();
        return;
      }

      _isConnected = true;
      _reconnectAttempts = 0;
      developer.log('✅ WebSocket connected', name: 'BloodPressureSocket');

      _socket!.listen(
        _handleIncomingMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: true,
      );

      _startHeartbeat();

      _emitMessage('connection', {'message': 'Connected successfully'});
    } on TimeoutException catch (e) {
      _handleError('Timeout: ${e.message}');
    } on WebSocketException catch (e) {
      _handleError('WebSocket error: ${e.message}');
    } catch (e, st) {
      _handleError('Failed to connect: $e\n$st');
    } finally {
      _isConnecting = false;
      if (!_isConnected) {
        _scheduleReconnect();
      }
    }
  }

  void _handleIncomingMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final type = (msg['type'] ?? '').toString();

      if (type == 'ping') {
        _sendPong();
        return;
      }
      if (type == 'pong') {
        _pongTimer?.cancel();
        return;
      }

      // Handle connection acknowledgment
      if (type == 'connection') {
        developer.log('🔌 ${msg['message']}', name: 'BloodPressureSocket');
      }

      // Handle new readings
      if (type == 'new_reading' && msg['data'] != null) {
        final readingData = Map<String, dynamic>.from(msg['data'] as Map);
        // Add the reading to the message for the readingsStream
        _messageController.add({
          'type': 'new_reading',
          'data': readingData,
          'alerts': msg['alerts'],
        });
        return;
      }

      // Pass other messages through
      _messageController.add(msg);
    } catch (e, st) {
      developer.log('❌ Parse error: $e', name: 'BloodPressureSocket', error: e, stackTrace: st);
      _messageController.addError('Error parsing message: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendPing());
  }

  void _sendPing() {
    try {
      if (!_isConnected || _socket == null) return;
      _pongTimer?.cancel();
      _pongTimer = Timer(const Duration(seconds: 5), () {
        _handleError('No pong from server');
      });
      _socket!.add(jsonEncode({'type': 'ping'}));
    } catch (e) {
      _handleError('Failed to send ping: $e');
    }
  }

  void _sendPong() {
    try {
      if (_socket == null) return;
      _socket!.add(jsonEncode({'type': 'pong'}));
    } catch (e) {
      _handleError('Failed to send pong: $e');
    }
  }

  void _handleError(dynamic error) {
    if (_isDisposed) return;
    developer.log('❌ Socket error: $error', name: 'BloodPressureSocket');

    if (!_messageController.isClosed) {
      _messageController.add({
        'type': 'error',
        'message': error.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    _isConnected = false;
    _scheduleReconnect();
  }

  void _handleDone() {
    if (_isDisposed) return;
    developer.log('🔌 Socket closed', name: 'BloodPressureSocket');
    _isConnected = false;

    if (!_messageController.isClosed) {
      _messageController.add({
        'type': 'disconnected',
        'message': 'Disconnected from server',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed || _isConnecting) return;
    if (_reconnectAttempts >= maxReconnectAttempts) {
      developer.log('❌ Max reconnect attempts reached', name: 'BloodPressureSocket');
      if (!_messageController.isClosed) {
        _messageController.add({
          'type': 'error',
          'message': 'Connection lost. Please refresh.',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: min(_reconnectAttempts * 2, 30));
    developer.log('🔄 Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$maxReconnectAttempts)',
        name: 'BloodPressureSocket');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_isDisposed || _isConnected || _isConnecting) return;
      connect();
    });
  }

  Future<void> sendReading({
    required int systolic,
    required int diastolic,
    int? pulse,
    DateTime? timestamp,
  }) async {
    if (_isDisposed || !_isConnected || _socket == null) {
      throw StateError('Not connected to WebSocket');
    }
    final payload = {
      'systolic': systolic,
      'diastolic': diastolic,
      if (pulse != null) 'pulse': pulse,
      'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
    };
    try {
      _socket!.add(jsonEncode(payload));
      developer.log('📤 Sent reading $payload', name: 'BloodPressureSocket');
      
      // Emit a local success message with the reading
      _emitMessage('success', {
        'reading_id': 'local-${DateTime.now().millisecondsSinceEpoch}',
        'message': 'Reading sent successfully',
        'data': payload,
      });
    } catch (e) {
      _handleError('Failed to send reading: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _isDisposed = true;
    await _safeClose();
    if (!_messageController.isClosed) {
      await _messageController.close();
    }
  }

  Future<void> _safeClose() async {
    _heartbeatTimer?.cancel();
    _pongTimer?.cancel();
    _reconnectTimer?.cancel();

    try {
      await _socket?.close();
    } catch (e) {
      developer.log('Error closing socket: $e', name: 'BloodPressureSocket');
    } finally {
      _socket = null;
      _isConnected = false;
      _isConnecting = false;
    }
  }

  void _emitMessage(String type, Map<String, dynamic> data) {
    if (_isDisposed || _messageController.isClosed) return;
    _messageController.add({
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      ...data,
    });
  }
}
