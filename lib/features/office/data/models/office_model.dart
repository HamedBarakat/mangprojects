import 'package:cloud_firestore/cloud_firestore.dart';

class OfficeModel {
  final String id;
  final String name;
  final String code;
  final String logo;
  final bool isActive;
  final DateTime? createdAt;
  final String workStartTime; // "HH:mm"
  final String workEndTime; // "HH:mm"

  const OfficeModel({
    required this.id,
    required this.name,
    required this.code,
    this.logo = '',
    this.isActive = true,
    this.createdAt,
    this.workStartTime = '09:00',
    this.workEndTime = '17:00',
  });

  // ─────────────────────────────────────────────────────────────
  // Time helpers
  // ─────────────────────────────────────────────────────────────

  int get startHour => int.tryParse(workStartTime.split(':')[0]) ?? 9;
  int get startMinute => int.tryParse(workStartTime.split(':')[1]) ?? 0;

  int get endHour => int.tryParse(workEndTime.split(':')[0]) ?? 17;
  int get endMinute => int.tryParse(workEndTime.split(':')[1]) ?? 0;

  /// official working hours
  double get workHours {
    final start = startHour + startMinute / 60;
    final end = endHour + endMinute / 60;
    return end - start;
  }

  /// is employee late?
  bool isLate(DateTime time) {
    if (time.hour > startHour) return true;
    if (time.hour == startHour && time.minute > startMinute) return true;
    return false;
  }

  /// overtime check
  bool isOvertime(DateTime time) {
    if (time.hour > endHour) return true;
    if (time.hour == endHour && time.minute > endMinute) return true;
    return false;
  }

  // ─────────────────────────────────────────────────────────────
  // Firestore factories
  // ─────────────────────────────────────────────────────────────

  factory OfficeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return OfficeModel(
      id: doc.id,
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      logo: data['logo'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      workStartTime: data['workStartTime'] ?? '09:00',
      workEndTime: data['workEndTime'] ?? '17:00',
    );
  }

  /// used when reading query results
  factory OfficeModel.fromMap(Map<String, dynamic> map, String id) {
    return OfficeModel(
      id: id,
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      logo: map['logo'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      workStartTime: map['workStartTime'] ?? '09:00',
      workEndTime: map['workEndTime'] ?? '17:00',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Firestore write
  // ─────────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'code': code,
      'logo': logo,
      'isActive': isActive,
      'workStartTime': workStartTime,
      'workEndTime': workEndTime,
    };
  }

  // ─────────────────────────────────────────────────────────────
  // copyWith
  // ─────────────────────────────────────────────────────────────

  OfficeModel copyWith({
    String? name,
    String? logo,
    bool? isActive,
    String? workStartTime,
    String? workEndTime,
  }) {
    return OfficeModel(
      id: id,
      name: name ?? this.name,
      code: code,
      logo: logo ?? this.logo,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
    );
  }
}
