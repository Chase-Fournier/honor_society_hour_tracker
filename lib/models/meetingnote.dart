class MeetingNote {
  final int id;
  final String title;
  final String text;
  final DateTime createdAt;

  MeetingNote({
    required this.id,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  factory MeetingNote.fromJson(Map<String, dynamic> json) {
    return MeetingNote(
      id: json['id'],
      title: json['title'] ?? '',
      text: json['text'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
