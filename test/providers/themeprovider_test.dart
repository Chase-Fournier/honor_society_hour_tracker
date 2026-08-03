import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/providers/hapticsprovider.dart';
import 'package:nhs_tracker/providers/notificationsprovider.dart';
import 'package:nhs_tracker/providers/themenotifier.dart';
import 'package:nhs_tracker/providers/themeprovider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(const {}));

  /// The constructor fires its own `loadThemePreference()` without exposing a
  /// handle on it. Awaiting our own call is not enough -- the constructor's can
  /// resolve afterwards and clobber whatever the test just set -- so drain the
  /// event loop too. Every provider in this app shares that constructor-side
  /// -effect pattern; see the same note in societyprovider_test.dart.
  Future<ThemeProvider> settled() async {
    final provider = ThemeProvider();
    await provider.loadThemePreference();
    await Future<void>.delayed(Duration.zero);
    return provider;
  }

  /// Same treatment for HapticsProvider, whose constructor also loads prefs.
  Future<HapticsProvider> settledHaptics() async {
    final provider = HapticsProvider();
    await Future<void>.delayed(Duration.zero);
    return provider;
  }

  group('theme metadata', () {
    // These are exhaustive switches over a 19-value enum; a new theme that
    // forgets a case would fall through to a default or throw.
    test('every theme has a non-empty name', () async {
      final provider = await settled();
      for (final mode in ThemeMode.values) {
        expect(provider.getThemeName(mode), isNotEmpty, reason: '$mode');
      }
    });

    test('every theme has a non-empty description', () async {
      final provider = await settled();
      for (final mode in ThemeMode.values) {
        expect(provider.getThemeDescription(mode), isNotEmpty, reason: '$mode');
      }
    });

    test('theme names are unique', () async {
      final provider = await settled();
      final names = ThemeMode.values.map(provider.getThemeName).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('every theme has an icon', () async {
      final provider = await settled();
      for (final mode in ThemeMode.values) {
        expect(provider.getThemeIcon(mode), isA<IconData>(), reason: '$mode');
      }
    });

    test('there are 19 themes', () {
      expect(ThemeMode.values, hasLength(19));
    });
  });

  group('getThemeData', () {
    test('builds a ThemeData for every theme without throwing', () async {
      final provider = await settled();
      for (final mode in ThemeMode.values) {
        provider.setThemeMode(mode);
        expect(provider.getThemeData(Colors.blue), isA<ThemeData>(),
            reason: '$mode');
      }
    });

    test('the seed colour drives the three base themes', () async {
      final provider = await settled();

      for (final mode in [
        ThemeMode.light,
        ThemeMode.dark,
        ThemeMode.midnight
      ]) {
        provider.setThemeMode(mode);
        final fromBlue = provider.getThemeData(Colors.blue).colorScheme;
        final fromRed = provider.getThemeData(Colors.red).colorScheme;
        expect(fromBlue.primary, isNot(fromRed.primary), reason: '$mode');
      }
    });

    // The named themes carry hard-coded ColorSchemes, so the user's seed colour
    // deliberately has no effect on them.
    test('the seed colour is ignored by the named themes', () async {
      final provider = await settled();
      provider.setThemeMode(ThemeMode.galaxy);

      expect(
        provider.getThemeData(Colors.blue).colorScheme.primary,
        provider.getThemeData(Colors.red).colorScheme.primary,
      );
    });

    test('light and dark produce different brightness', () async {
      final provider = await settled();

      provider.setThemeMode(ThemeMode.light);
      final light = provider.getThemeData(Colors.blue);
      provider.setThemeMode(ThemeMode.dark);
      final dark = provider.getThemeData(Colors.blue);

      expect(light.colorScheme.brightness, Brightness.light);
      expect(dark.colorScheme.brightness, Brightness.dark);
    });
  });

  group('mode getters', () {
    test('classify the three base themes', () async {
      final provider = await settled();

      provider.setThemeMode(ThemeMode.light);
      expect(provider.isLightMode, isTrue);
      expect(provider.isCustomTheme, isFalse);

      provider.setThemeMode(ThemeMode.dark);
      expect(provider.isDarkMode, isTrue);
      expect(provider.isCustomTheme, isFalse);

      provider.setThemeMode(ThemeMode.midnight);
      expect(provider.isMidnightMode, isTrue);
      expect(provider.isCustomTheme, isFalse);
    });

    test('every other theme counts as custom', () async {
      final provider = await settled();
      const base = {ThemeMode.light, ThemeMode.dark, ThemeMode.midnight};

      for (final mode in ThemeMode.values.where((m) => !base.contains(m))) {
        provider.setThemeMode(mode);
        expect(provider.isCustomTheme, isTrue, reason: '$mode');
      }
    });
  });

  group('persistence', () {
    test('defaults to light with no stored preference', () async {
      expect((await settled()).themeMode, ThemeMode.light);
    });

    test('restores a stored theme', () async {
      SharedPreferences.setMockInitialValues(
          {'themeMode': ThemeMode.forest.index});
      expect((await settled()).themeMode, ThemeMode.forest);
    });

    test('setThemeMode writes the index', () async {
      final provider = await settled();
      provider.setThemeMode(ThemeMode.ocean);
      await provider.saveThemePreference();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('themeMode'), ThemeMode.ocean.index);
    });

    // Guards against a stored index left behind by a build that had more
    // themes than the current one.
    test('falls back to light for an out-of-range stored index', () async {
      SharedPreferences.setMockInitialValues({'themeMode': 999});
      expect((await settled()).themeMode, ThemeMode.light);
    });

    test('notifies listeners on change', () async {
      final provider = await settled();
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.setThemeMode(ThemeMode.ruby);

      expect(notifications, 1);
      expect(provider.themeMode, ThemeMode.ruby);
    });
  });

  group('other providers', () {
    test('ThemeNotifier holds and updates its colour', () {
      final notifier = ThemeNotifier();
      var notifications = 0;
      notifier.addListener(() => notifications++);

      notifier.updateThemeColor(Colors.teal);

      expect(notifier.themeColor, Colors.teal);
      expect(notifications, 1);
    });

    test('HapticsProvider defaults to enabled and toggles', () async {
      final provider = await settledHaptics();
      expect(provider.isHapticsEnabled, isTrue);
      await provider.toggleHaptics(false);
      expect(provider.isHapticsEnabled, isFalse);

      await provider.toggleHaptics(true);
      expect(provider.isHapticsEnabled, isTrue);
    });

    test('HapticsProvider persists the toggle', () async {
      final provider = await settledHaptics();
      await provider.toggleHaptics(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('haptics_enabled'), isFalse);
    });

    test('haptic calls are safe no-ops in tests', () async {
      // Note the gate does NOT close under flutter_test: defaultTargetPlatform
      // is android there, so gaimon's MethodChannel really is invoked and would
      // throw MissingPluginException. It stays quiet only because
      // test/flutter_test_config.dart stubs that channel for the whole suite.
      final provider = await settledHaptics();
      expect(() {
        provider.selection();
        provider.success();
        provider.error();
        provider.warning();
        provider.light();
        provider.medium();
        provider.heavy();
      }, returnsNormally);
    });

    group('NotificationsProvider.shouldScheduleFor', () {
      /// The master switch defaults to false, and flipping it via setEnabled()
      /// calls into NotificationService for permissions and push registration.
      /// Seeding the pref directly exercises the category logic on its own.
      Future<NotificationsProvider> enabledProvider(
          [Map<String, Object> extra = const {}]) async {
        SharedPreferences.setMockInitialValues(
            {'notif_enabled': true, ...extra});
        final provider = NotificationsProvider();
        await Future<void>.delayed(Duration.zero);
        return provider;
      }

      test('the master switch vetoes every category', () async {
        SharedPreferences.setMockInitialValues(const {'notif_enabled': false});
        final provider = NotificationsProvider();
        await Future<void>.delayed(Duration.zero);

        for (final category in ['event', 'meeting_notes', 'hours', 'swap']) {
          expect(provider.shouldScheduleFor(category), isFalse,
              reason: category);
        }
      });

      test('each category defaults to on once enabled', () async {
        final provider = await enabledProvider();

        expect(provider.shouldScheduleFor('event'), isTrue);
        expect(provider.shouldScheduleFor('meeting_notes'), isTrue);
        expect(provider.shouldScheduleFor('hours'), isTrue);
        expect(provider.shouldScheduleFor('swap'), isTrue);
      });

      test('turning one category off leaves the others alone', () async {
        final provider = await enabledProvider();
        await provider.setEventReminders(false);

        expect(provider.shouldScheduleFor('event'), isFalse);
        expect(provider.shouldScheduleFor('meeting_notes'), isTrue);
      });

      test('a stored category preference is honoured', () async {
        final provider = await enabledProvider({'notif_swap_requests': false});
        expect(provider.shouldScheduleFor('swap'), isFalse);
      });

      // An unrecognised category falls through to the default branch and is
      // allowed, so a new notification type ships enabled rather than silent.
      test('an unknown category is allowed through', () async {
        final provider = await enabledProvider();
        expect(provider.shouldScheduleFor('something_new'), isTrue);
      });

      test('reminder lead time round-trips', () async {
        final provider = await enabledProvider();
        expect(provider.reminderMinutesBefore, 60);

        await provider.setReminderMinutesBefore(30);
        expect(provider.reminderMinutesBefore, 30);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('notif_reminder_minutes'), 30);
      });
    });
  });
}
