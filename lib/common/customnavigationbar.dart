import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:circle_nav_bar/circle_nav_bar.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import '../providers/navigationprovider.dart';
import '../providers/hapticsprovider.dart';
import '../common/app_design.dart';

class NavigationTabData {
  final String title;
  final IconData icon;
  final String? shortText; // For circle nav bar

  NavigationTabData({
    required this.title,
    required this.icon,
    this.shortText,
  });
}

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
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, child) {
        switch (navigationProvider.navigationBarType) {
          case NavigationBarType.google:
            return _buildWithGoogleNavBar(context);
          case NavigationBarType.circle:
            return _buildWithCircleNavBar(context);
          case NavigationBarType.floating:
            return _buildWithFloatingNavBar(context);
        }
      },
    );
  }

  Widget _buildWithGoogleNavBar(BuildContext context) {
    return Scaffold(
      body: body,
      bottomNavigationBar: _buildGoogleNavBar(context),
    );
  }

  Widget _buildWithCircleNavBar(BuildContext context) {
    return Scaffold(
      body: body,
      bottomNavigationBar: _buildCircleNavBar(context),
    );
  }

  Widget _buildWithFloatingNavBar(BuildContext context) {
    return BottomBar(
      child: _buildFloatingNavContent(context),
      body: (context, controller) => body,
      hideOnScroll: true,
      scrollOpposite: false,
      width: MediaQuery.of(context).size.width * 0.85,
      barColor: Colors.transparent,
      borderRadius: BorderRadius.circular(AppDesign.radiusRound),
      duration: AppDesign.animationMedium,
      curve: Curves.easeInOutCubic,
      showIcon: false,
      offset: 16,
      barAlignment: Alignment.bottomCenter,
      barDecoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest.withOpacity(0.95),
        borderRadius: BorderRadius.circular(AppDesign.radiusRound),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }

   Widget _buildGoogleNavBar(BuildContext context) {
    final theme = Theme.of(context);
    
    // Admin users get smaller sizing
    final iconSize = isAdmin ? 20.0 : 24.0;
    final horizontalPadding = isAdmin ? AppDesign.spacingS : AppDesign.spacingM;
    final verticalPadding = isAdmin ? AppDesign.spacingS : AppDesign.spacingM;
    final tabHorizontalPadding = isAdmin ? AppDesign.spacingM : AppDesign.spacingL;
    final tabVerticalPadding = isAdmin ? AppDesign.spacingS : AppDesign.spacingM;
    final gap = isAdmin ? AppDesign.spacingXS : AppDesign.spacingS;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: GNav(
            selectedIndex: selectedIndex,
            onTabChange: (index) {
              final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              onTabChanged(index);
            },
            gap: gap,
            activeColor: theme.colorScheme.onPrimaryContainer,
            iconSize: iconSize,
            padding: EdgeInsets.symmetric(
              horizontal: tabHorizontalPadding,
              vertical: tabVerticalPadding,
            ),
            duration: AppDesign.animationMedium,
            tabBackgroundColor: theme.colorScheme.primaryContainer,
            color: theme.colorScheme.onSurfaceVariant,
            tabBorderRadius: 50, // More pill-shaped (circular)
            curve: Curves.easeInOutCubic,
            haptic: false, // We handle haptics ourselves
            tabs: tabs.map((tab) => GButton(
              icon: tab.icon,
              text: tab.title,
            )).toList(),
          ),
        ),
      ),
    );
  }


  Widget _buildCircleNavBar(BuildContext context) {
    final theme = Theme.of(context);
    
    return CircleNavBar(
      activeIcons: tabs.map((tab) => Icon(
        tab.icon,
        color: theme.colorScheme.onPrimary,
        size: 24,
      )).toList(),
      inactiveIcons: tabs.map((tab) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tab.icon,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(height: 2),
          Text(
            tab.shortText ?? tab.title,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      )).toList(),
      color: theme.colorScheme.surfaceContainerLowest,
      circleColor: theme.colorScheme.primary,
      height: 60,
      circleWidth: 60,
      activeIndex: selectedIndex,
      onTap: (index) {
        final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
        hapticsProvider.selection();
        onTabChanged(index);
      },
      padding: const EdgeInsets.only(
        left: AppDesign.spacingM,
        right: AppDesign.spacingM,
        bottom: AppDesign.spacingM,
      ),
      cornerRadius: BorderRadius.only(
        topLeft: Radius.circular(AppDesign.radiusSmall),
        topRight: Radius.circular(AppDesign.radiusSmall),
        bottomLeft: Radius.circular(AppDesign.radiusLarge),
        bottomRight: Radius.circular(AppDesign.radiusLarge),
      ),
      shadowColor: theme.colorScheme.shadow.withOpacity(0.05),
      circleShadowColor: theme.colorScheme.shadow.withOpacity(0.05),
      elevation: 5, // Reduced elevation
      // Removed gradients for flatter look
    );
  }

  Widget _buildFloatingNavContent(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppDesign.spacingXS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == selectedIndex;
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                onTabChanged(index);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesign.spacingS,
                  vertical: AppDesign.spacingS,
                ),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? theme.colorScheme.primaryContainer.withOpacity(0.8)
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      color: isSelected 
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tab.shortText ?? tab.title,
                      style: TextStyle(
                        color: isSelected 
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}