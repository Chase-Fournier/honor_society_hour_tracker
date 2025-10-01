import 'hourrequirement.dart';

class HonorSociety {
  final int id;
  final String name;
  final String description;
  final String? imageUrl;
  final List<HourRequirement> hourRequirements;
  final int meetingRequirement;
  final DateTime createdAt;
  final String? errorFormUrl;

  HonorSociety({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.hourRequirements,
    required this.meetingRequirement,
    required this.createdAt,
    this.errorFormUrl,
  });

  factory HonorSociety.fromJson(Map<String, dynamic> json) {
    return HonorSociety(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['image_url'],
      hourRequirements: (json['hour_requirements'] as List)
          .map((req) => HourRequirement.fromJson(req))
          .toList(),
      meetingRequirement: json['meeting_requirement'],
      createdAt: DateTime.parse(json['created_at']),
      errorFormUrl: json['error_form_url'],
    );
  }
}
