import 'package:cloud_firestore/cloud_firestore.dart';

class OfficeModel {
  final String id;
  final String name;
  final String code;
  final String logo;
  final bool isActive;
  final DateTime? createdAt;
  final String workStartTime; // "HH:mm" e.g. "09:00"
  final String workEndTime;   // "HH:mm" e.g. "17:00"

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

  // ── Parsed helpers ─────────────────────────────────────────────────────────

  /// يرجع الـ start time كـ TimeOfDay parts
  int get startHour => int.tryParse(workStartTime.split(':')[0]) ?? 9;
  int get startMinute => int.tryParse(workStartTime.split(':')[1]) ?? 0;

  /// يرجع الـ end time كـ TimeOfDay parts
  int get endHour => int.tryParse(workEndTime.split(':')[0]) ?? 17;
  int get endMinute => int.tryParse(workEndTime.split(':')[1]) ?? 0;

  /// عدد ساعات العمل الرسمية
  double get workHours {
    final start = startHour + startMinute / 60;
    final end = endHour + endMinute / 60;
    return end - start;
  }

  /// هل الوقت الحالي بعد وقت البداية؟ → late
  bool isLate(DateTime time) {
    if (time.hour > startHour) return true;
    if (time.hour == startHour && time.minute > startMinute) return true;
    return false;
  }

  /// هل الوقت الحالي بعد وقت النهاية؟ → overtime territory
  bool isOvertime(DateTime time) {
    if (time.hour > endHour) return true;
    if (time.hour == endHour && time.minute > endMinute) return true;
    return false;
  }

  // ── Firestore ──────────────────────────────────────────────────────────────

  factory OfficeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return OfficeModel(
      id: doc.id,
      name: d['name'] ?? '',
      code: d['code'] ?? '',
      logo: d['logo'] ?? '',
      isActive: d['isActive'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      workStartTime: d['workStartTime'] ?? '09:00',
      workEndTime: d['workEndTime'] ?? '17:00',
    );
  }

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
