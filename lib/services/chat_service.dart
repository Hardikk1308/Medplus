import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medplus/services/auth_service.dart';

class ChatService {
  static const String _chatCreateEndpoint = '/chat/create';
  static const String _chatQueryEndpoint = '/chat';

  static Future<String?> _getToken() async {
    // Use the canonical token source so it matches login/signup storage
    final token = await AuthService.getToken();
    debugPrint(
      'ChatService: token present? ${token != null && token.isNotEmpty}',
    );
    return token;
  }

  static Future<Map<String, dynamic>> createChat(
    String name,
    String initialMessage,
  ) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated. Please log in again.');
    }
    final url = Uri.parse('${AuthService.baseUrl}$_chatCreateEndpoint');
    debugPrint('ChatService: POST $url');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Connection': 'close',
      },
      body: jsonEncode({
        'name': "Sarthak",
        'initial_message': initialMessage,
        'data': {},
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      debugPrint('ChatService: createChat success (${response.statusCode})');
      final data = jsonDecode(response.body);
      // Store chat ID in local storage
      final prefs = await SharedPreferences.getInstance();
      final dynamicId = data['id'] ?? data['chat_id'];
      if (dynamicId is String && dynamicId.isNotEmpty) {
        await prefs.setString('chat_id', dynamicId);
      } else {
        debugPrint(
          'ChatService: createChat returned missing chat id in body: $data',
        );
      }
      return data;
    } else if (response.statusCode == 401) {
      final body = response.body;
      debugPrint(
        'ChatService: createChat unauthorized (401) body: '
        '${body.length > 200 ? body.substring(0, 200) : body}',
      );
      // Do not auto-logout here; let the UI handle re-auth flow gracefully
      throw Exception('Session expired. Please log in again.');
    } else {
      final body = response.body;
      debugPrint(
        'ChatService: createChat failed (${response.statusCode}) body: '
        '${body.length > 200 ? body.substring(0, 200) : body}',
      );
      throw Exception('Failed to create chat (HTTP ${response.statusCode})');
    }
  }

  static Future<Map<String, dynamic>> sendMessage(
    String message, {
    String? chatId,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated. Please log in again.');
    }
    final prefs = await SharedPreferences.getInstance();

    // If no chatId is provided, try to get it from local storage
    String? currentChatId = chatId ?? prefs.getString('chat_id');

    // If still no chatId, create a new chat
    if (currentChatId == null) {
      final newChat = await createChat('Health Consultation', message);
      final dynamicId = newChat['id'] ?? newChat['chat_id'];
      if (dynamicId is String && dynamicId.isNotEmpty) {
        currentChatId = dynamicId;
        await prefs.setString('chat_id', currentChatId);
      } else {
        throw Exception('Chat creation succeeded but no chat_id was returned');
      }
    }

    final url = Uri.parse(
      '${AuthService.baseUrl}$_chatQueryEndpoint/$currentChatId/query',
    );

    // Emit token diagnostics to help track 401s
    final tokenExp = await AuthService.getTokenExpiration();
    debugPrint('ChatService: POST $url');
    debugPrint(
      'ChatService: token starts with: ${token.substring(0, 10)}... '
      'exp: ${tokenExp?.toIso8601String()}',
    );
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Connection': 'close',
      },
      body: jsonEncode({'query': message}),
    );

    if (response.statusCode == 200) {
      debugPrint('ChatService: sendMessage success (200)');
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      final body = response.body;
      debugPrint(
        'ChatService: sendMessage unauthorized (401) body: '
        '${body.length > 200 ? body.substring(0, 200) : body}',
      );
      // Do not auto-logout here; let the UI handle re-auth flow gracefully
      throw Exception('Session expired. Please log in again.');
    } else {
      final body = response.body;
      debugPrint(
        'ChatService: sendMessage failed (${response.statusCode}) body: '
        '${body.length > 200 ? body.substring(0, 200) : body}',
      );
      throw Exception('Failed to send message (HTTP ${response.statusCode})');
    }
  }

  static Future<void> clearChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_id');
  }
}
