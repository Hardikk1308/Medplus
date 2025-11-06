import 'dart:async';
import 'dart:io';
import 'dart:math' show max, min;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medplus/services/notification_service.dart';
import 'package:medplus/pages/history/history_screen.dart';
import 'package:medplus/services/auth_service.dart';
import 'package:medplus/services/blood_pressure_socket.dart';
import 'package:medplus/theme/app_colors.dart';
import 'package:medplus/widgets/chat_widget.dart';
import 'package:medplus/pages/logs/symptoms_logs_screen.dart';

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
  DateTime? _lastCriticalAlertAt;
  static const Duration _criticalAlertCooldown = Duration(seconds: 10);

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
        _showErrorDialog(
          'Authentication Error',
          'Please log in again to continue',
        );
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

      _readingsSub = _bpSocket!.readingsStream.listen(
        (reading) {
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
              _alerts.add(
                'CRITICAL: ${reading.systolic}/${reading.diastolic} mmHg at ${reading.timestamp}',
              );
              _triggerCriticalAlert(reading);
            }
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() => _errorMessage = e.toString());
        },
      );

      _messageSub = _bpSocket!.messageStream.listen(
        (message) {
          // Optional: handle other misc messages from server
        },
        onError: (e) {
          if (!mounted) return;
          setState(() => _errorMessage = 'Connection error: $e');
        },
      );

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

  void _triggerCriticalAlert(BloodPressureReading reading) {
    final now = DateTime.now();
    if (_lastCriticalAlertAt != null &&
        now.difference(_lastCriticalAlertAt!) < _criticalAlertCooldown) {
      return;
    }
    _lastCriticalAlertAt = now;

    // Play system alert sound and strong haptic feedback (best-effort cross-platform)
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    // Show an in-app high-visibility dialog
    if (!mounted) return;
    // Fire a system notification as well
    NotificationService.instance.showCriticalNotification(
      title: 'Critical BP Alert',
      body: 'Reading: ${reading.systolic}/${reading.diastolic} mmHg',
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Critical Blood Pressure Alert',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Reading: ${reading.systolic}/${reading.diastolic} mmHg' +
                (reading.pulse != null ? '\nPulse: ${reading.pulse} bpm' : ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
        debugPrint(
          'Get token failed (attempt ${attempts + 1}/$maxRetries): $e',
        );
        if (attempts == maxRetries - 1) rethrow;
      }
      await Future.delayed(Duration(milliseconds: 500 * (attempts + 1)));
      attempts++;
    }
    return null;
  }

  void _updateGraphData(BloodPressureReading reading) {
    final double x = _systolicData.isNotEmpty
        ? _systolicData.last.x + 1.0
        : 0.0;
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
    if (index == 2) {
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
              _errorMessage =
                  'Failed to load your medical records. Please try again.';
            });
          }
        }
      } else if (role == 'doctor') {
        // For doctors, we don't load records until a patient is selected
        if (mounted) {
          setState(() {
            _errorMessage =
                'Please select a patient to view their medical records';
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
          _errorMessage =
              'An error occurred while loading data. Please try again.';
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
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 320,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildLegendDot(Colors.red, 'Systolic'),
                const SizedBox(width: 12),
                _buildLegendDot(Colors.blue, 'Diastolic'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.black.withOpacity(0.7),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.12),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 20,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  minX: 0,
                  maxX: _systolicData.isNotEmpty ? _systolicData.length - 1 : 0,
                  minY: _minY,
                  maxY: _maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _systolicData,
                      isCurved: true,
                      gradient: const LinearGradient(
                        colors: [Colors.redAccent, Colors.red],
                      ),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.withOpacity(0.25),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    LineChartBarData(
                      spots: _diastolicData,
                      isCurved: true,
                      gradient: const LinearGradient(
                        colors: [Colors.lightBlueAccent, Colors.blue],
                      ),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withOpacity(0.20),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
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

  Widget _buildDivider() =>
      Container(width: 1, height: 40, color: Colors.grey[300]);

  Widget _buildHomeScreen() {
    return Padding(
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
                color: _isConnected
                    ? Colors.green.shade100
                    : Colors.red.shade100,
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
                      color: _isConnected
                          ? Colors.green.shade50
                          : Colors.red.shade50,
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
                          _isConnected
                              ? 'Connected'
                              : (_isInitializing
                                    ? 'Connecting...'
                                    : 'Disconnected'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                              _getPressureStatus(
                                _latestReading!.systolic,
                                true,
                              ),
                            ),
                            _buildDivider(),
                            _buildReadingColumn(
                              'Diastolic',
                              _latestReading!.diastolic.toString(),
                              'mmHg',
                              _getPressureStatus(
                                _latestReading!.diastolic,
                                false,
                              ),
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
                                Icon(
                                  Icons.timelapse,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Waiting for data...',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Blood Pressure Trend',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _systolicData.isNotEmpty
              ? _buildBloodPressureChart()
              : Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const SizedBox(
                    height: 120,
                    child: Center(child: Text('Waiting for data...')),
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
            ..._alerts.map(
              (alert) => Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: alert.contains('CRITICAL')
                        ? Colors.red.shade200
                        : Colors.orange.shade200,
                    width: 1,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: alert.contains('CRITICAL')
                          ? Colors.red.shade50
                          : Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      alert.contains('CRITICAL')
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline_rounded,
                      color: alert.contains('CRITICAL')
                          ? Colors.red
                          : Colors.orange,
                    ),
                  ),
                  title: Text(
                    alert,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () {},
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadingColumn(
    String label,
    String value,
    String unit,
    String status,
  ) {
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
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // Add the chat widget that will float above all other content
  Widget _buildChatWidget() {
    return const ChatWidget();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 113, 158, 255),
        title: const Text('Sahara', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isInitializing
                ? null
                : () async {
                    await _initSocket();
                    await _loadMedicalRecords();
                  },
          ),
        ],
      ),
      body: _selectedIndex == 1
          ? const SymptomsLogsScreen()
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () =>
                      Future.wait([_initSocket(), _loadMedicalRecords()]),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildHomeScreen(),
                        if (_errorMessage != null && !_isConnected)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Connection Status: $_errorMessage',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Floating chat widget overlay
                _buildChatWidget(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            activeIcon: Icon(Icons.description),
            label: 'Symptoms Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
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
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Welcome',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    'User',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.calendar_today,
                color: AppColors.primary,
              ),
              title: const Text('Appointments'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryScreen(),
                  ),
                );
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
