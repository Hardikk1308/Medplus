import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  // Create storage
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';

  // Write token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // Read token
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Delete token (for logout)
  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }
}