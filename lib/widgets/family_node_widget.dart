import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/family_member.dart';
import '../providers/family_provider.dart';
import '../screens/add_edit_member_screen.dart';
import '../screens/member_detail_screen.dart';

// ── Konstanta Layout ──────────────────────────────────────────────────────
const double _kNodeWidth    = 110.0;
const double _kNodeGap      = 24.0;
const double _kCoupleLineH  = 24.0; // panjang garis menikah
const double _kPlusSize     = 32.0;
const double _kVLineH       = 20.0;

// ── Metrics: (subtreeWidth, anchorX) ─────────────────────────────────────
// anchorX = posisi horizontal tengah node utama di dalam subtreenya
(double, double) _metrics(FamilyMember m, FamilyProvider p) {
  final children   = p.getChildren(m.id);
  final hasPartner = p.getPartner(m) != null;

  double ctw = 0; // children total width
  if (children.isNotEmpty) {
    ctw = children.fold(0.0, (a, c) => a + _metrics(c, p).$1) +
          (children.length - 1) * _kNodeGap;
  }

  if (!hasPartner) {
    final w = max(_kNodeWidth, ctw);
    return (w, w / 2);
  }

  // Dengan pasangan: node utama di kiri, pasangan di kanan
  // anchor = leftSpace (tengah node utama)
  final leftSpace  = max(_kNodeWidth / 2, ctw / 2);
  const rightSpace = _kNodeWidth / 2 + _kCoupleLineH + _kNodeWidth;
  return (leftSpace + rightSpace, leftSpace);
}

