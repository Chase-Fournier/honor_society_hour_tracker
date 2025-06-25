class MeetingNote {
  final int id;
  final String title;
  final String text;
  final String? content; // Add this field
  final DateTime createdAt;

  MeetingNote({
    required this.id,
    required this.title,
    required this.text,
    this.content, // Add this parameter
    required this.createdAt,
  });

  factory MeetingNote.fromJson(Map<String, dynamic> json) {
    return MeetingNote(
      id: json['id'],
      title: json['title'] ?? '',
      text: json['text'] ?? '',
      content: json['content'], // Add this line
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}