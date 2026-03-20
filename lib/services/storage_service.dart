import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/family_member.dart';

class StorageService {
  static const _membersKey = 'family_members';

  // ── Local Storage ──────────────────────────────────────────────

  Future<List<FamilyMember>> loadMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_membersKey);
    if (raw == null) return [];
    return FamilyMember.decodeList(raw);
  }

  Future<void> saveMembers(List<FamilyMember> members) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_membersKey, FamilyMember.encodeList(members));
  }

  // ── Export ─────────────────────────────────────────────────────

  /// Exports all members as a JSON file.
  /// Photos are embedded as base64 strings so the file is self-contained.
  Future<String> exportToFile(List<FamilyMember> members) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final file = File('${dir.path}/silsilah_keluarga_$timestamp.json');

    // Encode photos as base64
    final exportData = await Future.wait(members.map((m) async {
      final map = m.toJson();
      if (m.photoPath != null) {
        final photoFile = File(m.photoPath!);
        if (await photoFile.exists()) {
          final bytes = await photoFile.readAsBytes();
          map['photoBase64'] = base64Encode(bytes);
          map['photoPath'] = null; // clear local path
        }
      }
      return map;
    }));

    await file.writeAsString(jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'members': exportData,
    }));

    return file.path;
  }

  // ── Import ─────────────────────────────────────────────────────

  /// Imports members from a JSON file path.
  /// Photos in base64 are saved as local files.
  Future<List<FamilyMember>> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File tidak ditemukan.');

    final raw = await file.readAsString();
    final json = jsonDecode(raw);

    final membersJson = (json['members'] as List);
    final dir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${dir.path}/photos');
    if (!await photoDir.exists()) await photoDir.create();

    final members = await Future.wait(membersJson.map((item) async {
      final map = Map<String, dynamic>.from(item);
      final base64Photo = map['photoBase64'] as String?;
      if (base64Photo != null && base64Photo.isNotEmpty) {
        final bytes = base64Decode(base64Photo);
        final photoFile = File('${photoDir.path}/${map['id']}.jpg');
        await photoFile.writeAsBytes(bytes);
        map['photoPath'] = photoFile.path;
      }
      map.remove('photoBase64');
      return FamilyMember.fromJson(map);
    }));

    return members;
  }

  // ── Photo Storage ──────────────────────────────────────────────

  Future<String> savePhoto(String sourcePath, String memberId) async {
    final dir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${dir.path}/photos');
    if (!await photoDir.exists()) await photoDir.create();

    final dest = File('${photoDir.path}/$memberId.jpg');
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  Future<void> deletePhoto(String memberId) async {
    final dir = await getApplicationDocumentsDirectory();
    final photoFile = File('${dir.path}/photos/$memberId.jpg');
    if (await photoFile.exists()) await photoFile.delete();
  }
}