// ── Helper: posisikan child dengan center di posisi cx dalam container sw ─
Widget _cx(double sw, double cx, double childW, Widget child) {
  final left = max(0.0, cx - childW / 2);
  return SizedBox(
    width: sw,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SizedBox(width: left), child],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════
class FamilyNodeWidget extends StatelessWidget {
  final FamilyMember member;
  final int depth;

  const FamilyNodeWidget({super.key, required this.member, this.depth = 0});

  Color _lineColor(BuildContext ctx) {
    return Theme.of(ctx).brightness == Brightness.dark
        ? const Color(0xFF7986CB)
        : const Color(0xFF3949AB);
  }

  @override
  Widget build(BuildContext context) {
    final p       = context.watch<FamilyProvider>();
    final partner = p.getPartner(member);
    final children = p.getChildren(member.id);
    final (sw, ax) = _metrics(member, p);
    final lc = _lineColor(context);

    // Per-child metrics
    final cm = children.map((c) {
      final (w, a) = _metrics(c, p);
      return (c, w, a); // (member, subtreeW, anchorX)
    }).toList();

    final ctw = cm.isEmpty
        ? 0.0
        : cm.fold<double>(0.0, (a, x) => a + x.$2) +
          (cm.length - 1) * _kNodeGap;

    return SizedBox(
      width: sw,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Node utama + pasangan ────────────────────────────
          _buildNodeRow(context, partner, ax, sw, lc),

          // ── Tombol + tambah anak (di bawah node utama) ───────
          _cx(sw, ax, _kPlusSize,
              _AddChildButton(parentId: member.id, lineColor: lc)),

          // ── Children subtree ─────────────────────────────────
          if (cm.isNotEmpty) ...[
            _cx(sw, ax, 2.5,
                Container(width: 2.5, height: _kVLineH, color: lc)),
            if (cm.length > 1)
              _buildHConnector(sw, ax, cm, ctw, lc),
            _buildChildrenRow(sw, ax, cm, ctw, lc),
          ],
        ],
      ),
    );
  }

  // ── Baris node + opsional pasangan ──────────────────────────────────────
  Widget _buildNodeRow(
    BuildContext context,
    FamilyMember? partner,
    double ax,
    double sw,
    Color lc,
  ) {
    final nodeLeft = max(0.0, ax - _kNodeWidth / 2);
    return SizedBox(
      width: sw,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: nodeLeft),
          _NodeCard(member: member, depth: depth),
          if (partner != null) ...[
            Container(width: _kCoupleLineH, height: 2.5, color: lc),
            _NodeCard(member: partner, depth: depth, isPartner: true),
          ],
        ],
      ),
    );
  }

  // ── Garis horizontal penghubung anchor tiap anak ───────────────────────
  Widget _buildHConnector(
    double sw,
    double ax,
    List<(FamilyMember, double, double)> cm,
    double ctw,
    Color lc,
  ) {
    final rowLeft = ax - ctw / 2;
    final startX  = rowLeft + cm.first.$3;
    double xOff   = 0;
    for (int i = 0; i < cm.length - 1; i++) {
      xOff += cm[i].$2 + _kNodeGap;
    }
    final endX = rowLeft + xOff + cm.last.$3;

    return SizedBox(
      width: sw,
      height: 2.5,
      child: CustomPaint(
          painter: _HLinePainter(startX: startX, endX: endX, color: lc)),
    );
  }

  // ── Deretan anak dengan VLine per anak ────────────────────────────────
  Widget _buildChildrenRow(
    double sw,
    double ax,
    List<(FamilyMember, double, double)> cm,
    double ctw,
    Color lc,
  ) {
    final rowLeft = ax - ctw / 2;
    return SizedBox(
      width: sw,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: rowLeft),
          ...List.generate(cm.length, (i) {
            final (child, cw, cax) = cm[i];
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i > 0) const SizedBox(width: _kNodeGap),
                SizedBox(
                  width: cw,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // VLine di anchor anak
                      _cx(cw, cax, 2.5,
                          Container(width: 2.5, height: _kVLineH, color: lc)),
                      FamilyNodeWidget(member: child, depth: depth + 1),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Node Card
// ══════════════════════════════════════════════════════════════════════════
class _NodeCard extends StatelessWidget {
  final FamilyMember member;
  final int depth;
  final bool isPartner;

  const _NodeCard({required this.member, required this.depth, this.isPartner = false});

  Color _accent(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    if (isPartner) {
      return isDark ? const Color(0xFFCE93D8) : const Color(0xFF8E24AA);
    }
    final light = [
      const Color(0xFF1A237E),
      const Color(0xFF283593),
      const Color(0xFF303F9F),
      const Color(0xFF3949AB),
      const Color(0xFF5C6BC0),
    ];
    final dark = [
      const Color(0xFF7986CB),
      const Color(0xFF9FA8DA),
      const Color(0xFF5C6BC0),
      const Color(0xFF7986CB),
      const Color(0xFF9FA8DA),
    ];
    return (isDark ? dark : light)[depth.clamp(0, 4)];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<FamilyProvider>();
    final accent   = _accent(context);
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final cardBg   = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MemberDetailScreen(member: member)),
      ),
      onLongPress: () => _showOptions(context, provider),
      child: Container(
        width: _kNodeWidth,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(isDark ? 0.25 : 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: accent.withOpacity(0.15),
              backgroundImage:
                  member.photoPath != null ? FileImage(File(member.photoPath!)) : null,
              child: member.photoPath == null
                  ? Icon(Icons.person, color: accent, size: 28)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              member.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: accent),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext ctx, FamilyProvider provider) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bsCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF1A237E)),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(bsCtx);
                  Navigator.push(ctx,
                      MaterialPageRoute(
                          builder: (_) => AddEditMemberScreen(existing: member)));
                },
              ),
              if (isPartner)
                ListTile(
                  leading: const Icon(Icons.link_off, color: Colors.orange),
                  title: const Text('Hapus Hubungan Pasangan',
                      style: TextStyle(color: Colors.orange)),
                  onTap: () {
                    Navigator.pop(bsCtx);
                    final main = provider.members.firstWhere(
                        (m) => m.partnerId == member.id,
                        orElse: () => member);
                    provider.removePartner(main.id);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Hapus', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(bsCtx);
                  _confirmDelete(ctx, provider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, FamilyProvider provider) {
    final hasChildren = provider.getChildren(member.id).isNotEmpty;
    showDialog(
      context: ctx,
      builder: (dlg) => AlertDialog(
        title: const Text('Hapus Anggota'),
        content: Text(hasChildren
            ? 'Hapus "${member.name}"? Semua anggota di bawahnya juga akan ikut terhapus.'
            : 'Hapus "${member.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlg),
              child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(dlg);
              provider.deleteMember(member.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Tombol + (tambah anak)
// ══════════════════════════════════════════════════════════════════════════
class _AddChildButton extends StatelessWidget {
  final String parentId;
  final Color lineColor;

  const _AddChildButton({required this.parentId, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF7986CB) : const Color(0xFF1A237E);
    final bg     = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AddEditMemberScreen(parentId: parentId)),
        ),
        child: Container(
          width: _kPlusSize,
          height: _kPlusSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: 2),
            color: bg,
          ),
          child: Icon(Icons.add, size: 18, color: accent),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Custom painter garis horizontal
// ══════════════════════════════════════════════════════════════════════════
class _HLinePainter extends CustomPainter {
  final double startX;
  final double endX;
  final Color color;

  const _HLinePainter({required this.startX, required this.endX, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(startX, size.height / 2),
      Offset(endX, size.height / 2),
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HLinePainter old) =>
      old.startX != startX || old.endX != endX || old.color != color;
}