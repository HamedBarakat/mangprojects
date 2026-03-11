import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/office_settings_model.dart';

class OfficeSettingsRepository {
  final _db = FirebaseFirestore.instance;

  DocumentReference _settingsDoc(String officeId) => _db
      .collection('offices')
      .doc(officeId)
      .collection('settings')
      .doc('main');

  // ── Watch settings (real-time) ─────────────────────────────────────────────
  Stream<OfficeSettingsModel> watchSettings(String officeId) {
    return _settingsDoc(officeId).snapshots().map((doc) {
      if (!doc.exists) return OfficeSettingsModel.defaults(officeId);
      return OfficeSettingsModel.fromFirestore(doc);
    });
  }

  // ── Get settings (one-time) ────────────────────────────────────────────────
  Future<OfficeSettingsModel> getSettings(String officeId) async {
    final doc = await _settingsDoc(officeId).get();
    if (!doc.exists) return OfficeSettingsModel.defaults(officeId);
    return OfficeSettingsModel.fromFirestore(doc);
  }

  // ── Initialize settings (first time) ──────────────────────────────────────
  Future<void> initializeSettings(String officeId) async {
    final doc = await _settingsDoc(officeId).get();
    if (!doc.exists) {
      await _settingsDoc(officeId)
          .set(OfficeSettingsModel.defaults(officeId).toFirestore());
    }
  }

  // ── Update a single list ───────────────────────────────────────────────────
  Future<void> updateList({
    required String officeId,
    required String field, // 'projectTypes' | 'disciplines' | 'taskCategories' | 'departments'
    required List<String> items,
  }) async {
    await _settingsDoc(officeId)
        .set({field: items, 'officeId': officeId}, SetOptions(merge: true));
  }

  // ── Add item to a list ─────────────────────────────────────────────────────
  Future<void> addItem({
    required String officeId,
    required String field,
    required String item,
  }) async {
    await _settingsDoc(officeId).set({
      field: FieldValue.arrayUnion([item.trim()]),
      'officeId': officeId,
    }, SetOptions(merge: true));
  }

  // ── Remove item from a list ────────────────────────────────────────────────
  Future<void> removeItem({
    required String officeId,
    required String field,
    required String item,
  }) async {
    await _settingsDoc(officeId).set({
      field: FieldValue.arrayRemove([item]),
      'officeId': officeId,
    }, SetOptions(merge: true));
  }

  // ── Rename item in a list ──────────────────────────────────────────────────
  Future<void> renameItem({
    required String officeId,
    required String field,
    required String oldItem,
    required String newItem,
    required List<String> currentList,
  }) async {
    final updated =
        currentList.map((e) => e == oldItem ? newItem.trim() : e).toList();
    await updateList(officeId: officeId, field: field, items: updated);
  }

  // ── Save Job Title Groups ──────────────────────────────────────────────────
  Future<void> saveJobTitleGroups({
    required String officeId,
    required List<JobTitleGroupData> groups,
  }) async {
    final data = groups
        .map((g) => {'title': g.title, 'titles': g.titles})
        .toList();
    await _settingsDoc(officeId).set(
      {'jobTitleGroups': data, 'officeId': officeId},
      SetOptions(merge: true),
    );
  }
}
