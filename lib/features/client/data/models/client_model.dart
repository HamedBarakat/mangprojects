import 'package:cloud_firestore/cloud_firestore.dart';

// ── Client Contact ────────────────────────────────────────────────────────────

class ClientContact {
  final String id;
  final String name;
  final String role;
  final String? phone;
  final String? email;

  const ClientContact({
    required this.id,
    required this.name,
    required this.role,
    this.phone,
    this.email,
  });

  factory ClientContact.fromMap(Map<String, dynamic> map) {
    return ClientContact(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? '',
      phone: map['phone'] as String?,
      email: map['email'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (email != null && email!.isNotEmpty) 'email': email,
    };
  }
}

// ── Client Model ──────────────────────────────────────────────────────────────

class ClientModel {
  final String id;
  final String officeId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;
  final List<ClientContact> contacts;
  final DateTime createdAt;

  const ClientModel({
    required this.id,
    required this.officeId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    required this.isActive,
    required this.contacts,
    required this.createdAt,
  });

  factory ClientModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ClientModel(
      id: doc.id,
      officeId: d['officeId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      phone: d['phone'] as String?,
      email: d['email'] as String?,
      address: d['address'] as String?,
      notes: d['notes'] as String?,
      isActive: d['isActive'] as bool? ?? true,
      contacts: (d['contacts'] as List<dynamic>?)
              ?.map((c) =>
                  ClientContact.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'officeId': officeId,
      'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (notes != null) 'notes': notes,
      'isActive': isActive,
      'contacts': contacts.map((c) => c.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ClientModel copyWith({
    String? id,
    String? officeId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    bool? isActive,
    List<ClientContact>? contacts,
    DateTime? createdAt,
  }) {
    return ClientModel(
      id: id ?? this.id,
      officeId: officeId ?? this.officeId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      contacts: contacts ?? this.contacts,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
