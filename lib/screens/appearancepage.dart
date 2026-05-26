import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../common/app_design.dart';
import '../providers/themeprovider.dart' as themeprovider;
import '../providers/themenotifier.dart';
import '../providers/hapticsprovider.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  static const List<themeprovider.ThemeMode> _customThemes = [
    themeprovider.ThemeMode.sunset,
    themeprovider.ThemeMode.sunrise,
    themeprovider.ThemeMode.fullMoon,
    themeprovider.ThemeMode.forest,
    themeprovider.ThemeMode.ocean,
    themeprovider.ThemeMode.reef,
    themeprovider.ThemeMode.cherry,
    themeprovider.ThemeMode.lavender,
    themeprovider.ThemeMode.autumn,
    themeprovider.ThemeMode.winter,
    themeprovider.ThemeMode.desert,
    themeprovider.ThemeMode.galaxy,
    themeprovider.ThemeMode.emerald,
    themeprovider.ThemeMode.ruby,
    themeprovider.ThemeMode.sapphire,
    themeprovider.ThemeMode.amber,
  ];

  Color _selectedColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadSelectedColor();
  }

  Future<void> _loadSelectedColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('themeColor');
    if (!mounted) return;
    setState(() {
      _selectedColor = colorValue != null ? Color(colorValue) : Colors.blue;
    });
  }

  Future<void> _handleColorChange(Color color) async {
    setState(() => _selectedColor = color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColor', color.value);
    if (!mounted) return;
    Provider.of<ThemeNotifier>(context, listen: false).updateThemeColor(color);
  }

  // Three representative colors per named theme (primary, secondary, tertiary)
  List<Color> _themeSwatch(themeprovider.ThemeMode theme) {
    switch (theme) {
      case themeprovider.ThemeMode.sunset:
        return const [Color(0xFFFF6B35), Color(0xFFE91E63), Color(0xFFFF9800)];
      case themeprovider.ThemeMode.sunrise:
        return const [Color(0xFFFFB74D), Color(0xFFFF8A65), Color(0xFFFFD54F)];
      case themeprovider.ThemeMode.fullMoon:
        return const [Color(0xFF90CAF9), Color(0xFFB39DDB), Color(0xFF81D4FA)];
      case themeprovider.ThemeMode.forest:
        return const [Color(0xFF2E7D32), Color(0xFF388E3C), Color(0xFF689F38)];
      case themeprovider.ThemeMode.ocean:
        return const [Color(0xFF0277BD), Color(0xFF00ACC1), Color(0xFF0288D1)];
      case themeprovider.ThemeMode.reef:
        return const [Color(0xFFFF7043), Color(0xFF26A69A), Color(0xFFAB47BC)];
      case themeprovider.ThemeMode.cherry:
        return const [Color(0xFFE91E63), Color(0xFFF06292), Color(0xFFFFB3BA)];
      case themeprovider.ThemeMode.lavender:
        return const [Color(0xFF9C27B0), Color(0xFFBA68C8), Color(0xFFCE93D8)];
      case themeprovider.ThemeMode.autumn:
        return const [Color(0xFFD84315), Color(0xFFFF8F00), Color(0xFFFFB300)];
      case themeprovider.ThemeMode.winter:
        return const [Color(0xFF1976D2), Color(0xFF42A5F5), Color(0xFF81D4FA)];
      case themeprovider.ThemeMode.desert:
        return const [Color(0xFF8D6E63), Color(0xFFBCAAA4), Color(0xFFA1887F)];
      case themeprovider.ThemeMode.galaxy:
        return const [Color(0xFF7C4DFF), Color(0xFF448AFF), Color(0xFF18FFFF)];
      case themeprovider.ThemeMode.emerald:
        return const [Color(0xFF00695C), Color(0xFF26A69A), Color(0xFF4DB6AC)];
      case themeprovider.ThemeMode.ruby:
        return const [Color(0xFFC62828), Color(0xFFD32F2F), Color(0xFFE57373)];
      case themeprovider.ThemeMode.sapphire:
        return const [Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF42A5F5)];
      case themeprovider.ThemeMode.amber:
        return const [Color(0xFFFF8F00), Color(0xFFFFB300), Color(0xFFFFD54F)];
      default:
        final scheme = Theme.of(context).colorScheme;
        return [scheme.primary, scheme.secondary, scheme.tertiary];
    }
  }

  void _setMode(themeprovider.ThemeMode mode) {
    Provider.of<HapticsProvider>(context, listen: false).selection();
    Provider.of<themeprovider.ThemeProvider>(context, listen: false)
        .setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<themeprovider.ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
      ),
      body: ListView(
        padding: AppDesign.paddingMedium,
        children: [
          _sectionTitle(context, 'Mode & Color'),
          _modeSegmentedControl(themeProvider),
          const SizedBox(height: AppDesign.spacingS),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: AppDesign.borderLarge,
              side: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: AppDesign.borderLarge),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
              ),
              title: const Text('Color'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openColorPicker,
            ),
          ),
          const SizedBox(height: AppDesign.spacingL),

          _sectionTitle(context, 'Premade Themes'),
          ..._customThemes.map((theme) {
            final isSelected = themeProvider.themeMode == theme;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDesign.spacingS),
              child: _themeTile(themeProvider, theme, isSelected),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _modeSegmentedControl(themeprovider.ThemeProvider themeProvider) {
    return Row(
      children: [
        Expanded(
          child: _modeSegment(
              themeProvider, themeprovider.ThemeMode.light, 'Light'),
        ),
        const SizedBox(width: AppDesign.spacingS),
        Expanded(
          child: _modeSegment(
              themeProvider, themeprovider.ThemeMode.dark, 'Dark'),
        ),
        const SizedBox(width: AppDesign.spacingS),
        Expanded(
          child: _modeSegment(themeProvider,
              themeprovider.ThemeMode.midnight, 'Midnight'),
        ),
      ],
    );
  }

  Widget _modeSegment(
    themeprovider.ThemeProvider themeProvider,
    themeprovider.ThemeMode mode,
    String label,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = themeProvider.themeMode == mode;
    final borderRadius = BorderRadius.circular(AppDesign.radiusRound);
    return Material(
      color: isSelected
          ? colorScheme.primary
          : colorScheme.primaryContainer,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => _setMode(mode),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(Icons.check, size: 18, color: colorScheme.onPrimary),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onPrimaryContainer,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeTile(
    themeprovider.ThemeProvider themeProvider,
    themeprovider.ThemeMode theme,
    bool isSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final swatch = _themeSwatch(theme);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppDesign.borderLarge,
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withOpacity(0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected
          ? colorScheme.primaryContainer.withOpacity(0.4)
          : null,
      child: InkWell(
        borderRadius: AppDesign.borderLarge,
        onTap: () => _setMode(theme),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: swatch[0],
                  borderRadius: AppDesign.borderSmall,
                ),
                child: Icon(
                  themeProvider.getThemeIcon(theme),
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  themeProvider.getThemeName(theme),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              _swatchCircles(swatch),
              const SizedBox(width: 8),
              if (isSelected)
                Icon(Icons.check_circle, color: colorScheme.primary, size: 20)
              else
                const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swatchCircles(List<Color> colors) {
    return SizedBox(
      width: 56,
      height: 22,
      child: Stack(
        children: [
          for (int i = 0; i < colors.length; i++)
            Positioned(
              left: i * 16.0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openColorPicker() {
    Provider.of<HapticsProvider>(context, listen: false).selection();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Theme Color'),
          content: SingleChildScrollView(
            child: SlidePicker(
              pickerColor: _selectedColor,
              onColorChanged: _handleColorChange,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Provider.of<HapticsProvider>(context, listen: false)
                    .selection();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
