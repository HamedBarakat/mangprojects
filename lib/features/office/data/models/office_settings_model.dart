import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../home/data/models/user_model.dart';

class OfficeSettingsModel {
  final String id;
  final String officeId;

  final List<String> projectTypes;
  final List<String> disciplines;
  final List<String> taskCategories;
  final List<String> departments;
  final Map<String, String> roleLabels;

  // ── Job Title Groups (customizable per office) ─────────────────────────────
  // List of groups, each group has a title + map of key→label
  // If empty → fall back to JobTitles.groups defaults
  final List<JobTitleGroupData> jobTitleGroups;

  const OfficeSettingsModel({
    required this.id,
    required this.officeId,
    required this.projectTypes,
    required this.disciplines,
    required this.taskCategories,
    required this.departments,
    required this.roleLabels,
    required this.jobTitleGroups,
  });

  // ── Effective job title groups (office custom OR defaults) ─────────────────
  List<JobTitleGroup> get effectiveJobTitleGroups {
    if (jobTitleGroups.isEmpty) return JobTitles.groups;
    return jobTitleGroups
        .map((g) => JobTitleGroup(title: g.title, titles: g.titles))
        .toList();
  }

  // ── Flat map of all effective job titles ───────────────────────────────────
  Map<String, String> get effectiveJobTitles {
    final groups = effectiveJobTitleGroups;
    final map = <String, String>{};
    for (final g in groups) {
      map.addAll(g.titles);
    }
    return map;
  }

  // ── Defaults ───────────────────────────────────────────────────────────────
  factory OfficeSettingsModel.defaults(String officeId) {
    return OfficeSettingsModel(
      id: 'settings',
      officeId: officeId,
      projectTypes: [
        'Design',
        'Shop Drawings',
        'Supervision',
        'Construction Management',
      ],
      disciplines: [
        'Electrical',
        'Mechanical',
        'Plumbing',
        'Low Current',
        'Structural',
        'Architecture',
      ],
      taskCategories: [
        'Design',
        'Execution',
        'Review',
        'Site Visit',
        'Coordination',
      ],
      departments: [
        'Management',
        'Electrical',
        'Mechanical',
        'Architecture',
        'Structural',
      ],
      roleLabels: {
        'admin':          'Admin',
        'team_leader':    'Team Leader',
        'reviewer':       'Reviewer',
        'engineer':       'Engineer',
        'management':     'Management',
        'administration': 'Administration',
        'client':         'Client',
      },
      jobTitleGroups: [], // empty = use JobTitles.groups defaults
    );
  }

  // ── Firestore ──────────────────────────────────────────────────────────────
  factory OfficeSettingsModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    // Parse jobTitleGroups
    final rawGroups = d['jobTitleGroups'] as List<dynamic>? ?? [];
    final groups = rawGroups.map((g) {
      final map = g as Map<String, dynamic>;
      return JobTitleGroupData(
        title: map['title'] as String? ?? '',
        titles: Map<String, String>.from(map['titles'] as Map? ?? {}),
      );
    }).toList();

    return OfficeSettingsModel(
      id: doc.id,
      officeId: d['officeId'] ?? '',
      projectTypes:   List<String>.from(d['projectTypes'] ?? []),
      disciplines:    List<String>.from(d['disciplines'] ?? []),
      taskCategories: List<String>.from(d['taskCategories'] ?? []),
      departments:    List<String>.from(d['departments'] ?? []),
      roleLabels:     Map<String, String>.from(d['roleLabels'] ?? {}),
      jobTitleGroups: groups,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'officeId':      officeId,
      'projectTypes':  projectTypes,
      'disciplines':   disciplines,
      'taskCategories': taskCategories,
      'departments':   departments,
      'roleLabels':    roleLabels,
      'jobTitleGroups': jobTitleGroups
          .map((g) => {'title': g.title, 'titles': g.titles})
          .toList(),
    };
  }

  OfficeSettingsModel copyWith({
    List<String>? projectTypes,
    List<String>? disciplines,
    List<String>? taskCategories,
    List<String>? departments,
    Map<String, String>? roleLabels,
    List<JobTitleGroupData>? jobTitleGroups,
  }) {
    return OfficeSettingsModel(
      id: id,
      officeId: officeId,
      projectTypes:   projectTypes   ?? this.projectTypes,
      disciplines:    disciplines    ?? this.disciplines,
      taskCategories: taskCategories ?? this.taskCategories,
      departments:    departments    ?? this.departments,
      roleLabels:     roleLabels     ?? this.roleLabels,
      jobTitleGroups: jobTitleGroups ?? this.jobTitleGroups,
    );
  }
}

// ── JobTitleGroupData — plain data class for Firestore ────────────────────────
class JobTitleGroupData {
  final String title;
  final Map<String, String> titles; // key → label

  const JobTitleGroupData({required this.title, required this.titles});
}
