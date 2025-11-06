// lib/services/medical_record_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medplus/models/medical_record.dart';
import 'auth_service.dart';

/// Service layer for fetching and creating medical-related data.
///
/// IMPORTANT:
/// - Patients should use `/patient/symptoms/me`.
/// - Doctors must use `/patient/symptoms/{patient_id}` with a valid UUID.
///   Calling `/me` as a doctor produces a 422 (UUID parse error).
class MedicalRecordService {
  // Reuse the baseUrl from AuthService to keep things in sync
  static const String baseUrl = AuthService.baseUrl;

  static const Duration timeout = Duration(seconds: 30);
  static final http.Client _client = http.Client();

  /// PATIENT ONLY — fetches the current patient's symptoms using `/me`.
  static Future<List<MedicalRecord>> getMySymptoms() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl/patient/symptoms/me');
    _logGet(url, token);

    final res = await _client
        .get(url, headers: _headers(token))
        .timeout(timeout);

    _logResponse(res);
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body);
      return data.map((e) => MedicalRecord.fromJson(e)).toList();
    }
    throw Exception('Failed to load my symptoms: ${res.statusCode}');
  }

  /// DOCTOR ONLY — fetches symptoms for a specific patient UUID.
  static Future<List<MedicalRecord>> getPatientSymptoms(
    String patientId,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl/patient/symptoms/$patientId');
    _logGet(url, token);

    final res = await _client
        .get(url, headers: _headers(token))
        .timeout(timeout);

    _logResponse(res);
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body);
      return data.map((e) => MedicalRecord.fromJson(e)).toList();
    }
    throw Exception('Failed to load patient symptoms: ${res.statusCode}');
  }

  /// Backwards-compatible wrapper used by Home screen:
  /// - If user is PATIENT → fetch `/patient/symptoms/me`
  /// - If user is DOCTOR  → returns an empty list (no patient selected)
  ///
  /// Call [getPatientSymptoms(patientId)] when the doctor selects a patient.
  static Future<List<MedicalRecord>> getMedicalRecords() async {
    try {
      final me = await AuthService.getCurrentUser();
      if (me == null) throw Exception('Not authenticated');

      final role = me.role?.toLowerCase() ?? '';
      if (role == 'patient') {
        return getMySymptoms();
      } else if (role == 'doctor') {
        // Return empty list for doctors - they need to select a patient first
        return [];
      } else {
        throw Exception('Unknown role: $role');
      }
    } catch (e) {
      debugPrint('Error in getMedicalRecords: $e');
      rethrow;
    }
  }

  /// Create appointment (patient).
  /// Expects keys like:
  /// {
  ///   "appointment_datetime": "2025-12-15T14:30:00Z",
  ///   "type": "in-person",
  ///   "duration": 30,
  ///   "reason": "Follow-up",
  ///   "notes": "Optional"
  /// }
  static Future<MedicalRecord> createAppointment(
    Map<String, dynamic> data,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl/appointments');
    _logPost(url, token, data);

    final res = await _client
        .post(
          url,
          headers: _headers(token, isJson: true),
          body: json.encode(data),
        )
        .timeout(timeout);

    _logResponse(res);
    if (res.statusCode == 201) {
      return MedicalRecord.fromJson(json.decode(res.body));
    }
    throw Exception('Failed to create appointment: ${res.statusCode}');
  }

  /// Fetch prescriptions for current user (role-based access enforced by backend).
  static Future<List<MedicalRecord>> getPrescriptions() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl/prescriptions');
    _logGet(url, token);

    final res = await _client
        .get(url, headers: _headers(token))
        .timeout(timeout);

    _logResponse(res);
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body);
      return data.map((e) => MedicalRecord.fromJson(e)).toList();
    }
    throw Exception('Failed to load prescriptions: ${res.statusCode}');
  }

  /// Fetch lab reports.
  /// Patients: `/patient/lab-reports/me`
  /// Doctors : `/patient/lab-reports` (for assigned/accessible patients)
  static Future<List<MedicalRecord>> getLabReports() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');

    final me = await AuthService.getCurrentUser();
    if (me == null) throw Exception('Could not get current user');

    final role = me.role.toLowerCase();
    final url = role == 'doctor'
        ? Uri.parse(
            '$baseUrl/patient/lab-reports',
          ) // doctor scope (assigned patients)
        : Uri.parse('$baseUrl/patient/lab-reports/me'); // patient scope

    _logGet(url, token);

    final res = await _client
        .get(url, headers: _headers(token))
        .timeout(timeout);

    _logResponse(res);
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body);
      return data.map((e) => MedicalRecord.fromJson(e)).toList();
    }

    // Try to surface backend "detail" if present
    try {
      final body = json.decode(res.body);
      final detail = body['detail']?.toString();
      throw Exception(
        detail ?? 'Failed to load lab reports: ${res.statusCode}',
      );
    } catch (_) {
      throw Exception('Failed to load lab reports: ${res.statusCode}');
    }
  }

  /// Fetch upcoming/scheduled appointments.
  /// Patients: `/appointments/patient/my-appointments?status=scheduled`
  /// Doctors : `/appointments/doctor/my-appointments?status=scheduled`
  static Future<List<MedicalRecord>> getUpcomingAppointments() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');

    final me = await AuthService.getCurrentUser();
    if (me == null) throw Exception('Could not get current user');

    final role = me.role?.toLowerCase() ?? '';
    final url = role == 'doctor'
        ? Uri.parse(
            '$baseUrl/appointments/doctor/my-appointments?status=scheduled',
          )
        : Uri.parse(
            '$baseUrl/appointments/patient/my-appointments?status=scheduled',
          );

    _logGet(url, token);

    final res = await _client
        .get(url, headers: _headers(token))
        .timeout(timeout);

    _logResponse(res);
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body);

      // Sort by appointment_datetime (safely)
      data.sort((x, y) {
        final da =
            DateTime.tryParse(x['appointment_datetime']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db =
            DateTime.tryParse(y['appointment_datetime']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return da.compareTo(db);
      });

      return data.map((e) => MedicalRecord.fromJson(e)).toList();
    }

    try {
      final body = json.decode(res.body);
      final detail = body['detail']?.toString();
      throw Exception(
        detail ?? 'Failed to load appointments: ${res.statusCode}',
      );
    } catch (_) {
      throw Exception('Failed to load appointments: ${res.statusCode}');
    }
  }

  /// Dispose the shared HTTP client when the app is shutting down.
  static void close() {
    _client.close();
  }

  // -----------------------
  // Helpers
  // -----------------------

  static Map<String, String> _headers(String token, {bool isJson = false}) {
    return {
      'Authorization': 'Bearer $token',
      if (isJson) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      // ngrok bypass header (if needed)
      'ngrok-skip-browser-warning': 'true',
    };
  }

  static void _logGet(Uri url, String token) {
    final preview = token.isNotEmpty
        ? token.substring(0, min(10, token.length))
        : '';
    // ignore: avoid_print
    print('🔍 GET $url\n🔑 token: $preview...');
  }

  static void _logPost(Uri url, String token, Map<String, dynamic> body) {
    final preview = token.isNotEmpty
        ? token.substring(0, min(10, token.length))
        : '';
    // ignore: avoid_print
    print('📝 POST $url\n🔑 token: $preview...\n📦 body: $body');
  }

  static void _logResponse(http.Response res) {
    // ignore: avoid_print
    print('📨 Response ${res.statusCode}: ${res.body}');
  }
}
