class HRPolicyModel {
  static const kAllDays = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  static const kDayLabels = {
    'sun': 'Sun', 'mon': 'Mon', 'tue': 'Tue',
    'wed': 'Wed', 'thu': 'Thu', 'fri': 'Fri', 'sat': 'Sat',
  };
  static const kDefaultWorkDays = ['sun', 'mon', 'tue', 'wed', 'thu'];
  static const kDefaultStart = '08:00';
  static const kDefaultEnd = '16:30';

  final List<String> workDays;
  final String workStartTime;
  final String workEndTime;
  final double lateGraceHoursPerMonth;
  final double permissionHoursPerMonth;
  final int annualLeaveDays;

  const HRPolicyModel({
    required this.workDays,
    required this.workStartTime,
    required this.workEndTime,
    required this.lateGraceHoursPerMonth,
    required this.permissionHoursPerMonth,
    required this.annualLeaveDays,
  });

  factory HRPolicyModel.defaults() => const HRPolicyModel(
        workDays: kDefaultWorkDays,
        workStartTime: kDefaultStart,
        workEndTime: kDefaultEnd,
        lateGraceHoursPerMonth: 5.0,
        permissionHoursPerMonth: 5.0,
        annualLeaveDays: 21,
      );

  factory HRPolicyModel.fromMap(Map<String, dynamic> d) => HRPolicyModel(
        workDays: List<String>.from(d['workDays'] ?? kDefaultWorkDays),
        workStartTime: d['workStartTime'] as String? ?? kDefaultStart,
        workEndTime: d['workEndTime'] as String? ?? kDefaultEnd,
        lateGraceHoursPerMonth:
            ((d['lateGraceHoursPerMonth'] ?? 5.0) as num).toDouble(),
        permissionHoursPerMonth:
            ((d['permissionHoursPerMonth'] ?? 5.0) as num).toDouble(),
        annualLeaveDays: (d['annualLeaveDays'] as num?)?.toInt() ?? 21,
      );

  Map<String, dynamic> toMap() => {
        'workDays': workDays,
        'workStartTime': workStartTime,
        'workEndTime': workEndTime,
        'lateGraceHoursPerMonth': lateGraceHoursPerMonth,
        'permissionHoursPerMonth': permissionHoursPerMonth,
        'annualLeaveDays': annualLeaveDays,
      };

  // ── Helpers ───────────────────────────────────────────────────────────────
  int get startHour => int.tryParse(workStartTime.split(':')[0]) ?? 8;
  int get startMinute => int.tryParse(workStartTime.split(':')[1]) ?? 0;
  int get endHour => int.tryParse(workEndTime.split(':')[0]) ?? 16;
  int get endMinute => int.tryParse(workEndTime.split(':')[1]) ?? 30;

  bool isLate(DateTime time) =>
      time.hour > startHour ||
      (time.hour == startHour && time.minute > startMinute);

  /// "Sun-Thu" for consecutive days, "Sun, Tue, Thu" otherwise
  String get workDaysLabel {
    if (workDays.isEmpty) return '—';
    // Try to detect consecutive range in kAllDays order
    final orderedSelected = kAllDays.where((d) => workDays.contains(d)).toList();
    if (orderedSelected.length >= 2) {
      bool consecutive = true;
      for (int i = 0; i < orderedSelected.length - 1; i++) {
        final a = kAllDays.indexOf(orderedSelected[i]);
        final b = kAllDays.indexOf(orderedSelected[i + 1]);
        if (b - a != 1) { consecutive = false; break; }
      }
      if (consecutive) {
        return '${kDayLabels[orderedSelected.first]}-${kDayLabels[orderedSelected.last]}';
      }
    }
    return orderedSelected.map((d) => kDayLabels[d] ?? d).join(', ');
  }
}
