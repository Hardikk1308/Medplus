import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medplus/services/auth_service.dart';
import 'package:medplus/models/auth_models.dart';
import 'package:medplus/services/logs_service.dart';

class SymptomsLogsScreen extends StatefulWidget {
  const SymptomsLogsScreen({Key? key}) : super(key: key);

  @override
  State<SymptomsLogsScreen> createState() => _SymptomsLogsScreenState();
}

class _SymptomsLogsScreenState extends State<SymptomsLogsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<List<dynamic>>? _medicineFuture;
  Future<List<dynamic>>? _symptomsFuture;
  Future<User?>? _userFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _medicineFuture = LogsService.getMyMedicineLogs();
    _symptomsFuture = LogsService.getMySymptoms();
    _userFuture = AuthService.getCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 3),
              insets: const EdgeInsets.symmetric(horizontal: 24),
            ),
            tabs: const [
              Tab(icon: Icon(Icons.medication), text: 'Medicines'),
              Tab(icon: Icon(Icons.sick), text: 'Symptoms'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMedicineTab(),
              _buildSymptomsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return FutureBuilder<User?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        final user = snapshot.data;
        if (user == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Icon(Icons.person, color: Theme.of(context).primaryColor),
              ),
              title: Text(user.fullName.isNotEmpty ? user.fullName : user.username,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${user.email} • ${user.role.toUpperCase()}'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedicineTab() {
    return FutureBuilder<List<dynamic>>(
      future: _medicineFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildError('Failed to load medicines', onRetry: _reloadMedicines);
        }
        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return _buildEmpty('No medicine logs yet');
        }
        return RefreshIndicator(
          onRefresh: _reloadAll,
          child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final item = data[index] as Map<String, dynamic>;
            final createdAtRaw = (item['created_at'] ?? item['updated_at'] ?? '').toString();
            final createdAt = _formatDate(createdAtRaw);
            final meds = (item['medicine_data']?['medicines'] as List?) ?? [];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                title: Text('Medicine Log ${index + 1}'),
                subtitle: Text(createdAt),
                children: meds.map((m) {
                  final mm = m as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.medication_outlined),
                    title: Text((mm['name'] ?? '').toString()),
                    subtitle: Text('Dose: ${(mm['dose'] ?? '').toString()}'),
                    trailing: Text(_formatDate((mm['taken_at'] ?? '').toString())),
                  );
                }).toList(),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: data.length,
        ));
      },
    );
  }

  Widget _buildSymptomsTab() {
    return FutureBuilder<List<dynamic>>(
      future: _symptomsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildError('Failed to load symptoms', onRetry: _reloadSymptoms);
        }
        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return _buildEmpty('No symptoms logged yet');
        }
        return RefreshIndicator(
          onRefresh: _reloadAll,
          child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final item = data[index] as Map<String, dynamic>;
            final createdAt = _formatDate((item['created_at'] ?? '').toString());
            final symptoms = (item['symptoms'] as List?) ?? (item['symptom_data']?['symptoms'] as List? ?? []);
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.sick_outlined),
                title: Text('Entry ${index + 1}'),
                subtitle: Text(createdAt),
                trailing: Text('${symptoms.length} items'),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Symptoms', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...symptoms.map((s) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.circle, size: 8),
                                title: Text(s.toString()),
                              )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: data.length,
        ));
      },
    );
  }

  Future<void> _reloadMedicines() async {
    setState(() {
      _medicineFuture = LogsService.getMyMedicineLogs();
    });
  }

  Future<void> _reloadSymptoms() async {
    setState(() {
      _symptomsFuture = LogsService.getMySymptoms();
    });
  }

  Future<void> _reloadAll() async {
    _reloadMedicines();
    _reloadSymptoms();
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return raw.replaceAll('T', ' ').replaceAll('Z', '');
    }
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildError(String message, {required Future<void> Function() onRetry}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          )
        ],
      ),
    );
  }
}
