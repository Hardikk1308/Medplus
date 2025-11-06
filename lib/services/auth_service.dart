import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:medplus/models/auth_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // 🔧 FIX: remove the leading space before https://
  static const String baseUrl = 'https://multistratified-puppyishly-latrina.ngrok-free.dev';
  static const String signupEndpoint = '/auth/register';
  static const String loginEndpoint = '/auth/login';
  static const String meEndpoint = '/auth/me';

  static Future<AuthResponse> signup({
    required String email,
    required String username,
    required String password,
    required String fullName,
    required String role,
    String? doctorId,
  }) async {
    final url = Uri.parse('$baseUrl$signupEndpoint');

    final signupRequest = SignupRequest(
      email: email,
      username: username,
      password: password,
      fullName: fullName,
      role: role,
      doctorId: doctorId,
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(signupRequest.toJson()),
      );

      if (response.statusCode == 201) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', authResponse.accessToken);
        return authResponse;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to sign up');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  static Future<AuthResponse> login(String email, String password) async {
    final url = Uri.parse('$baseUrl$loginEndpoint');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          // If your backend expects 'email' instead of 'username', change this key.
          'username': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', authResponse.accessToken);
        return authResponse;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to login');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  static Future<User?> getCurrentUser() async {
    final token = await getToken();
    if (token == null) return null;

    final url = Uri.parse('$baseUrl$meEndpoint');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        if (response.statusCode == 401) {
          await logout();
        }
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<void> logout() async {
    try {
      // 🔧 Do not allow null prefs; let it throw if init fails so we can catch.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      debugPrint('Successfully logged out and removed token');
    } catch (e, stackTrace) {
      debugPrint('Error during logout: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Keep this name since the UI now calls isLoggedIn()
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // (Optional) alias to match any older UI code
  static Future<bool> isUserLoggedIn() => isLoggedIn();

  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      debugPrint(token != null
          ? 'Token retrieved from SharedPreferences'
          : 'No token found in SharedPreferences');
      return token;
    } catch (e, stackTrace) {
      debugPrint('Error getting token: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
}
