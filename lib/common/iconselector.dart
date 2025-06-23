import 'package:flutter/material.dart';
import 'app_design.dart';
import 'package:provider/provider.dart';
import '../providers/hapticsprovider.dart';

class IconSelector extends StatefulWidget {
  final String initialValue; // The initial icon name (e.g., 'service')
  final ValueChanged<String> onChanged; // Callback when icon changes

  const IconSelector({
    Key? key,
    required this.initialValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  _IconSelectorState createState() => _IconSelectorState();
}

class _IconSelectorState extends State<IconSelector> {
  late String _selectedIconName;

  @override
  void initState() {
    super.initState();
    _selectedIconName = widget.initialValue;
    // Ensure the initial value exists in our map, otherwise use default
    if (!_kAppIcons.containsKey(_selectedIconName)) {
      _selectedIconName = 'default';
    }
  }

  // Function to show the icon selection bottom sheet
  void _showIconSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        // Optional: nice rounded corners
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDesign.radiusLarge)),
      ),
      builder: (sheetContext) {
        // Use a GridView to display icons
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _kAppIcons.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, // Adjust column count as needed
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final iconName = _kAppIcons.keys.elementAt(index);
            final iconData = _kAppIcons.values.elementAt(index);
            final isSelected = iconName == _selectedIconName;

            return InkWell(
              onTap: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                // Update state and call callback
                setState(() {
                  _selectedIconName = iconName;
                });
                widget.onChanged(_selectedIconName);
                Navigator.pop(sheetContext); // Close the bottom sheet
              },
              borderRadius: AppDesign.borderSmall,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColorLight.withOpacity(0.3)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: AppDesign.borderSmall,
                ),
                child: Tooltip(
                  message: iconName, // Show name on hover/long press
                  child: Icon(
                    iconData,
                    size: 30,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).iconTheme.color,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Display the currently selected icon and a button to change it
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Icon',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: InkWell(
        // Use InkWell for tap feedback
        onTap: () {
          final hapticsProvider =
              Provider.of<HapticsProvider>(context, listen: false);
          hapticsProvider.selection();
          _showIconSelectionSheet(context);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(getIconDataByName(_selectedIconName)),
                const SizedBox(width: 12),
                Text(_selectedIconName),
              ],
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey), // Indicator
          ],
        ),
      ),
    );
  }
}

const Map<String, IconData> _kAppIcons = {
  // Original Icons
  'work': Icons.work_outline,
  'service': Icons.volunteer_activism_outlined,
  'tutoring': Icons.school_outlined,
  'leadership': Icons.group_outlined,
  'event': Icons.event_outlined,
  'meeting': Icons.groups_outlined,
  'fundraising': Icons.monetization_on_outlined,
  'sports': Icons.sports_soccer_outlined,
  'art': Icons.palette_outlined,
  'music': Icons.music_note_outlined,

  // Added Icons
  'science': Icons.science_outlined,
  'tech': Icons.computer_outlined,
  'environment': Icons.eco_outlined,
  'health': Icons.local_hospital_outlined,
  'community': Icons.people_alt_outlined,
  'culture': Icons.museum_outlined,
  'writing': Icons.edit_note_outlined,
  'reading': Icons.menu_book_outlined,
  'debate': Icons.record_voice_over_outlined,
  'chess': Icons.grid_view_outlined, // Using grid icon as placeholder
  'robotics': Icons.precision_manufacturing_outlined,
  'gardening': Icons.yard_outlined,
  'cooking': Icons.soup_kitchen_outlined,
  'construction': Icons.construction_outlined,
  'photography': Icons.camera_alt_outlined,
  'film': Icons.movie_outlined,
  'volunteer': Icons.volunteer_activism, // Filled version for emphasis
  'charity': Icons.favorite_border_outlined,
  'mentoring': Icons.supervisor_account_outlined,
  'research': Icons.biotech_outlined,
  'travel': Icons.explore_outlined,
  'language': Icons.translate_outlined,
  'code': Icons.code_outlined,
  'design': Icons.design_services_outlined,
  'agriculture': Icons.agriculture_outlined,
  'workspaces': Icons.workspaces,

  // Default/Fallback
  'default': Icons.help_outline,
};

// Helper function to get IconData from name, with a fallback
IconData getIconDataByName(String? name) {
  return _kAppIcons[name] ?? _kAppIcons['default']!;
}
