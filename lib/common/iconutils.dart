import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/societyprovider.dart';
import '../models/honorsociety.dart';
import '../models/hourrequirement.dart';
import 'iconselector.dart';
import 'normalizetype.dart';

/// Gets the appropriate icon name for an event type based on society requirements
///
/// This function looks up the matching requirement in the honor society
/// and returns its configured icon name. Falls back to defaults if no match is found.
///
/// Parameters:
/// - context: BuildContext - Required for provider access
/// - eventType: String - The type of event to find an icon for
///
/// Returns:
/// - String - The icon name to use
String getIconNameForEventType(BuildContext context, String eventType) {
  final society =
      Provider.of<SocietyProvider>(context, listen: false).currentSociety;
  return iconNameForEventType(society, eventType);
}

/// [getIconNameForEventType] without the `BuildContext`.
///
/// Takes the society directly so the lookup can be exercised without a widget
/// tree or a Provider. The context-taking version above is a thin wrapper.
String iconNameForEventType(HonorSociety? society, String eventType) {
  // Early exit if no event type provided
  if (eventType.isEmpty) return 'workspaces';
  if (society == null) {
    // Fallback if no society is available
    return getDefaultIconNameForType(eventType);
  }

  // Special case for Meeting type (often doesn't have a requirement object)
  if (eventType.toLowerCase() == 'meeting') {
    // Check if there's a custom Meeting requirement first
    final meetingReq = society.hourRequirements.firstWhere(
      (req) => req.type.toLowerCase() == 'meeting',
      orElse: () => HourRequirement(
        id: -1,
        type: 'Meeting',
        hoursNeeded: 0,
        description: '',
        iconName: 'leadership', // Default meeting icon
      ),
    );
    return meetingReq.iconName;
  }

  // Find the requirement that matches this event type (case-insensitive)
  // Use normalizeType extension for consistent matching
  final normalizedEventType = normalizeType(eventType);

  // First try exact match
  for (final req in society.hourRequirements) {
    if (normalizeType(req.type) == normalizedEventType && req.isActive) {
      return req.iconName;
    }
  }

  // Try partial match if no exact match found
  for (final req in society.hourRequirements) {
    if (req.isActive &&
        (normalizedEventType.contains(normalizeType(req.type)) ||
            normalizeType(req.type).contains(normalizedEventType))) {
      return req.iconName;
    }
  }

  // No matching requirement found, fall back to default
  return getDefaultIconNameForType(eventType);
}

IconData getIconForType(String type, BuildContext context) {
  final iconName = getIconNameForEventType(context, type);
  return getIconDataByName(iconName);
}

/// Default icon name for an event type, matched by keyword.
///
/// Used as the fallback when the society has no requirement matching the type.
/// Returns a key from `_kAppIcons` in `iconselector.dart`. That matters: this
/// used to return raw Material icon names ('volunteer_activism', 'school',
/// 'groups', ...) while the icon map is keyed by semantic slugs ('volunteer',
/// 'tutoring', 'meeting', ...). Only 3 of the 16 outputs overlapped, so
/// [getIconDataByName] fell through to its `Icons.help_outline` fallback and
/// every event type without a configured society requirement rendered a
/// question mark.
///
/// Note the checks run in order and use `contains`, so an earlier keyword wins:
/// 'art' matches "Departmental", and "Community Service" resolves to 'volunteer'
/// because 'service' is checked before 'communit'.
String getDefaultIconNameForType(String eventType) {
  final lowerType = eventType.toLowerCase();

  if (lowerType.contains('service') || lowerType.contains('volunteer')) {
    return 'volunteer';
  }
  if (lowerType.contains('tutor') || lowerType.contains('teach')) {
    return 'tutoring';
  }
  if (lowerType.contains('meeting')) {
    return 'meeting';
  }
  if (lowerType.contains('leader') || lowerType.contains('officer')) {
    return 'leadership';
  }
  if (lowerType.contains('fundrais') || lowerType.contains('donat')) {
    return 'fundraising';
  }
  if (lowerType.contains('communit')) {
    return 'community';
  }
  if (lowerType.contains('environment') || lowerType.contains('garden')) {
    return 'environment';
  }
  if (lowerType.contains('health') || lowerType.contains('medical')) {
    return 'health';
  }
  if (lowerType.contains('tech') || lowerType.contains('computer')) {
    return 'tech';
  }
  if (lowerType.contains('art')) {
    return 'art';
  }
  if (lowerType.contains('music')) {
    return 'music';
  }
  if (lowerType.contains('sport') || lowerType.contains('athletic')) {
    return 'sports';
  }
  if (lowerType.contains('research') || lowerType.contains('science')) {
    return 'science';
  }
  if (lowerType.contains('writing') || lowerType.contains('essay')) {
    return 'writing';
  }
  if (lowerType.contains('mentor')) {
    return 'mentoring';
  }

  // Default icon if no match
  return 'workspaces';
}
