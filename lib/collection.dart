class Collection {
  final int id;
  final String name;
  final List<String> eventIds;
  bool rendered;

  Collection({
    required this.id,
    required this.name,
    required this.eventIds,
    this.rendered = false,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'],
      name: json['name'],
      eventIds: json['event_ids'] is List<dynamic>
          ? List<String>.from(json['event_ids'])
          : [],
    );
  }
}
