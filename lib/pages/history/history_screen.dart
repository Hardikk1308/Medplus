import 'package:flutter/material.dart';
import 'package:medplus/models/medical_record.dart';
import 'package:medplus/services/history_service.dart';
import 'package:medplus/theme/app_colors.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  
  // History data
  List<MedicalRecord> _appointments = [];
  List<MedicalRecord> _prescriptions = [];
  List<MedicalRecord> _labReports = [];
  List<Map<String, dynamic>> _bloodPressureReadings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        HistoryService.getAppointmentHistory(),
        HistoryService.getPrescriptionHistory(),
        HistoryService.getLabReportHistory(),
        HistoryService.getBloodPressureHistory(),
      ]);

      if (!mounted) return;

      setState(() {
        _appointments = results[0] as List<MedicalRecord>;
        _prescriptions = results[1] as List<MedicalRecord>;
        _labReports = results[2] as List<MedicalRecord>;
        _bloodPressureReadings = results[3] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load history: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical History'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Appointments'),
            Tab(text: 'Prescriptions'),
            Tab(text: 'Lab Reports'),
            Tab(text: 'Blood Pressure'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAppointmentsTab(),
                      _buildPrescriptionsTab(),
                      _buildLabReportsTab(),
                      _buildBloodPressureTab(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAppointmentsTab() {
    if (_appointments.isEmpty) {
      return const Center(child: Text('No appointment history available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appointment = _appointments[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: const Icon(Icons.calendar_today, color: AppColors.primary),
            title: Text(appointment.data['title'] ?? 'Appointment'),
            subtitle: Text(
              '${_formatDate(appointment.date)} • ${appointment.doctorName ?? 'Doctor'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to appointment details
            },
          ),
        );
      },
    );
  }

  Widget _buildPrescriptionsTab() {
    if (_prescriptions.isEmpty) {
      return const Center(child: Text('No prescription history available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _prescriptions.length,
      itemBuilder: (context, index) {
        final prescription = _prescriptions[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: const Icon(Icons.medication, color: AppColors.primary),
            title: Text(prescription.data['medication'] ?? 'Prescription'),
            subtitle: Text(
              'Prescribed on ${_formatDate(prescription.date)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to prescription details
            },
          ),
        );
      },
    );
  }

  Widget _buildLabReportsTab() {
    if (_labReports.isEmpty) {
      return const Center(child: Text('No lab report history available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _labReports.length,
      itemBuilder: (context, index) {
        final report = _labReports[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: const Icon(Icons.medical_services, color: AppColors.primary),
            title: Text(report.data['testName'] ?? 'Lab Test'),
            subtitle: Text(
              'Tested on ${_formatDate(report.date)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to lab report details
            },
          ),
        );
      },
    );
  }

  Widget _buildBloodPressureTab() {
    if (_bloodPressureReadings.isEmpty) {
      return const Center(child: Text('No blood pressure data available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _bloodPressureReadings.length,
      itemBuilder: (context, index) {
        final reading = _bloodPressureReadings[index];
        final date = DateTime.parse(reading['timestamp']);
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: const Icon(Icons.favorite, color: Colors.red),
            title: Text(
              '${reading['systolic']}/${reading['diastolic']} mmHg',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pulse: ${reading['pulse']} bpm'),
                Text(_formatDateTime(date)),
              ],
            ),
            trailing: _getStatusIcon(reading['systolic'], reading['diastolic']),
          ),
        );
      },
    );
  }

  Widget _getStatusIcon(int systolic, int diastolic) {
    if (systolic > 140 || diastolic > 90) {
      return const Icon(Icons.warning_amber_rounded, color: Colors.orange);
    } else if (systolic < 90 || diastolic < 60) {
      return const Icon(Icons.arrow_downward, color: Colors.blue);
    }
    return const Icon(Icons.check_circle, color: Colors.green);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('MMM d, yyyy • hh:mm a').format(date);
  }
}
