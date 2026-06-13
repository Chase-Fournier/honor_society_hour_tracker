import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hapticsprovider.dart';
import 'app_design.dart';

class NavigationTabData {
  final String title;
  final IconData icon;
  final String? shortText; // Shown as the pill label when selected

  NavigationTabData({
    required this.title,
    required this.icon,
    this.shortText,
  });
}

/// A single, custom bottom navigation bar.
///
/// Replaces the previous swappable (google / circle / floating) variants with
/// one design: a flat surface bar whose selected tab animates into a pill that
/// reveals its label. The label width and the pill background animate smoothly,
/// so neighbouring tabs slide as the selection moves.
class CustomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChanged;
  final List<NavigationTabData> tabs;
  final Widget body;
  final bool isAdmin;

  const CustomNavigationBar({
    Key? key,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.tabs,
    required this.body,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: body,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppDesign.spacingS,
              vertical: isAdmin ? AppDesign.spacingXS : AppDesign.spacingS,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final tab = entry.value;
                return _NavBarItem(
                  tab: tab,
                  isSelected: index == selectedIndex,
                  isAdmin: isAdmin,
                  onTap: () {
                    if (index == selectedIndex) return;
                    Provider.of<HapticsProvider>(context, listen: false)
                        .selection();
                    onTabChanged(index);
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final NavigationTabData tab;
  final bool isSelected;
  final bool isAdmin;
  final VoidCallback onTap;

  const _NavBarItem({
    Key? key,
    required this.tab,
    required this.isSelected,
    required this.isAdmin,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final double iconSize = isAdmin ? 22 : 24;
    final double labelSize = isAdmin ? 12 : 13;
    final EdgeInsets pillPadding = EdgeInsets.symmetric(
      horizontal: isAdmin ? AppDesign.spacingM - 2 : AppDesign.spacingM,
      vertical: isAdmin ? AppDesign.spacingS : AppDesign.spacingS + 2,
    );

    final Color foreground =
        isSelected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDesign.animationMedium,
        curve: Curves.easeInOutCubic,
        padding: pillPadding,
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDesign.radiusRound),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon colour cross-fades for a smooth selected/unselected swap.
            TweenAnimationBuilder<double>(
              duration: AppDesign.animationMedium,
              curve: Curves.easeInOutCubic,
              tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
              builder: (context, t, _) {
                return Icon(
                  tab.icon,
                  size: iconSize,
                  color: Color.lerp(
                    scheme.onSurfaceVariant,
                    scheme.onPrimaryContainer,
                    t,
                  ),
                );
              },
            ),
            // The label only exists when selected; AnimatedSize tweens its
            // width in/out so the pill grows and shrinks smoothly.
            ClipRect(
              child: AnimatedSize(
                duration: AppDesign.animationMedium,
                curve: Curves.easeInOutCubic,
                child: isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: AppDesign.spacingS),
                        child: Text(
                          tab.shortText ?? tab.title,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: TextStyle(
                            color: foreground,
                            fontSize: labelSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
