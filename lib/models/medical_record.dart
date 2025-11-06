class MedicalRecord {
  final String id;
  final String patientId;
  final DateTime date;
  final String type; // 'prescription', 'appointment', 'lab_report'
  final Map<String, dynamic> data;
  final String? doctorName;
  final String? status;

  MedicalRecord({
    required this.id,
    required this.patientId,
    required this.date,
    required this.type,
    required this.data,
    this.doctorName,
    this.status,
  });

  factory MedicalRecord.fromJson(Map<String, dynamic> json) {
    return MedicalRecord(
      id: json['id'] ?? '',
      patientId: json['patientId'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      type: json['type'] ?? '',
      data: json['data'] ?? {},
      doctorName: json['doctorName'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'date': date.toIso8601String(),
        'type': type,
        'data': data,
        'doctorName': doctorName,
        'status': status,
      };
}
