import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectModel {
  final String id;
  final String officeId;
  final String projectCode;
  final String name;
  final String type; // design / executive_drawings / supervision
  final String status; // active / completed / suspended / cancelled
  final String clientId;
  final String clientName;
  final String location;
  final List<String> disciplines;
  final DateTime startDate;
  final DateTime endDate;
  final double completionPercentage;
  final String createdBy;
  final DateTime createdAt;
  final String notes;

  const ProjectModel({
    required this.id,
    required this.officeId,
    required this.projectCode,
    required this.name,
    required this.type,
    required this.status,
    required this.clientId,
    required this.clientName,
    required this.location,
    required this.disciplines,
    required this.startDate,
    required this.endDate,
    required this.completionPercentage,
    required this.createdBy,
    required this.createdAt,
    required this.notes,
  });

  String get typeLabel {
    switch (type) {
      case 'design':
        return 'Design';
      case 'executive_drawings':
        return 'Executive Drawings';
      case 'supervision':
        return 'Supervision';
      default:
        return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'suspended':
        return 'Suspended';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  factory ProjectModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProjectModel(
      id: doc.id,
      officeId: d['officeId'] ?? '',
      projectCode: d['projectCode'] ?? '',
      name: d['name'] ?? '',
      type: d['type'] ?? 'design',
      status: d['status'] ?? 'active',
      clientId: d['clientId'] ?? '',
      clientName: d['clientName'] ?? '',
      location: d['location'] ?? '',
      disciplines: List<String>.from(d['disciplines'] ?? []),
      startDate: (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (d['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completionPercentage: (d['completionPercentage'] ?? 0).toDouble(),
      createdBy: d['createdBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: d['notes'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'officeId': officeId,
      'projectCode': projectCode,
      'name': name,
      'type': type,
      'status': status,
      'clientId': clientId,
      'clientName': clientName,
      'location': location,
      'disciplines': disciplines,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'completionPercentage': completionPercentage,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
    };
  }
}
