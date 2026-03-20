import 'dart:convert';

class FamilyMember {
  final String id;
  String name;
  String? photoPath;
  String? parentId;
  String notes;
  List<String> childrenIds;
  String? partnerId;    // ID pasangan (suami/istri)
  bool isPartnerNode;   // true = node ini hanya muncul di sisi pasangannya
  DateTime createdAt;
  DateTime updatedAt;

  FamilyMember({
    required this.id,
    required this.name,
    this.photoPath,
    this.parentId,
    this.notes = '',
    List<String>? childrenIds,
    this.partnerId,
    this.isPartnerNode = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : childrenIds = childrenIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  FamilyMember copyWith({
    String? name,
    String? photoPath,
    String? parentId,
    String? notes,
    List<String>? childrenIds,
    String? partnerId,
    bool? isPartnerNode,
    bool clearPartnerId = false,
  }) {
    return FamilyMember(
      id: id,
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      parentId: parentId ?? this.parentId,
      notes: notes ?? this.notes,
      childrenIds: childrenIds ?? List.from(this.childrenIds),
      partnerId: clearPartnerId ? null : (partnerId ?? this.partnerId),
      isPartnerNode: isPartnerNode ?? this.isPartnerNode,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'photoPath': photoPath,
        'parentId': parentId,
        'notes': notes,
        'childrenIds': childrenIds,
        'partnerId': partnerId,
        'isPartnerNode': isPartnerNode,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        id: json['id'],
        name: json['name'],
        photoPath: json['photoPath'],
        parentId: json['parentId'],
        notes: json['notes'] ?? '',
        childrenIds: List<String>.from(json['childrenIds'] ?? []),
        partnerId: json['partnerId'],
        isPartnerNode: json['isPartnerNode'] ?? false,
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );

  static String encodeList(List<FamilyMember> members) =>
      jsonEncode(members.map((m) => m.toJson()).toList());

  static List<FamilyMember> decodeList(String source) =>
      (jsonDecode(source) as List)
          .map((item) => FamilyMember.fromJson(item))
          .toList();
}