import 'package:flutter/material.dart';
import 'app_design.dart';
import 'iconutils.dart';

/// Completed + potential hours bar for one requirement type.
/// Pure: all inputs are parameters. Extracted from HomePage.
Widget buildDoubleProgressBar(BuildContext context, String title,
    double completedHours, double potentialHours, int hoursNeeded) {
  final isComplete = completedHours >= hoursNeeded;

  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: AppDesign.borderMedium),
    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Padding(
      padding: AppDesign.paddingSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title with icon
              Row(
                children: [
                  Icon(
                    getIconForType(title, context),
                    size: 18,
                    color: isComplete
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$title',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              // Hours text more compact
              Text(
                '${completedHours.toStringAsFixed(1)} / $hoursNeeded',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isComplete
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress bars with animation
          Stack(
            children: [
              // Background track
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppDesign.borderSmall,
                ),
              ),

              // Potential hours progress
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeInOut,
                tween: Tween<double>(
                  begin: 0,
                  end: (potentialHours / hoursNeeded).clamp(0.0, 1.0),
                ),
                builder: (context, potentialValue, _) {
                  return FractionallySizedBox(
                    widthFactor: potentialValue,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        borderRadius: AppDesign.borderSmall,
                      ),
                    ),
                  );
                },
              ),

              // Completed hours progress
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutQuart,
                tween: Tween<double>(
                  begin: 0,
                  end: (completedHours / hoursNeeded).clamp(0.0, 1.0),
                ),
                builder: (context, completedValue, _) {
                  return FractionallySizedBox(
                    widthFactor: completedValue,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: isComplete
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.8),
                        borderRadius: AppDesign.borderSmall,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          // Only show this info if there's additional potential hours
          if (potentialHours > completedHours)
            Padding(
              padding: AppDesign.paddingSmall,
              child: Row(
                children: [
                  Icon(
                    Icons.upcoming,
                    size: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.7),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Potential: ${potentialHours.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                    ),
                  ),
                  if (isComplete)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Complete',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// Meeting-attendance progress bar.
/// `meetingsLeft` is passed in (originally derived from the events list).
Widget buildMeetingProgressBar(BuildContext context, double completedHours,
    int hoursNeeded, {required int meetingsLeft}) {
  final meetingsAttended = completedHours.floor();
  final isComplete = meetingsAttended >= hoursNeeded;

  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: AppDesign.borderMedium),
    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Padding(
      padding: AppDesign.paddingSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title with icon
              Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    size: 18,
                    color: isComplete
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Meetings',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              // Meetings text
              Text(
                '$meetingsAttended / $hoursNeeded',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isComplete
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress bar with animation
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutQuart,
            tween: Tween<double>(
              begin: 0,
              end: (meetingsAttended / hoursNeeded).clamp(0.0, 1.0),
            ),
            builder: (context, value, _) {
              return Stack(
                children: [
                  // Background track
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: AppDesign.borderSmall,
                    ),
                  ),

                  // Progress
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: isComplete
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context)
                                .colorScheme
                                .tertiary
                                .withOpacity(0.8),
                        borderRadius: AppDesign.borderSmall,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          if (meetingsLeft > 0)
            Padding(
              padding: AppDesign.paddingSmall,
              child: Row(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.7),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Upcoming: $meetingsLeft',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                    ),
                  ),
                  if (isComplete)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 12,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Complete',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.tertiary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
