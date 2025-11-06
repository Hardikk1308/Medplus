class SignupRequest {
  final String email;
  final String username;
  final String password;
  final String fullName;
  final String role;
  final String? doctorId;

  SignupRequest({
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
      'full_name': fullName,
      'role': role,
      if (role == 'patient' && doctorId != null) 'doctor_id': doctorId,
    };
  }
}

class AuthResponse {
  final String accessToken;
  final User user;

  AuthResponse({
    required this.accessToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'],
      user: User.fromJson(json['user']),
    );
  }
}

class User {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role;
  final bool isActive;
  final bool isVerified;
  final String authProvider;
  final DateTime createdAt;

  User({
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
    return User(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      fullName: json['full_name'] ?? '',
      role: json['role'],
      isActive: json['is_active'] ?? false,
      isVerified: json['is_verified'] ?? false,
      authProvider: json['auth_provider'] ?? 'email',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
