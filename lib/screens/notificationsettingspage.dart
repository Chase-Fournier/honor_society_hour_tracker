import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/app_design.dart';
import '../providers/hapticsprovider.dart';
import '../providers/notificationsprovider.dart';
import '../services/notification_service.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  static const _reminderChoices = <int>[15, 30, 60, 120, 1440];

  String _reminderLabel(int minutes) {
    if (minutes < 60) return '$minutes minutes before';
    if (minutes < 1440) {
      final hours = minutes ~/ 60;
      return '$hours hour${hours == 1 ? '' : 's'} before';
    }
    final days = minutes ~/ 1440;
    return '$days day${days == 1 ? '' : 's'} before';
  }

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationsProvider>();
    final haptics = context.read<HapticsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
      ),
      body: ListView(
        padding: AppDesign.paddingMedium,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: AppDesign.borderLarge,
            ),
            child: SwitchListTile(
              title: const Text('Enable Notifications'),
              subtitle: const Text(
                  'Allow Wheeler NHS to send reminders and updates.'),
              value: notifications.enabled,
              onChanged: (value) async {
                haptics.selection();
                final ok = await notifications.setEnabled(value);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Notification permission denied. Enable it in system settings.'),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          AbsorbPointer(
            absorbing: !notifications.enabled,
            child: Opacity(
              opacity: notifications.enabled ? 1.0 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppDesign.borderLarge,
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'What to notify me about',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        SwitchListTile(
                          title: const Text('Event reminders'),
                          subtitle:
                              const Text('Before time slots you signed up for'),
                          secondary: const Icon(Icons.event_available),
                          value: notifications.eventReminders,
                          onChanged: (v) {
                            haptics.selection();
                            notifications.setEventReminders(v);
                          },
                        ),
                        SwitchListTile(
                          title: const Text('New meeting notes'),
                          subtitle: const Text('When an admin posts notes'),
                          secondary: const Icon(Icons.sticky_note_2),
                          value: notifications.meetingNotes,
                          onChanged: (v) {
                            haptics.selection();
                            notifications.setMeetingNotes(v);
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Hours updated by admin'),
                          subtitle: const Text(
                              'Attendance marked or hours adjusted'),
                          secondary: const Icon(Icons.timer),
                          value: notifications.hourUpdates,
                          onChanged: (v) {
                            haptics.selection();
                            notifications.setHourUpdates(v);
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Swap requests'),
                          subtitle: const Text(
                              'When a swap involves you or you accept/decline'),
                          secondary: const Icon(Icons.swap_horiz),
                          value: notifications.swapRequests,
                          onChanged: (v) {
                            haptics.selection();
                            notifications.setSwapRequests(v);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppDesign.borderLarge,
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Event reminder timing',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final minutes in _reminderChoices)
                          RadioListTile<int>(
                            title: Text(_reminderLabel(minutes)),
                            value: minutes,
                            groupValue: notifications.reminderMinutesBefore,
                            onChanged: (v) {
                              if (v == null) return;
                              haptics.selection();
                              notifications.setReminderMinutesBefore(v);
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppDesign.borderLarge,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.send),
                      title: const Text('Send a test notification'),
                      subtitle: const Text(
                          'Useful to confirm everything is working.'),
                      onTap: () async {
                        haptics.selection();
                        await NotificationService.instance.showLocal(
                          id: 99999,
                          title: 'Test notification',
                          body: 'If you see this, notifications are working.',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
