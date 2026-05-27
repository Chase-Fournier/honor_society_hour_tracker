class ContinuousEventStep {
  final int order;
  final String description;
  final String? link;

  ContinuousEventStep({
    required this.order,
    required this.description,
    this.link,
  });

  factory ContinuousEventStep.fromJson(Map<String, dynamic> json) {
    return ContinuousEventStep(
      order: (json['order'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      link: (json['link'] as String?)?.trim().isEmpty == true
          ? null
          : json['link'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'description': description,
      if (link != null && link!.isNotEmpty) 'link': link,
    };
  }

  ContinuousEventStep copyWith({int? order, String? description, String? link}) {
    return ContinuousEventStep(
      order: order ?? this.order,
      description: description ?? this.description,
      link: link ?? this.link,
    );
  }
}
