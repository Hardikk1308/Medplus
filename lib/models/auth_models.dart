// lib/models/auth_models.dart
import 'package:flutter/foundation.dart';

@immutable
class SignupRequest {
  final String email;
  final String username;
  final String password;
  final String fullName;
  final String role;
  final String? doctorId;

  const SignupRequest({
    required this.email,
    required this.username,
    required this.password,
    required this.fullName,
    required this.role,
    this.doctorId,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'username': username,
      'password': password,
      // use snake_case if your FastAPI/Pydantic backend expects it
      'full_name': fullName,
      'role': role,
      if (role == 'patient' && doctorId != null) 'doctor_id': doctorId,
    };
  }
}

@immutable
class AuthResponse {
  final String accessToken;
  final String tokenType; // often "bearer"
  final User user;

  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // accept snake_case or camelCase
    final token = (json['access_token'] ?? json['accessToken'] ?? '').toString();
    final type = (json['token_type'] ?? json['tokenType'] ?? 'bearer').toString();

    final userJson = json['user'];
    if (userJson is! Map) {
      throw const FormatException('AuthResponse.user missing or not an object');
    }

    return AuthResponse(
      accessToken: token,
      tokenType: type,
      user: User.fromJson(userJson.cast<String, dynamic>()),
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        'user': user.toJson(),
      };
}

@immutable
class User {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role;
  final bool isActive;
  final bool isVerified;
  final String authProvider;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.isVerified,
    required this.authProvider,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // accept both snake_case and camelCase fields from backend
    final created = json['created_at'] ?? json['createdAt'];
    DateTime? createdAt;
    if (created != null) {
      createdAt = DateTime.tryParse(created.toString());
    }

    return User(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      fullName: (json['full_name'] ?? json['fullName'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      isActive: (json['is_active'] ?? json['isActive'] ?? false) == true,
      isVerified: (json['is_verified'] ?? json['isVerified'] ?? false) == true,
      authProvider: (json['auth_provider'] ?? json['authProvider'] ?? 'email').toString(),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'username': username,
        'full_name': fullName, // switch to 'fullName' if your API expects camelCase
        'role': role,
        'is_active': isActive,
        'is_verified': isVerified,
        'auth_provider': authProvider,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
