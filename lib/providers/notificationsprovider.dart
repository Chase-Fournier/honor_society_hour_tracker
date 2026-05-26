import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class NotificationsProvider extends ChangeNotifier {
  static const _kEnabled = 'notif_enabled';
  static const _kEventReminders = 'notif_event_reminders';
  static const _kMeetingNotes = 'notif_meeting_notes';
  static const _kHourUpdates = 'notif_hour_updates';
  static const _kSwapRequests = 'notif_swap_requests';
  static const _kReminderMinutes = 'notif_reminder_minutes';

  bool _enabled = false;
  bool _eventReminders = true;
  bool _meetingNotes = true;
  bool _hourUpdates = true;
  bool _swapRequests = true;
  int _reminderMinutesBefore = 60;

  bool get enabled => _enabled;
  bool get eventReminders => _eventReminders;
  bool get meetingNotes => _meetingNotes;
  bool get hourUpdates => _hourUpdates;
  bool get swapRequests => _swapRequests;
  int get reminderMinutesBefore => _reminderMinutesBefore;

  NotificationsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabled) ?? false;
    _eventReminders = prefs.getBool(_kEventReminders) ?? true;
    _meetingNotes = prefs.getBool(_kMeetingNotes) ?? true;
    _hourUpdates = prefs.getBool(_kHourUpdates) ?? true;
    _swapRequests = prefs.getBool(_kSwapRequests) ?? true;
    _reminderMinutesBefore = prefs.getInt(_kReminderMinutes) ?? 60;
    notifyListeners();
  }

  Future<bool> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        _enabled = false;
        await prefs.setBool(_kEnabled, false);
        notifyListeners();
        return false;
      }
      await NotificationService.instance.registerForPush();
    } else {
      await NotificationService.instance.unregisterDevice();
      await NotificationService.instance.cancelAll();
    }
    _enabled = value;
    await prefs.setBool(_kEnabled, value);
    notifyListeners();
    return true;
  }

  Future<void> setEventReminders(bool value) async {
    _eventReminders = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEventReminders, value);
    notifyListeners();
  }

  Future<void> setMeetingNotes(bool value) async {
    _meetingNotes = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMeetingNotes, value);
    notifyListeners();
  }

  Future<void> setHourUpdates(bool value) async {
    _hourUpdates = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHourUpdates, value);
    notifyListeners();
  }

  Future<void> setSwapRequests(bool value) async {
    _swapRequests = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSwapRequests, value);
    notifyListeners();
  }

  Future<void> setReminderMinutesBefore(int minutes) async {
    _reminderMinutesBefore = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kReminderMinutes, minutes);
    notifyListeners();
  }

  bool shouldScheduleFor(String category) {
    if (!_enabled) return false;
    switch (category) {
      case 'event':
        return _eventReminders;
      case 'meeting_notes':
        return _meetingNotes;
      case 'hours':
        return _hourUpdates;
      case 'swap':
        return _swapRequests;
      default:
        return true;
    }
  }
}
