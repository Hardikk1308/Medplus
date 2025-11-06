import 'dart:async';
import 'dart:io';
import 'dart:math' show max, min;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:medplus/pages/history/history_screen.dart';
import 'package:medplus/services/auth_service.dart';
import 'package:medplus/services/blood_pressure_socket.dart';
import 'package:medplus/services/medical_record_service.dart';
import 'package:medplus/theme/app_colors.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  int _selectedIndex = 0;

  // WebSocket and subscriptions
  BloodPressureSocket? _bpSocket;
  StreamSubscription<bool>? _connSub;
  StreamSubscription<BloodPressureReading>? _readingsSub;
  StreamSubscription<Map<String, dynamic>>? _messageSub;

  // State
  bool _isInitializing = false;
  bool _isConnected = false;
    String? _errorMessage;

  // Data
  BloodPressureReading? _latestReading;
  final List<BloodPressureReading> _recentReadings = [];
  final List<String> _alerts = [];
  // Holds loaded medical records; kept as dynamic to match service return types

  // Graph
  final List<FlSpot> _systolicData = [];
  final List<FlSpot> _diastolicData = [];
  double _minY = 50;
  double _maxY = 200;

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  @override
  void dispose() {
    _cleanupSocket();
    super.dispose();
  }

  Future<void> _initSocket() async {
    if (!mounted || _isInitializing) return;

    _isInitializing = true;
    setState(() {
      _errorMessage = null;
    });

    try {
      final token = await _getTokenWithRetry();
      if (token == null || token.isEmpty) {
        _showErrorDialog('Authentication Error', 'Please log in again to continue');
        return;
      }

      // Clean any existing socket
      await _cleanupSocket();

      // Create socket
      _bpSocket = BloodPressureSocket(
        token: token,
        connectionTimeout: const Duration(seconds: 10),
        reconnectDelay: const Duration(seconds: 5),
        maxReconnectAttempts: 5,
      );

      // Subscriptions
      _connSub = _bpSocket!.connectionStatusStream.listen((connected) {
        if (!mounted) return;
        setState(() {
          _isConnected = connected;
          if (connected) _errorMessage = null;
        });
      });

      _readingsSub = _bpSocket!.readingsStream.listen((reading) {
        if (!mounted) return;
        setState(() {
          _latestReading = reading;
          _recentReadings.add(reading);
          if (_recentReadings.length > 100) _recentReadings.removeAt(0);
          _updateGraphData(reading);
          // Update min/max
          _minY = min(_minY, (reading.diastolic * 0.9).floorToDouble());
          _maxY = max(_maxY, (reading.systolic * 1.1).ceilToDouble());

          // Simple alert example
          if (reading.systolic >= 180 || reading.diastolic >= 120) {
            _alerts.add('CRITICAL: ${reading.systolic}/${reading.diastolic} mmHg at ${reading.timestamp}');
          }
        });
      }, onError: (e) {
        if (!mounted) return;
        setState(() => _errorMessage = e.toString());
      });

      _messageSub = _bpSocket!.messageStream.listen((message) {
        // Optional: handle other misc messages from server
      }, onError: (e) {
        if (!mounted) return;
        setState(() => _errorMessage = 'Connection error: $e');
      });

      await _bpSocket!.connect();
      await _loadMedicalRecords();
    } catch (e, st) {
      debugPrint('Error initializing socket: $e\n$st');
      if (!mounted) return;
      setState(() {
        _errorMessage = _formatConnectionError(e);
        _isConnected = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _cleanupSocket() async {
    await _connSub?.cancel();
    await _readingsSub?.cancel();
    await _messageSub?.cancel();
    _connSub = null;
    _readingsSub = null;
    _messageSub = null;

    try {
      await _bpSocket?.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting socket: $e');
    } finally {
      _bpSocket = null;
    }
  }

  Future<String?> _getTokenWithRetry({int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final token = await AuthService.getToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (e) {
        debugPrint('Get token failed (attempt ${attempts + 1}/$maxRetries): $e');
        if (attempts == maxRetries - 1) rethrow;
      }
      await Future.delayed(Duration(milliseconds: 500 * (attempts + 1)));
      attempts++;
    }
    return null;
    }

  void _updateGraphData(BloodPressureReading reading) {
    final double x = _systolicData.isNotEmpty ? _systolicData.last.x + 1.0 : 0.0;
    final double systolic = reading.systolic.toDouble();
    final double diastolic = reading.diastolic.toDouble();

    _systolicData.add(FlSpot(x, systolic));
    _diastolicData.add(FlSpot(x, diastolic));

    // Keep only last 50 points, reindex x for nicer bottom axis
    const keep = 50;
    if (_systolicData.length > keep) {
      _systolicData.removeAt(0);
      _diastolicData.removeAt(0);
      for (int i = 0; i < _systolicData.length; i++) {
        _systolicData[i] = FlSpot(i.toDouble(), _systolicData[i].y);
        _diastolicData[i] = FlSpot(i.toDouble(), _diastolicData[i].y);
      }
    }

    // Y-axis range with padding
    final allY = <double>[
      ..._systolicData.map((e) => e.y),
      ..._diastolicData.map((e) => e.y),
    ];
    if (allY.isNotEmpty) {
      final minY = allY.reduce(min);
      final maxY = allY.reduce(max);
      _minY = (minY * 0.9).floorToDouble().clamp(0, double.infinity);
      _maxY = (maxY * 1.1).ceilToDouble();
      if (_maxY <= _minY) _maxY = _minY + 20;
    }
  }

  String _formatConnectionError(Object e) {
    if (e is SocketException) {
      return 'Network error: ${e.message}. Check your internet connection.';
    }
    if (e is TimeoutException) {
      return 'Connection timeout. The server may be unavailable.';
    }
    if (e.toString().contains('PlatformException')) {
      return 'Failed to initialize local storage or security module.';
    }
    return 'Failed to connect: $e';
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HistoryScreen()),
      ).then((_) => _loadMedicalRecords());
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  Future<void> _loadMedicalRecords() async {
    if (!mounted) return;

    setState(() {
      _errorMessage = null;
      // _isLoading = true; // Add this if you have a loading state
    });

    try {
      final me = await AuthService.getCurrentUser();
      if (me == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      final role = me.role.toLowerCase();
      debugPrint('Loading medical records for role: $role');

      if (role == 'patient') {
        try {
          if (mounted) {
            setState(() {
              // Update your state with the fetched records
              _errorMessage = null;
            });
          }
        } catch (e) {
          debugPrint('Error fetching patient records: $e');
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to load your medical records. Please try again.';
            });
          }
        }
      } else if (role == 'doctor') {
        // For doctors, we don't load records until a patient is selected
        if (mounted) {
          setState(() {
            _errorMessage = 'Please select a patient to view their medical records';
// Clear any existing records
          });
        }
      } else {
        throw Exception('Unauthorized access: Invalid user role');
      }
    } catch (e, st) {
      debugPrint('Error in _loadMedicalRecords: $e\n$st');
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred while loading data. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
// Make sure to set loading to false when done
        });
      }
    }
}

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initSocket();
            },
            child: const Text('Retry Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodPressureChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(16.0),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) => Text('${value.toInt()}'),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) => Text('${value.toInt()}'),
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true),
            minX: 0,
            maxX: _systolicData.isNotEmpty ? _systolicData.length - 1 : 0,
            minY: _minY,
            maxY: _maxY,
            lineBarsData: [
              LineChartBarData(
                spots: _systolicData,
                isCurved: true,
                color: Colors.red,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
              LineChartBarData(
                spots: _diastolicData,
                isCurved: true,
                color: Colors.blue,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPressureStatus(int value, bool isSystolic) {
    if (isSystolic) {
      if (value < 90) return 'Low';
      if (value < 120) return 'Normal';
      if (value < 140) return 'High';
      return 'Dangerous';
    } else {
      if (value < 60) return 'Low';
      if (value < 80) return 'Normal';
      if (value < 90) return 'High';
      return 'Dangerous';
    }
  }

  String _getPulseStatus(int? value) {
    if (value == null) return '';
    if (value < 60) return 'Low';
    if (value <= 100) return 'Normal';
    return 'High';
  }

  Widget _buildDivider() => Container(width: 1, height: 40, color: Colors.grey[300]);

  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green.shade50 : Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isConnected ? Icons.wifi : Icons.wifi_off,
                      color: _isConnected ? Colors.green : Colors.red,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConnected ? 'Connected' : (_isInitializing ? 'Connecting...' : 'Disconnected'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: _isConnected ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _latestReading != null
                              ? 'Last update: ${_latestReading!.timestamp.toLocal().toString().substring(0, 19)}'
                              : _isConnected
                                  ? 'Waiting for data...'
                                  : 'Not connected',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isConnected && !_isInitializing)
                    TextButton.icon(
                      onPressed: _initSocket,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    )
                  else if (_isInitializing)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Current reading
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.red, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'BLOOD PRESSURE',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.grey[600],
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _latestReading != null
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildReadingColumn(
                              'Systolic',
                              _latestReading!.systolic.toString(),
                              'mmHg',
                              _getPressureStatus(_latestReading!.systolic, true),
                            ),
                            _buildDivider(),
                            _buildReadingColumn(
                              'Diastolic',
                              _latestReading!.diastolic.toString(),
                              'mmHg',
                              _getPressureStatus(_latestReading!.diastolic, false),
                            ),
                            _buildDivider(),
                            _buildReadingColumn(
                              'Pulse',
                              _latestReading!.pulse?.toString() ?? '--',
                              'bpm',
                              _getPulseStatus(_latestReading!.pulse),
                            ),
                          ],
                        )
                      : const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.timelapse, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Waiting for data...', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text('Blood Pressure Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _systolicData.isNotEmpty ? _buildBloodPressureChart() : const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('Waiting for data...')),
              ),
            ),
          ),

          if (_alerts.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'ALERTS',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.grey[600],
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ..._alerts.map((alert) => Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: alert.contains('CRITICAL') ? Colors.red.shade200 : Colors.orange.shade200,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: alert.contains('CRITICAL') ? Colors.red.shade50 : Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        alert.contains('CRITICAL') ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                        color: alert.contains('CRITICAL') ? Colors.red : Colors.orange,
                      ),
                    ),
                    title: Text(alert, style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                    onTap: () {},
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildReadingColumn(String label, String value, String unit, String status) {
    Color statusColor = Colors.grey;
    if (status == 'High' || status == 'Low') {
      statusColor = Colors.orange;
    } else if (status == 'Dangerous') {
      statusColor = Colors.red;
    } else if (status == 'Normal') {
      statusColor = Colors.green;
    }

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(unit, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            if (status.isNotEmpty) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MedPlus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isInitializing
                ? null
                : () async {
                    await _initSocket();
                    await _loadMedicalRecords();
                  },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([_initSocket(), _loadMedicalRecords()]),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHomeScreen(),
              if (_errorMessage != null && !_isConnected)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Connection Status: $_errorMessage', style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: AppColors.primary),
                  ),
                  SizedBox(height: 10),
                  Text('Welcome', style: TextStyle(color: Colors.white, fontSize: 16)),
                  Text('User', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: AppColors.primary),
              title: const Text('Appointments'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.medication, color: AppColors.primary),
              title: const Text('Prescriptions'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to prescriptions screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment, color: AppColors.primary),
              title: const Text('Lab Reports'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to lab reports screen
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings, color: AppColors.primary),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await AuthService.logout();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
