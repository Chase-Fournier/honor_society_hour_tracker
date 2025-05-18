// Helper method to normalize type strings for consistent matching
String normalizeType(String type) {
  // Convert to title case for consistent comparison
  return type
      .trim()
      .split(' ')
      .map((word) => word.isNotEmpty
          ? word[0].toUpperCase() +
              (word.length > 1 ? word.substring(1).toLowerCase() : '')
          : '')
      .join(' ');
}
