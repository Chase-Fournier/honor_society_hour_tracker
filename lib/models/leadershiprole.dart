class LeadershipRole {
  final int id;
  final String title;
  final String description;
  final String holderName;
  final String? email;
  final String? phone;
  final int societyId;
  final DateTime createdAt;
  final bool isActive;
  final int displayOrder;

  LeadershipRole({
    required this.id,
    required this.title,
    required this.description,
    required this.holderName,
    this.email,
    this.phone,
    required this.societyId,
    required this.createdAt,
    this.isActive = true,
    this.displayOrder = 0,
  });

  factory LeadershipRole.fromJson(Map<String, dynamic> json) {
    return LeadershipRole(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      holderName: json['holder_name'],
      email: json['email'],
      phone: json['phone'],
      societyId: json['society_id'],
      createdAt: DateTime.parse(json['created_at']),
      isActive: json['is_active'] ?? true,
      displayOrder: json['display_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'holder_name': holderName,
      'email': email,
      'phone': phone,
      'society_id': societyId,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
      'display_order': displayOrder,
    };
  }

  LeadershipRole copyWith({
    int? id,
    String? title,
    String? description,
    String? holderName,
    String? email,
    String? phone,
    int? societyId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    int? displayOrder,
  }) {
    return LeadershipRole(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      holderName: holderName ?? this.holderName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      societyId: societyId ?? this.societyId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }
}
