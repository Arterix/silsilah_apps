import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_member.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // Gunakan userId sebagai root collection agar tiap user punya data sendiri
  CollectionReference _col(String userId) =>
      _db.collection('users').doc(userId).collection('members');

  // ── Load semua member ─────────────────────────────────────────
  Future<List<FamilyMember>> loadMembers(String userId) async {
    final snap = await _col(userId).get();
    return snap.docs
        .map((d) => FamilyMember.fromJson(d.data() as Map<String, dynamic>))
        .toList();
  }

  // ── Simpan satu member ────────────────────────────────────────
  Future<void> saveMember(String userId, FamilyMember member) async {
    await _col(userId).doc(member.id).set(member.toJson());
  }

  // ── Hapus satu member ─────────────────────────────────────────
  Future<void> deleteMember(String userId, String memberId) async {
    await _col(userId).doc(memberId).delete();
  }

  // ── Hapus banyak member sekaligus (batch) ─────────────────────
  Future<void> deleteMembers(String userId, List<String> ids) async {
    final batch = _db.batch();
    for (final id in ids) {
      batch.delete(_col(userId).doc(id));
    }
    await batch.commit();
  }

  // ── Simpan banyak member sekaligus (batch) ────────────────────
  Future<void> saveAllMembers(String userId, List<FamilyMember> members) async {
    final batch = _db.batch();
    for (final m in members) {
      batch.set(_col(userId).doc(m.id), m.toJson());
    }
    await batch.commit();
  }

  // ── Realtime stream (opsional) ────────────────────────────────
  Stream<List<FamilyMember>> membersStream(String userId) {
    return _col(userId).snapshots().map((snap) => snap.docs
        .map((d) => FamilyMember.fromJson(d.data() as Map<String, dynamic>))
        .toList());
  }
}