import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medplus/models/medical_record.dart';
import 'package:medplus/services/auth_service.dart';

class HistoryService {
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  static const Duration timeout = Duration(seconds: 10);

  // Get user's medical history
  static Future<List<MedicalRecord>> getUserHistory() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('$baseUrl/user/history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => MedicalRecord.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load history: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get blood pressure history
  static Future<List<Map<String, dynamic>>> getBloodPressureHistory() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('$baseUrl/user/blood-pressure/history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to load blood pressure history: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get appointment history
  static Future<List<MedicalRecord>> getAppointmentHistory() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('$baseUrl/user/appointments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((json) => MedicalRecord.fromJson(json))
            .where((record) => record.type == 'appointment')
            .toList();
      } else {
        throw Exception('Failed to load appointments: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get prescription history
  static Future<List<MedicalRecord>> getPrescriptionHistory() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('$baseUrl/user/prescriptions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((json) => MedicalRecord.fromJson(json))
            .where((record) => record.type == 'prescription')
            .toList();
      } else {
        throw Exception('Failed to load prescriptions: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get lab report history
  static Future<List<MedicalRecord>> getLabReportHistory() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('$baseUrl/user/lab-reports'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((json) => MedicalRecord.fromJson(json))
            .where((record) => record.type == 'lab_report')
            .toList();
      } else {
        throw Exception('Failed to load lab reports: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
