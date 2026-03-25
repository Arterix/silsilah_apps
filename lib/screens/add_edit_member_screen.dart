import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/family_member.dart';
import '../providers/family_provider.dart';

class AddEditMemberScreen extends StatefulWidget {
  final FamilyMember? existing;
  final String? parentId;
  // Jika ini adalah screen untuk menambah pasangan
  final bool isAddingPartner;
  final String? forMemberId;

  const AddEditMemberScreen({
    super.key,
    this.existing,
    this.parentId,
    this.isAddingPartner = false,
    this.forMemberId,
  });

  @override
  State<AddEditMemberScreen> createState() => _AddEditMemberScreenState();
}

class _AddEditMemberScreenState extends State<AddEditMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _notesCtrl;
  String? _photoPath;
  bool _isSaving = false;
  final _picker = ImagePicker();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
    _photoPath = widget.existing?.photoPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Hapus Foto', style: TextStyle(color: Colors.red)),
                onTap: () {
                  setState(() => _photoPath = null);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
    if (src == null) return;
    final picked = await _picker.pickImage(source: src, imageQuality: 75);
    if (picked != null) setState(() => _photoPath = picked.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final provider = context.read<FamilyProvider>();
    String? savedPhotoPath;

    try {
      // Jika menambahkan PASANGAN
      if (widget.isAddingPartner && widget.forMemberId != null) {
        final partnerId = const Uuid().v4();
        if (_photoPath != null && !_photoPath!.contains('/app_data/')) {
          savedPhotoPath = await provider.savePhoto(_photoPath!, partnerId);
        } else {
          savedPhotoPath = _photoPath;
        }
        final partner = FamilyMember(
          id: partnerId,
          name: _nameCtrl.text.trim(),
          photoPath: savedPhotoPath,
          notes: _notesCtrl.text.trim(),
          isPartnerNode: true,
        );
        await provider.addPartner(widget.forMemberId!, partner);
        if (mounted) Navigator.pop(context);
        return;
      }

      // Add atau Edit biasa
      if (_isEdit) {
        final existing = widget.existing!;
        if (_photoPath != null &&
            _photoPath != existing.photoPath &&
            !_photoPath!.contains('/app_data/')) {
          savedPhotoPath =
              await provider.savePhoto(_photoPath!, existing.id);
        } else {
          savedPhotoPath = _photoPath;
        }
        await provider.updateMember(existing.copyWith(
          name: _nameCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          photoPath: savedPhotoPath,
        ));
      } else {
        final newId = const Uuid().v4();
        if (_photoPath != null) {
          savedPhotoPath = await provider.savePhoto(_photoPath!, newId);
        }
        final member = FamilyMember(
          id: newId,
          name: _nameCtrl.text.trim(),
          photoPath: savedPhotoPath,
          parentId: widget.parentId,
          notes: _notesCtrl.text.trim(),
        );
        if (widget.parentId == null) {
          await provider.addAncestor(member);
        } else {
          await provider.addMember(member);
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF1A237E);

    String title;
    if (widget.isAddingPartner) {
      title = 'Tambah Pasangan';
    } else if (_isEdit) {
      title = 'Edit Anggota';
    } else if (widget.parentId == null) {
      title = 'Tambah Leluhur';
    } else {
      title = 'Tambah Anggota';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Foto ───────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: accent.withOpacity(0.1),
                      backgroundImage: _photoPath != null
                          ? FileImage(File(_photoPath!))
                          : null,
                      child: _photoPath == null
                          ? const Icon(Icons.person, size: 54, color: accent)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt,
                          size: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Nama ───────────────────────────────────────────
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nama',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accent, width: 2),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // ── Keterangan ─────────────────────────────────────
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: 'Keterangan (opsional)',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accent, width: 2),
                ),
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 28),

            // ── Tombol Simpan ─────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}