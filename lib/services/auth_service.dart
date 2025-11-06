import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:medplus/models/auth_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // ⚠️ Update this when your ngrok URL rotates
  static const String baseUrl =
      'https://multistratified-puppyishly-latrina.ngrok-free.dev';
  static const String signupEndpoint = '/auth/register';
  static const String loginEndpoint = '/auth/login';
  static const String meEndpoint = '/auth/me';

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? _currentUser;

  // ------------------ AUTH CALLS ------------------

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
      debugPrint('Signup: POST $url');
      debugPrint('Signup payload: ${signupRequest.toJson()}');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              // Workaround some proxies (ngrok/HTTP2) that may return 421 on reused connections
              'Connection': 'close',
            },
            body: jsonEncode(signupRequest.toJson()),
          )
          .timeout(const Duration(seconds: 20));

      // Some APIs return 200, others 201
      if (response.statusCode == 200 || response.statusCode == 201) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        await _saveAuthData(authResponse); // consistent token+user storage
        return authResponse;
      }

      // Try to parse API error details safely
      try {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to sign up');
      } catch (_) {
        debugPrint('Signup failed [${response.statusCode}]: ${response.body}');
        throw Exception('Failed to sign up (HTTP ${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Signup request timed out');
    } on SocketException {
      throw Exception('No Internet connection');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  static Future<AuthResponse> login(String email, String password) async {
    final url = Uri.parse('$baseUrl$loginEndpoint');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              // backend expects 'username' form field; you pass email in it
              'username': email,
              'password': password,
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        await _saveAuthData(authResponse);
        return authResponse;
      }

      try {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to login');
      } catch (_) {
        throw Exception('Failed to login (HTTP ${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Login request timed out');
    } on SocketException {
      throw Exception('No Internet connection');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // ------------------ USER ------------------

  static Future<User?> getCurrentUser({bool forceRefresh = false}) async {
    if (_instance._currentUser != null && !forceRefresh) {
      return _instance._currentUser;
    }

    final token = await getToken();
    if (token == null) return null;

    if (isTokenExpired(token)) {
      // Avoid auto-logout; let caller decide re-auth flow
      return null;
    }

    final url = Uri.parse('$baseUrl$meEndpoint');

    try {
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final user = User.fromJson(jsonDecode(response.body));
        _instance._currentUser = user;

        // ✅ ALWAYS store a Map via toJson()
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(user.toJson()));
        return user;
      } else if (response.statusCode == 401) {
        // Avoid auto-logout on a single /me 401; surface null and let UI handle
        return null;
      } else {
        return null;
      }
    } on TimeoutException {
      // Fallback to cache on timeout
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        _instance._currentUser = User.fromJson(jsonDecode(userJson));
        return _instance._currentUser;
      }
      return null;
    } catch (e) {
      // Offline/cache fallback
      if (e is SocketException || e is TimeoutException) {
        final prefs = await SharedPreferences.getInstance();
        final userJson = prefs.getString(_userKey);
        if (userJson != null) {
          _instance._currentUser = User.fromJson(jsonDecode(userJson));
          return _instance._currentUser;
        }
      }
      return null;
    }
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      _instance._currentUser = null;
      debugPrint('Successfully logged out and removed auth data');
    } catch (e, stackTrace) {
      debugPrint('Error during logout: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // ------------------ TOKEN HELPERS ------------------

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;

    if (isTokenExpired(token)) {
      // Avoid auto-logout here; simply report not logged in
      return false;
    }
    return true;
  }

  static Future<bool> isUserLoggedIn() => isLoggedIn();

  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);

      if (token != null && isTokenExpired(token)) {
        // Avoid auto-logout when token is expired; return null to trigger re-auth
        return null;
      }
      return token;
    } catch (e, stackTrace) {
      debugPrint('Error getting token: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  static Future<void> _saveAuthData(AuthResponse authResponse) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, authResponse.accessToken);
    _instance._currentUser = authResponse.user;
    // ✅ CRITICAL: encode a Map, not an object
    await prefs.setString(_userKey, jsonEncode(authResponse.user.toJson()));
  }

  static bool isTokenExpired(String token) {
    try {
      final claims = JwtDecoder.decode(token);
      final dynamic exp = claims['exp'];
      if (exp is int) {
        final expTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        return expTime.isBefore(DateTime.now());
      }
      // If no exp claim, assume not expired (opaque tokens or non-standard JWTs)
      return false;
    } catch (_) {
      // If decode fails, assume not expired to avoid false logouts; 401s will surface naturally
      return false;
    }
  }

  static Future<DateTime?> getTokenExpiration() async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final claims = JwtDecoder.decode(token);
      final dynamic exp = claims['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
