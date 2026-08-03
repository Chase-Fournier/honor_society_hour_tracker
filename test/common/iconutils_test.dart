import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/common/iconselector.dart';
import 'package:nhs_tracker/common/iconutils.dart';
import 'package:nhs_tracker/logic/notification_routing.dart';

import '../helpers/fixtures.dart';

void main() {
  group('iconNameForEventType', () {
    test('falls back for an empty type', () {
      expect(iconNameForEventType(honorSociety(), ''), 'workspaces');
    });

    test('uses keyword defaults when there is no society', () {
      expect(iconNameForEventType(null, 'Community Service'), 'volunteer');
    });

    test('prefers an exact requirement match', () {
      final society = honorSociety(hourRequirements: [
        hourRequirement(type: 'Service', iconName: 'recycling'),
      ]);
      expect(iconNameForEventType(society, 'Service'), 'recycling');
    });

    test('matches a requirement case- and spacing-insensitively', () {
      final society = honorSociety(hourRequirements: [
        hourRequirement(type: 'community service', iconName: 'recycling'),
      ]);
      expect(iconNameForEventType(society, 'COMMUNITY SERVICE'), 'recycling');
    });

    test('ignores inactive requirements', () {
      final society = honorSociety(hourRequirements: [
        hourRequirement(
            type: 'Service', iconName: 'recycling', isActive: false),
      ]);
      // Falls through to the keyword default rather than using the disabled one.
      expect(iconNameForEventType(society, 'Service'), 'volunteer');
    });

    test('falls back to a partial match', () {
      final society = honorSociety(hourRequirements: [
        hourRequirement(type: 'Service', iconName: 'recycling'),
      ]);
      expect(iconNameForEventType(society, 'Service Project'), 'recycling');
    });

    test('uses the society meeting requirement icon when there is one', () {
      final society = honorSociety(hourRequirements: [
        hourRequirement(type: 'Meeting', iconName: 'forum'),
      ]);
      expect(iconNameForEventType(society, 'Meeting'), 'forum');
    });

    test('meetings get a sensible icon even with no requirement', () {
      final society = honorSociety(hourRequirements: []);
      final name = iconNameForEventType(society, 'Meeting');

      expect(name, 'leadership');
      expect(getIconDataByName(name),
          isNot(getIconDataByName('definitely-not-an-icon')));
    });

    test('an unmatched type falls through to the keyword defaults', () {
      final society = honorSociety(hourRequirements: [
        hourRequirement(type: 'Service', iconName: 'recycling'),
      ]);
      expect(iconNameForEventType(society, 'Music Recital'), 'music');
    });
  });

  group('getDefaultIconNameForType', () {
    test('maps each keyword family', () {
      const cases = {
        'Volunteer Day': 'volunteer',
        'Tutoring': 'tutoring',
        'Chapter Meeting': 'meeting',
        'Officer Duty': 'leadership',
        'Fundraiser': 'fundraising',
        'Community Outreach': 'community',
        'Environment Cleanup': 'environment',
        'Health Fair': 'health',
        'Tech Support': 'tech',
        'Music Recital': 'music',
        'Sports Day': 'sports',
        'Research Project': 'science',
        'Essay Writing': 'writing',
        'Mentorship': 'mentoring',
      };

      cases.forEach((type, expected) {
        expect(getDefaultIconNameForType(type), expected, reason: type);
      });
    });

    test('is case-insensitive', () {
      expect(getDefaultIconNameForType('TUTORING'), 'tutoring');
    });

    test('anything unrecognised gets the generic icon', () {
      expect(getDefaultIconNameForType('Bake Sale Setup'), 'workspaces');
      expect(getDefaultIconNameForType(''), 'workspaces');
    });

    // The checks are ordered `contains` tests, so a short keyword can capture
    // an unrelated word. Pinned because it looks like a bug at a glance and
    // reordering the cascade would change real icons.
    test('a short keyword can capture an unrelated word', () {
      expect(getDefaultIconNameForType('Departmental'), 'art');
    });

    test('an earlier keyword wins over a later one', () {
      // 'service' is checked before 'communit'.
      expect(getDefaultIconNameForType('Community Service'), 'volunteer');
      // 'communit' is checked before 'art'.
      expect(getDefaultIconNameForType('Community Art'), 'community');
    });
  });

  group('getIconDataByName', () {
    test('resolves a known name', () {
      expect(getIconDataByName('school'), isA<IconData>());
    });

    test('falls back for null and unknown names', () {
      expect(getIconDataByName(null), getIconDataByName('nope'));
      expect(getIconDataByName('nope'), isA<IconData>());
    });

    test('every default icon name resolves to a real icon', () {
      // Guards against getDefaultIconNameForType returning a name the icon map
      // does not know, which would silently render the fallback glyph.
      // Regression: this cascade used to return raw Material icon names while
      // the icon map is keyed by semantic slugs, so 13 of these 16 fell through
      // to the question-mark fallback in the real UI.
      const types = [
        'Volunteer Day',
        'Tutoring',
        'Chapter Meeting',
        'Officer Duty',
        'Fundraiser',
        'Community Outreach',
        'Environment Cleanup',
        'Health Fair',
        'Tech Support',
        'Music Recital',
        'Sports Day',
        'Research Project',
        'Essay Writing',
        'Mentorship',
        'Bake Sale',
      ];
      final fallback = getIconDataByName('definitely-not-an-icon');

      for (final type in types) {
        final name = getDefaultIconNameForType(type);
        expect(getIconDataByName(name), isNot(fallback),
            reason: '$type -> "$name" is not a key in the icon map');
      }
    });
  });

  group('tabForNotificationType', () {
    test('routes each type for an admin', () {
      expect(tabForNotificationType('event', isAdmin: true), 1);
      expect(tabForNotificationType('meeting_notes', isAdmin: true), 0);
      expect(tabForNotificationType('hours', isAdmin: true), 2);
      expect(tabForNotificationType('swap', isAdmin: true), 2);
      expect(tabForNotificationType('continuous_submission', isAdmin: true), 0);
    });

    test('routes each type for a member', () {
      expect(tabForNotificationType('event', isAdmin: false), 0);
      expect(tabForNotificationType('meeting_notes', isAdmin: false), 0);
      expect(tabForNotificationType('hours', isAdmin: false), 1);
      expect(tabForNotificationType('swap', isAdmin: false), 0);
      expect(
          tabForNotificationType('continuous_submission', isAdmin: false), 1);
    });

    test('an unknown or absent type means stay put', () {
      expect(tabForNotificationType(null, isAdmin: true), isNull);
      expect(tabForNotificationType('something_new', isAdmin: false), isNull);
      expect(tabForNotificationType('', isAdmin: false), isNull);
    });

    test('every target index is valid for its shell', () {
      const types = [
        'event',
        'meeting_notes',
        'hours',
        'swap',
        'continuous_submission',
      ];

      for (final type in types) {
        expect(tabForNotificationType(type, isAdmin: true),
            lessThan(kAdminTabCount),
            reason: '$type (admin)');
        expect(tabForNotificationType(type, isAdmin: false),
            lessThan(kMemberTabCount),
            reason: '$type (member)');
      }
    });
  });
}
