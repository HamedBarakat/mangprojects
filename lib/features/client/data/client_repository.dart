import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/client_model.dart';

class ClientRepository {
  final _db = FirebaseFirestore.instance;
  final String officeId;

  ClientRepository({required this.officeId});

  CollectionReference get _col => _db.collection('clients');

  // ── Watch all clients for office ──────────────────────────────────────────
  Stream<List<ClientModel>> watchClients() {
    return _col
        .where('officeId', isEqualTo: officeId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ClientModel.fromFirestore(d)).toList());
  }

  // ── Add client ────────────────────────────────────────────────────────────
  Future<void> addClient(Map<String, dynamic> data) async {
    await _col.add({
      ...data,
      'officeId': officeId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Update client ─────────────────────────────────────────────────────────
  Future<void> updateClient(String id, Map<String, dynamic> data) async {
    await _col.doc(id).update(data);
  }

  // ── Delete client ─────────────────────────────────────────────────────────
  Future<void> deleteClient(String id) async {
    await _col.doc(id).delete();
  }
}
