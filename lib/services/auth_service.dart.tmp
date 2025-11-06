import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:medplus/services/SecureStorageService.dart'; // Import the new service

class AuthService {
  // ⚠️ IMPORTANT: Using the full endpoint as base URL based on your provided code
  static const String _baseUrl =
      'https://multistratified-puppyishly-latrina.ngrok-free.dev/auth/login';

  /// Handles user login via API and saves the JWT token on success.
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        // Login Successful
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String accessToken = responseData['access_token'];

        // 🏆 Save the access token securely!
        await SecureStorageService.saveToken(accessToken);
        
        debugPrint('✅ Login Successful. Token Saved.');
        return true;
      } else {
        // Login Failed
        debugPrint('❌ Login failed with status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      // Network error or other exception
      debugPrint('🚨 An error occurred during login: $e');
      return false;
    }
  }

  /// Checks if a JWT token is present in secure storage.
  Future<bool> isUserLoggedIn() async {
    final token = await SecureStorageService.getToken();
    return token != null;
  }
  
  /// Removes the token to log the user out.
  Future<void> logout() async {
    await SecureStorageService.deleteToken();
    debugPrint('👋 User logged out (token deleted).');
  }
}