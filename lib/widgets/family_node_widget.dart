import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/family_member.dart';
import '../providers/family_provider.dart';
import '../screens/add_edit_member_screen.dart';
import '../screens/member_detail_screen.dart';

// ── Layout constants ──────────────────────────────────────────────────────
const double _kNodeW       = 110.0;
const double _kNodeGap     = 24.0;
const double _kCoupleLineW = 28.0;
const double _kCardRowH    = 120.0;
const double _kAddRowH     = 36.0;
const double _kConnH       = 52.0;
const double _kStemY       = 22.0;
const double _kPlusSize    = 28.0;

// ═════════════════════════════════════════════════════════════════════════
// Internal tree node
// ═════════════════════════════════════════════════════════════════════════
class _TNode {
  final FamilyMember member;
  final FamilyMember? partner;
  final List<_TNode> children;

  double slotW    = 0;
  double unitOffX = 0;

  _TNode(this.member, this.partner, this.children);

  double get unitW =>
      partner != null ? _kNodeW + _kCoupleLineW + _kNodeW : _kNodeW;

  double get anchorInSlot => unitOffX + unitW / 2;
}

// ── Gen entry ─────────────────────────────────────────────────────────────
class _GEntry {
  final _TNode node;
  final double absX;
  final String? parentId;

  _GEntry(this.node, this.absX, [this.parentId]);

  double get anchorAbs => absX + node.anchorInSlot;
  double get unitLeft  => absX + node.unitOffX;
}

// ── Build tree ───────────────────────────────────────────────────────────
_TNode _buildTree(FamilyMember m, FamilyProvider p) {
  final partner  = p.getPartner(m);
  final children = p.getChildren(m.id).map((c) => _buildTree(c, p)).toList();
  return _TNode(m, partner, children);
}

// ── Compute slot widths bottom-up ─────────────────────────────────────────
void _computeSlots(_TNode n) {
  for (final c in n.children) _computeSlots(c);

  if (n.children.isEmpty) {
    n.slotW    = n.unitW;
    n.unitOffX = 0;
  } else {
    final cw = n.children.fold(0.0, (s, c) => s + c.slotW)
               + (n.children.length - 1) * _kNodeGap;
    n.slotW    = max(n.unitW, cw);
    n.unitOffX = (n.slotW - n.unitW) / 2;
  }
}

// ── BFS: collect per-generation entries with absolute X ──────────────────
List<List<_GEntry>> _toGens(_TNode root) {
  final gens = <List<_GEntry>>[];
  var cur = [_GEntry(root, 0, null)];

  while (cur.isNotEmpty) {
    gens.add(cur);
    final next = <_GEntry>[];
    for (final e in cur) {
      if (e.node.children.isEmpty) continue;
      final cw = e.node.children.fold(0.0, (s, c) => s + c.slotW)
                 + (e.node.children.length - 1) * _kNodeGap;
      double cx = e.absX + (e.node.slotW - cw) / 2;
      for (final child in e.node.children) {
        next.add(_GEntry(child, cx, e.node.member.id));
        cx += child.slotW + _kNodeGap;
      }
    }
    cur = next;
  }
  return gens;
}

// ══════════════════════════════════════════════════════════════════════════
// FamilyNodeWidget
// ══════════════════════════════════════════════════════════════════════════
class FamilyNodeWidget extends StatelessWidget {
  final FamilyMember member;
  final int depth;

  const FamilyNodeWidget({super.key, required this.member, this.depth = 0});

