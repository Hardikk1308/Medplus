import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:medplus/services/auth_service.dart';

class LogsService {
 static const String _medicineMeEndpoint = '/patient/medicine/me';
static const String _symptomsMeEndpoint = '/patient/symptoms/me';

  static Future<List<dynamic>> getMyMedicineLogs() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    final url = Uri.parse('${AuthService.baseUrl}$_medicineMeEndpoint');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    debugPrint('getMyMedicineLogs failed [${res.statusCode}] ${res.body}');
    throw Exception('Failed to load medicine logs');
  }

  static Future<List<dynamic>> getMySymptoms() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    final url = Uri.parse('${AuthService.baseUrl}$_symptomsMeEndpoint');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    debugPrint('getMySymptoms failed [${res.statusCode}] ${res.body}');
    throw Exception('Failed to load symptoms');
  }
}
