import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/societyprovider.dart';
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
  // Early exit if no event type provided
  if (eventType.isEmpty) return 'workspaces';
  // Get the current society from provider
  final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
  if (society == null) {
    // Fallback if no society is available
    return _getDefaultIconNameForType(eventType);
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
  return _getDefaultIconNameForType(eventType);
}

IconData getIconForType(String type, BuildContext context) {
  final iconName = getIconNameForEventType(context, type);
 return getIconDataByName(iconName);
}

/// Helper function to get a default icon name based on event type
/// Used as fallback when no matching requirement is found
String _getDefaultIconNameForType(String eventType) {
  final lowerType = eventType.toLowerCase();
  
  if (lowerType.contains('service') || lowerType.contains('volunteer')) {
    return 'volunteer_activism';
  }
  if (lowerType.contains('tutor') || lowerType.contains('teach')) {
    return 'school';
  }
  if (lowerType.contains('meeting')) {
    return 'groups';
  }
  if (lowerType.contains('leader') || lowerType.contains('officer')) {
    return 'emoji_people';
  }
  if (lowerType.contains('fundrais') || lowerType.contains('donat')) {
    return 'attach_money';
  }
  if (lowerType.contains('communit')) {
    return 'public';
  }
  if (lowerType.contains('environment') || lowerType.contains('garden')) {
    return 'nature';
  }
  if (lowerType.contains('health') || lowerType.contains('medical')) {
    return 'health_and_safety';
  }
  if (lowerType.contains('tech') || lowerType.contains('computer')) {
    return 'computer';
  }
  if (lowerType.contains('art')) {
    return 'palette';
  }
  if (lowerType.contains('music')) {
    return 'music_note';
  }
  if (lowerType.contains('sport') || lowerType.contains('athletic')) {
    return 'sports';
  }
  if (lowerType.contains('research') || lowerType.contains('science')) {
    return 'science';
  }
  if (lowerType.contains('writing') || lowerType.contains('essay')) {
    return 'edit_note';
  }
  if (lowerType.contains('mentor')) {
    return 'psychology';
  }
  
  // Default icon if no match
  return 'workspaces';
}