  Color _lc(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark
          ? const Color(0xFF7986CB)
          : const Color(0xFF3949AB);

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<FamilyProvider>();
    final lc   = _lc(context);
    final root = _buildTree(member, p);
    _computeSlots(root);
    final gens = _toGens(root);
    final w    = root.slotW;

    return SizedBox(
      width: w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < gens.length; i++) ...[
            _GenCardsRow(entries: gens[i], totalW: w, genDepth: i, lc: lc),
            _GenAddRow(entries: gens[i], totalW: w, lc: lc),
            if (i < gens.length - 1)
              _ConnectorRow(
                parents:  gens[i],
                children: gens[i + 1],
                totalW:   w,
                lc:       lc,
              ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// _GenCardsRow — all cards for one generation, positioned by absolute X
// ══════════════════════════════════════════════════════════════════════════
class _GenCardsRow extends StatelessWidget {
  final List<_GEntry> entries;
  final double totalW;
  final int genDepth;
  final Color lc;

  const _GenCardsRow({
    required this.entries,
    required this.totalW,
    required this.genDepth,
    required this.lc,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  totalW,
      height: _kCardRowH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final e in entries)
            Positioned(
              left: e.unitLeft,
              top:  0,
              child: _UnitWidget(
                main:    e.node.member,
                partner: e.node.partner,
                lc:      lc,
                depth:   genDepth,
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// _GenAddRow — "+" buttons at each node's anchor X
// ══════════════════════════════════════════════════════════════════════════
class _GenAddRow extends StatelessWidget {
  final List<_GEntry> entries;
  final double totalW;
  final Color lc;

  const _GenAddRow({
    required this.entries,
    required this.totalW,
    required this.lc,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  totalW,
      height: _kAddRowH,
      child: Stack(
        children: [
          for (final e in entries)
            Positioned(
              left: e.anchorAbs - _kPlusSize / 2,
              top:  4,
              child: _AddChildButton(
                parentId:  e.node.member.id,
                lineColor: lc,
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// _ConnectorRow — draws connector lines between two generations
// ══════════════════════════════════════════════════════════════════════════
class _ConnectorRow extends StatelessWidget {
  final List<_GEntry> parents;
  final List<_GEntry> children;
  final double totalW;
  final Color lc;

  const _ConnectorRow({
    required this.parents,
    required this.children,
    required this.totalW,
    required this.lc,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<_GEntry>> byParent = {};
    for (final c in children) {
      if (c.parentId != null) {
        byParent.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }

    final specs = <_LineSpec>[];

    for (final p in parents) {
      final kids = byParent[p.node.member.id];
      if (kids == null || kids.isEmpty) continue;

      final px = p.anchorAbs;

      if (kids.length == 1) {
        final cx = kids.first.anchorAbs;
        if ((px - cx).abs() < 1.0) {
          specs.add(_LineSpec(px, 0, px, _kConnH));
        } else {
          specs.add(_LineSpec(px, 0, px, _kStemY));
          specs.add(_LineSpec(px, _kStemY, cx, _kStemY));
          specs.add(_LineSpec(cx, _kStemY, cx, _kConnH));
        }
      } else {
        final firstCx = kids.first.anchorAbs;
        final lastCx  = kids.last.anchorAbs;

        specs.add(_LineSpec(px, 0, px, _kStemY));
        specs.add(_LineSpec(firstCx, _kStemY, lastCx, _kStemY));
        for (final kid in kids) {
          specs.add(_LineSpec(kid.anchorAbs, _kStemY, kid.anchorAbs, _kConnH));
        }
      }
    }

    return SizedBox(
      width:  totalW,
      height: _kConnH,
      child: CustomPaint(
        painter: _LinePainter(specs: specs, color: lc),
      ),
    );
  }
}

class _LineSpec {
  final double x1, y1, x2, y2;
  const _LineSpec(this.x1, this.y1, this.x2, this.y2);
}

class _LinePainter extends CustomPainter {
  final List<_LineSpec> specs;
  final Color color;

  const _LinePainter({required this.specs, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..strokeWidth = 2.5
      ..strokeCap   = StrokeCap.round;
    for (final s in specs) {
      canvas.drawLine(Offset(s.x1, s.y1), Offset(s.x2, s.y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.specs != specs || old.color != color;
}

// ══════════════════════════════════════════════════════════════════════════
// _UnitWidget — main card + optional partner card
// ══════════════════════════════════════════════════════════════════════════
class _UnitWidget extends StatelessWidget {
  final FamilyMember main;
  final FamilyMember? partner;
  final Color lc;
  final int depth;

  const _UnitWidget({
    required this.main,
    required this.partner,
    required this.lc,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _NodeCard(member: main, depth: depth),
        if (partner != null) ...[
          Container(
            width:  _kCoupleLineW,
            height: 2.5,
            decoration: BoxDecoration(
              color:        lc,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _NodeCard(member: partner!, depth: depth, isPartner: true),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// _NodeCard
// ══════════════════════════════════════════════════════════════════════════
class _NodeCard extends StatelessWidget {
  final FamilyMember member;
  final int depth;
  final bool isPartner;

  const _NodeCard({
    required this.member,
    required this.depth,
    this.isPartner = false,
  });

  Color _accent(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    if (isPartner) {
      return isDark ? const Color(0xFFCE93D8) : const Color(0xFF8E24AA);
    }
    const light = [
      Color(0xFF1A237E), Color(0xFF283593),
      Color(0xFF303F9F), Color(0xFF3949AB), Color(0xFF5C6BC0),
    ];
    const dark = [
      Color(0xFF7986CB), Color(0xFF9FA8DA),
      Color(0xFF5C6BC0), Color(0xFF7986CB), Color(0xFF9FA8DA),
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
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => MemberDetailScreen(member: member))),
      onLongPress: () => _showOptions(context, provider),
      child: Container(
        width:   _kNodeW,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:        cardBg,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: accent, width: 2),
          boxShadow: [
            BoxShadow(
              color:      accent.withOpacity(isDark ? 0.25 : 0.15),
              blurRadius: 8,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius:          28,
              backgroundColor: accent.withOpacity(0.15),
              backgroundImage: member.photoPath != null
                  ? FileImage(File(member.photoPath!))
                  : null,
              child: member.photoPath == null
                  ? Icon(Icons.person, color: accent, size: 28)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              member.name,
              textAlign: TextAlign.center,
              maxLines:  2,
              overflow:  TextOverflow.ellipsis,
              style: TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      accent,
              ),
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
                width:  40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color:        Colors.grey[400],
                    borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF1A237E)),
                title:   const Text('Edit'),
                onTap: () {
                  Navigator.pop(bsCtx);
                  Navigator.push(ctx, MaterialPageRoute(
                      builder: (_) => AddEditMemberScreen(existing: member)));
                },
              ),
              if (isPartner)
                ListTile(
                  leading: const Icon(Icons.link_off, color: Colors.orange),
                  title:   const Text('Hapus Hubungan Pasangan',
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
                title:   const Text('Hapus', style: TextStyle(color: Colors.red)),
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
        title:   const Text('Hapus Anggota'),
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
// _AddChildButton
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

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => AddEditMemberScreen(parentId: parentId))),
      child: Container(
        width:  _kPlusSize,
        height: _kPlusSize,
        decoration: BoxDecoration(
          shape:  BoxShape.circle,
          border: Border.all(color: accent, width: 2),
          color:  bg,
        ),
        child: Icon(Icons.add, size: 14, color: accent),
      ),
    );
  }
}