import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_member.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // Gunakan satu userId tetap karena belum ada Auth
  static const _userId = 'default_user';

  CollectionReference get _col =>
      _db.collection('users').doc(_userId).collection('members');

  // ── Real-time stream ──────────────────────────────────────────
  Stream<List<FamilyMember>> membersStream() {
    return _col.snapshots().map((snap) => snap.docs
        .map((d) => FamilyMember.fromJson(d.data() as Map<String, dynamic>))
        .toList());
  }

  // ── Load semua member ─────────────────────────────────────────
  Future<List<FamilyMember>> loadMembers() async {
    final snap = await _col.get();
    return snap.docs
        .map((d) => FamilyMember.fromJson(d.data() as Map<String, dynamic>))
        .toList();
  }

  // ── Simpan banyak member sekaligus (batch) ────────────────────
  Future<void> saveAllMembers(List<FamilyMember> members) async {
    final batch = _db.batch();
    for (final m in members) {
      batch.set(_col.doc(m.id), m.toJson());
    }
    await batch.commit();
  }

  // ── Hapus banyak member sekaligus (batch) ─────────────────────
  Future<void> deleteMembers(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _db.batch();
    for (final id in ids) {
      batch.delete(_col.doc(id));
    }
    await batch.commit();
  }

  // ── Hapus SEMUA member (untuk fitur replace all) ──────────────
  Future<void> deleteAllMembers() async {
    final snap  = await _col.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}