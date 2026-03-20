import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/family_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/add_edit_member_screen.dart';
import '../widgets/family_node_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarColor =
        isDark ? const Color(0xFF1E1E2E) : const Color(0xFF1A237E);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Silsilah Keluarga',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Dark mode toggle
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) => IconButton(
              icon: Icon(
                themeProvider.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
              tooltip: themeProvider.isDark ? 'Light Mode' : 'Dark Mode',
              onPressed: themeProvider.toggle,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Export',
            onPressed: () => _export(context),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Import',
            onPressed: () => _import(context),
          ),
        ],
      ),
      body: Consumer<FamilyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.roots.isEmpty) {
            return _EmptyState(
              onAdd: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditMemberScreen(),
                ),
              ),
            );
          }

          final lineColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;

          return InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(80),
            minScale: 0.3,
            maxScale: 2.0,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tombol "+" paling atas untuk tambah leluhur baru
                  _AddRootButton(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddEditMemberScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Garis dari tombol "+" ke root
                  Container(width: 2.5, height: 24, color: lineColor),
                  const SizedBox(height: 8),
                  for (int i = 0; i < provider.roots.length; i++) ...[
                    FamilyNodeWidget(member: provider.roots[i]),
                    if (i < provider.roots.length - 1)
                      const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final provider = context.read<FamilyProvider>();
    if (provider.members.isEmpty) {
      _showSnack(context, 'Belum ada data untuk diekspor.');
      return;
    }
    try {
      _showSnack(context, 'Menyiapkan file...');
      final path = await provider.exportData();
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Silsilah Keluarga',
        text: 'Data silsilah keluarga',
      );
    } catch (e) {
      _showSnack(context, 'Gagal export: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;
    final provider = context.read<FamilyProvider>();

    if (!context.mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text(
          'Pilih cara import:\n\n'
          'Gabung: menambahkan anggota baru tanpa menghapus data existing.\n\n'
          'Ganti Semua: menghapus semua data dan menggantinya dengan data yang diimport.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'merge'),
            child: const Text('Gabung'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ganti Semua'),
          ),
        ],
      ),
    );

    if (choice == null || choice == 'cancel') return;

    try {
      if (choice == 'merge') {
        final added = await provider.importData(filePath);
        if (context.mounted) {
          _showSnack(context, '$added anggota baru berhasil ditambahkan.');
        }
      } else {
        await provider.replaceAllData(filePath);
        if (context.mounted) {
          _showSnack(context, 'Data berhasil diganti.');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Gagal import: $e');
      }
    }
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AddRootButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddRootButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        isDark ? const Color(0xFF7986CB) : const Color(0xFF1A237E);
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              border: Border.all(color: accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(Icons.add, color: accent, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            'Tambah Anggota',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_tree_outlined,
              size: 80,
              color: isDark ? Colors.grey[600] : Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Belum ada silsilah keluarga',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap tombol di bawah untuk menambahkan\nanggota pertama',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add),
            label: const Text('Tambah Anggota Pertama'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF7986CB)
                  : const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}