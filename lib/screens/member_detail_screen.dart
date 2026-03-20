import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/family_member.dart';
import '../providers/family_provider.dart';
import 'add_edit_member_screen.dart';

class MemberDetailScreen extends StatelessWidget {
  final FamilyMember member;
  const MemberDetailScreen({super.key, required this.member});

  static const Color _accent = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    final prov    = context.watch<FamilyProvider>();
    final m       = prov.getById(member.id) ?? member;
    final children = prov.getChildren(m.id);

    // ── Cari orang tua ──────────────────────────────────────────
    // Orang tua utama (yang punya parentId)
    FamilyMember? primaryParent =
        m.parentId != null ? prov.getById(m.parentId!) : null;

    // Pasangan dari orang tua utama (orang tua kedua)
    FamilyMember? secondaryParent;
    if (primaryParent != null) {
      final partnerOfParent = prov.getPartner(primaryParent);
      if (partnerOfParent != null) secondaryParent = partnerOfParent;
    }

    // Pasangan member ini sendiri
    final partner = prov.getPartner(m);

    return Scaffold(
      appBar: AppBar(
        title: Text(m.name),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => AddEditMemberScreen(existing: m))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, prov, m),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Foto & Nama ──────────────────────────────────
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: _accent.withOpacity(0.1),
                    backgroundImage: m.photoPath != null
                        ? FileImage(File(m.photoPath!))
                        : null,
                    child: m.photoPath == null
                        ? const Icon(Icons.person, size: 64, color: _accent)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(m.name,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _accent)),
                  if (m.notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(m.notes,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Pasangan ─────────────────────────────────────
            _sectionTitle('Pasangan'),
            const SizedBox(height: 8),
            if (partner != null) ...[
              _RelationChip(
                member: partner,
                onTap: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(
                        builder: (_) => MemberDetailScreen(member: partner))),
              ),
              const SizedBox(height: 8),
              _removePartnerBtn(context, prov, m),
            ] else if (!m.isPartnerNode)
              _addPartnerBtn(context, m),

            const SizedBox(height: 20),

            // ── Orang Tua ────────────────────────────────────
            _sectionTitle('Orang Tua'),
            const SizedBox(height: 8),
            if (primaryParent == null && secondaryParent == null)
              const Text('Tidak ada data orang tua.',
                  style: TextStyle(color: Colors.grey))
            else
              Builder(builder: (context) {
                final p1 = primaryParent;
                final p2 = secondaryParent;
                return Row(
                  children: [
                    if (p1 != null)
                      Expanded(
                        child: _RelationChip(
                          member: p1,
                          onTap: () => Navigator.pushReplacement(context,
                              MaterialPageRoute(
                                  builder: (_) => MemberDetailScreen(member: p1))),
                        ),
                      ),
                    if (p1 != null && p2 != null) const SizedBox(width: 10),
                    if (p2 != null)
                      Expanded(
                        child: _RelationChip(
                          member: p2,
                          onTap: () => Navigator.pushReplacement(context,
                              MaterialPageRoute(
                                  builder: (_) => MemberDetailScreen(member: p2))),
                        ),
                      ),
                  ],
                );
              }),

            const SizedBox(height: 20),

            // ── Anak ─────────────────────────────────────────
            _sectionTitle('Anak (${children.length})'),
            const SizedBox(height: 8),
            if (children.isEmpty)
              const Text('Belum ada anak.', style: TextStyle(color: Colors.grey)),
            ...children.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RelationChip(
                    member: c,
                    onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(
                            builder: (_) => MemberDetailScreen(member: c))),
                  ),
                )),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => AddEditMemberScreen(parentId: m.id))),
              icon: const Icon(Icons.add, color: _accent),
              label: const Text('Tambah Anak', style: TextStyle(color: _accent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _accent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _accent.withOpacity(0.7),
            letterSpacing: 1.1),
      );

  Widget _addPartnerBtn(BuildContext context, FamilyMember m) =>
      OutlinedButton.icon(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => AddEditMemberScreen(
                      isAddingPartner: true,
                      forMemberId: m.id,
                    ))),
        icon: const Icon(Icons.favorite_border, color: _accent),
        label: const Text('Tambah Pasangan', style: TextStyle(color: _accent)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  Widget _removePartnerBtn(
          BuildContext context, FamilyProvider prov, FamilyMember m) =>
      OutlinedButton.icon(
        onPressed: () => _confirmRemovePartner(context, prov, m),
        icon: const Icon(Icons.link_off, color: Colors.orange),
        label: const Text('Hapus Pasangan', style: TextStyle(color: Colors.orange)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.orange),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  void _confirmDelete(BuildContext ctx, FamilyProvider prov, FamilyMember m) {
    final hasChildren = prov.getChildren(m.id).isNotEmpty;
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Hapus Anggota'),
        content: Text(hasChildren
            ? 'Hapus "${m.name}"? Semua anggota di bawahnya juga akan ikut terhapus.'
            : 'Hapus "${m.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx);
              prov.deleteMember(m.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _confirmRemovePartner(
      BuildContext ctx, FamilyProvider prov, FamilyMember m) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Hapus Hubungan Pasangan'),
        content: const Text(
            'Data pasangan akan dihapus dari pohon keluarga. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
          TextButton(
            onPressed: () { Navigator.pop(dCtx); prov.removePartner(m.id); },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

// ── Relation chip ─────────────────────────────────────────────────────────
class _RelationChip extends StatelessWidget {
  final FamilyMember member;
  final VoidCallback onTap;
  const _RelationChip({required this.member, required this.onTap});

  static const Color _accent = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _accent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accent.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _accent.withOpacity(0.15),
              backgroundImage: member.photoPath != null
                  ? FileImage(File(member.photoPath!))
                  : null,
              child: member.photoPath == null
                  ? const Icon(Icons.person, size: 18, color: _accent)
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(member.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: _accent)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: _accent.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}