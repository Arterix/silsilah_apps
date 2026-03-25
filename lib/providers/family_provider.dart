import 'package:flutter/foundation.dart';
import '../models/family_member.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';
import 'dart:async';

class FamilyProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final FirestoreService _firestore = FirestoreService();

  List<FamilyMember> _members = [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _sub;

  List<FamilyMember> get members => _members;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Root nodes: tidak punya parent DAN bukan partner node
  List<FamilyMember> get roots =>
      _members.where((m) => m.parentId == null && !m.isPartnerNode).toList();

  FamilyMember? getById(String id) {
    try {
      return _members.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Children tidak termasuk partner nodes
  List<FamilyMember> getChildren(String parentId) =>
      _members.where((m) => m.parentId == parentId && !m.isPartnerNode).toList();

  FamilyMember? getPartner(FamilyMember member) {
    if (member.partnerId == null) return null;
    final p = getById(member.partnerId!);
    if (p == null || !p.isPartnerNode) return null;
    return p;
  }

  // ── Init ────────────────────────────────────────────────────────

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _members = await _storage.loadMembers();
      if (_members.isNotEmpty) notifyListeners();
    } catch (_) {}

    // Aktifkan real-time listener ke Firestore
    _startListening();

    _isLoading = false;
    notifyListeners();
  }

  // Listener ini berjalan terus selama app hidup.
  void _startListening() {
    _sub?.cancel(); // batalkan listener lama jika ada

    _sub = _firestore.membersStream().listen(
      (remoteMembers) async {
        if (remoteMembers.isNotEmpty) {
          _members = remoteMembers;
          // Sync ke lokal untuk offline access
          await _storage.saveMembers(_members);
          notifyListeners();
        } else if (_members.isEmpty) {
          // Firestore kosong, coba ambil dari lokal (migrasi data lama)
          _members = await _storage.loadMembers();
          if (_members.isNotEmpty) {
            await _firestore.saveAllMembers(_members);
          }
          notifyListeners();
        }
      },
      onError: (e) {
        // Koneksi gagal, pakai data lokal yang sudah ada
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  // Hentikan listener saat provider di-dispose
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── CRUD ────────────────────────────────────────────────────────

  Future<void> addMember(FamilyMember member) async {
    _members.add(member);
    if (member.parentId != null) {
      final pIdx = _members.indexWhere((m) => m.id == member.parentId);
      if (pIdx != -1 && !_members[pIdx].childrenIds.contains(member.id)) {
        _members[pIdx].childrenIds.add(member.id);
      }
    }
    await _persist();
  }

  Future<void> updateMember(FamilyMember updated) async {
    final idx = _members.indexWhere((m) => m.id == updated.id);
    if (idx == -1) return;
    _members[idx] = updated;
    await _persist();
  }

  Future<void> deleteMember(String id) async {
    final idsToDelete = <String>{};
    _collectDescendants(id, idsToDelete);

    for (final deleteId in List<String>.from(idsToDelete)) {
      final m = getById(deleteId);
      if (m?.partnerId != null) {
        final partner = getById(m!.partnerId!);
        if (partner != null && partner.isPartnerNode) {
          idsToDelete.add(partner.id);
        }
      }
    }

    // Hapus foto
    for (final deleteId in idsToDelete) {
      final m = getById(deleteId);
      if (m?.photoPath != null) await _storage.deletePhoto(deleteId);
    }

    // Putus relasi dari parent
    final member = getById(id);
    if (member?.parentId != null) {
      final pIdx = _members.indexWhere((m) => m.id == member!.parentId);
      if (pIdx != -1) _members[pIdx].childrenIds.remove(id);
    }

    // Bersihkan partnerId pada member lain yang menunjuk ke member yang dihapus
    for (final m in _members) {
      if (idsToDelete.contains(m.partnerId)) {
        final idx = _members.indexWhere((x) => x.id == m.id);
        if (idx != -1) {
          _members[idx] = _members[idx].copyWith(clearPartnerId: true);
        }
      }
    }

    try {
      await _firestore.deleteMembers(idsToDelete.toList());
    } catch (_) {}

    await _persist();
  }

  void _collectDescendants(String id, Set<String> result) {
    result.add(id);
    final member = getById(id);
    if (member == null) return;
    for (final childId in List<String>.from(member.childrenIds)) {
      _collectDescendants(childId, result);
    }
  }

  // ── Partner ─────────────────────────────────────────────────────

  /// Membuat pasangan baru untuk [memberId] dan menghubungkan keduanya.
  Future<void> addPartner(String memberId, FamilyMember partner) async {
    // partner.isPartnerNode = true sudah di-set oleh pemanggil
    _members.add(partner);

    final mIdx = _members.indexWhere((m) => m.id == memberId);
    if (mIdx != -1) {
      _members[mIdx] = _members[mIdx].copyWith(partnerId: partner.id);
    }
    await _persist();
  }

  /// Putus hubungan pasangan (hapus partner node, bersihkan partnerId).
  Future<void> removePartner(String memberId) async {
    final member = getById(memberId);
    if (member?.partnerId == null) return;

    final partner = getById(member!.partnerId!);
    if (partner != null && partner.isPartnerNode) {
      if (partner.photoPath != null) await _storage.deletePhoto(partner.id);
      try {
        await _firestore.deleteMembers([partner.id]);
      } catch (_) {}
      _members.removeWhere((m) => m.id == partner.id);
    }

    final mIdx = _members.indexWhere((m) => m.id == memberId);
    if (mIdx != -1) {
      _members[mIdx] = _members[mIdx].copyWith(clearPartnerId: true);
    }
    await _persist();
  }

  // ── Ancestor ─────────────────────────────────────────────────────

  Future<void> addAncestor(FamilyMember newAncestor) async {
    final currentRoots = roots;
    for (final root in currentRoots) {
      final idx = _members.indexWhere((m) => m.id == root.id);
      if (idx != -1) {
        _members[idx] = _members[idx].copyWith(parentId: newAncestor.id);
        if (!newAncestor.childrenIds.contains(root.id)) {
          newAncestor.childrenIds.add(root.id);
        }
      }
    }
    _members.add(newAncestor);
    await _persist();
  }

  // ── Export / Import ─────────────────────────────────────────────

  Future<String> exportData() async => _storage.exportToFile(_members);

  Future<int> importData(String filePath) async {
    final imported = await _storage.importFromFile(filePath);
    int addedCount = 0;

    for (final incoming in imported) {
      final existingIdx = _members.indexWhere((m) => m.id == incoming.id);
      if (existingIdx == -1) {
        _members.add(incoming);
        addedCount++;
      } else {
        final existing = _members[existingIdx];
        final mergedChildren = List<String>.from(existing.childrenIds);
        for (final cid in incoming.childrenIds) {
          if (!mergedChildren.contains(cid)) mergedChildren.add(cid);
        }
        if (mergedChildren.length != existing.childrenIds.length) {
          _members[existingIdx] = existing.copyWith(childrenIds: mergedChildren);
        }
      }
    }

    for (final m in _members) {
      if (m.parentId != null) {
        final pIdx = _members.indexWhere((p) => p.id == m.parentId);
        if (pIdx != -1 && !_members[pIdx].childrenIds.contains(m.id)) {
          _members[pIdx].childrenIds.add(m.id);
        }
      }
    }

    if (addedCount > 0) await _persist();
    return addedCount;
  }

  Future<void> replaceAllData(String filePath) async {
    final imported = await _storage.importFromFile(filePath);
    _members = imported;

    try {
      await _firestore.deleteAllMembers();
    } catch (_) {}

    await _persist();
  }

  // ── Photo ───────────────────────────────────────────────────────

  Future<String> savePhoto(String sourcePath, String memberId) =>
      _storage.savePhoto(sourcePath, memberId);

  // ── Persist ─────────────────────────────────────────────────────

  Future<void> _persist() async {
  await _storage.saveMembers(_members);
  try {
    await _firestore.saveAllMembers(_members);
  } catch (_) {}
  notifyListeners();
}
}

