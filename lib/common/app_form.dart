import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_design.dart';
import 'app_widgets.dart';
import '../providers/hapticsprovider.dart';

/// Shared building blocks for the admin add/edit forms.
///
/// [showAppForm] presents a form responsively: a centered, width-constrained
/// dialog on wide/web layouts and a draggable, keyboard-aware modal bottom
/// sheet on phones. Both branches share the same [body] / [footer] widget tree,
/// so callers write the form once.

/// Width (in logical px) at/above which a form is shown as a centered dialog
/// instead of a bottom sheet. Matches the app's other wide-screen checks.
const double kAppFormWideBreakpoint = 720.0;

Future<T?> showAppForm<T>({
  required BuildContext context,
  required String title,
  IconData? icon,
  required WidgetBuilder body,
  required List<Widget> Function(BuildContext context) footer,
  double maxWidth = 520,
  VoidCallback? onDispose,
}) {
  final isWide = MediaQuery.of(context).size.width >= kAppFormWideBreakpoint;

  if (isWide) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: AppDesign.borderLarge),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: _AppFormShell(
            title: title,
            icon: icon,
            body: body,
            footer: footer,
            isSheet: false,
            onDispose: onDispose,
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppDesign.radiusLarge)),
    ),
    builder: (ctx) => _AppFormShell(
      title: title,
      icon: icon,
      body: body,
      footer: footer,
      isSheet: true,
      onDispose: onDispose,
    ),
  );
}

class _AppFormShell extends StatefulWidget {
  final String title;
  final IconData? icon;
  final WidgetBuilder body;
  final List<Widget> Function(BuildContext context) footer;
  final bool isSheet;
  final VoidCallback? onDispose;

  const _AppFormShell({
    required this.title,
    required this.icon,
    required this.body,
    required this.footer,
    required this.isSheet,
    this.onDispose,
  });

  @override
  State<_AppFormShell> createState() => _AppFormShellState();
}

class _AppFormShellState extends State<_AppFormShell> {
  @override
  void dispose() {
    // Runs after the subtree unmounts, so callers can safely dispose the
    // controllers their body/footer used without racing the close animation.
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final icon = widget.icon;
    final body = widget.body;
    final isSheet = widget.isSheet;
    final scheme = Theme.of(context).colorScheme;
    final actions = widget.footer(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSheet)
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(
                  top: AppDesign.spacingS, bottom: AppDesign.spacingXS),
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDesign.spacingL,
            AppDesign.spacingM,
            AppDesign.spacingL,
            AppDesign.spacingS,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: scheme.primary),
                const SizedBox(width: AppDesign.spacingS),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDesign.spacingL,
              AppDesign.spacingS,
              AppDesign.spacingL,
              AppDesign.spacingM,
            ),
            child: body(context),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(AppDesign.spacingM),
          child: Row(
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: AppDesign.spacingM),
                Expanded(child: actions[i]),
              ],
            ],
          ),
        ),
      ],
    );

    if (isSheet) {
      // Lift the sheet above the keyboard so fields stay visible.
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: content,
      );
    }
    return content;
  }
}

/// A titled section: a header (icon + title + optional subtitle) followed by a
/// surface-tinted card containing the grouped fields. Separate consecutive
/// sections with `SizedBox(height: AppDesign.spacingL)`.
class AppFormSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? subtitle;
  final Widget child;

  const AppFormSection({
    Key? key,
    required this.title,
    this.icon,
    this.subtitle,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title: title, subtitle: subtitle, icon: icon),
        const SizedBox(height: AppDesign.spacingM),
        AppSurfaceCard(
          padding: AppDesign.paddingMedium,
          child: child,
        ),
      ],
    );
  }
}

/// A read-only, tappable field styled to match [AppTextField]. Use in place of
/// `ElevatedButton`-as-picker for dates and times. Fires selection haptics.
class AppPickerField extends StatelessWidget {
  final String label;
  final String? value;
  final String? hint;
  final IconData icon;
  final VoidCallback onTap;

  const AppPickerField({
    Key? key,
    required this.label,
    this.value,
    this.hint,
    required this.icon,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = value != null && value!.isNotEmpty;

    return InkWell(
      onTap: () {
        Provider.of<HapticsProvider>(context, listen: false).selection();
        onTap();
      },
      borderRadius: AppDesign.borderMedium,
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: AppDesign.borderMedium),
          filled: true,
          fillColor: scheme.surface,
          // The icons live in the child Row, so keep content padding tight and
          // symmetric — this is what lets the field fit in narrow columns.
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDesign.spacingM, vertical: 14),
        ),
        // Icons are inline (not prefix/suffix) so they don't each reserve a
        // 48px tap target, and the value gets the remaining space with ellipsis
        // instead of wrapping.
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppDesign.spacingS),
            Expanded(
              child: Text(
                hasValue ? value! : (hint ?? 'Select'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color:
                          hasValue ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// A tokenized switch row for boolean options. Fires selection haptics.
class AppSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const AppSwitchRow({
    Key? key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          : null,
      value: value,
      onChanged: (v) {
        Provider.of<HapticsProvider>(context, listen: false).selection();
        onChanged(v);
      },
    );
  }
}

/// A dropdown styled to match the rest of the forms: same field decoration as
/// [AppTextField], a rounded/themed popup (instead of the default square menu),
/// and `isExpanded` so long options ellipsize instead of overflowing.
class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final IconData? prefixIcon;

  const AppDropdownField({
    Key? key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.prefixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      borderRadius: AppDesign.borderLarge,
      dropdownColor: scheme.surfaceContainerHigh,
      elevation: 3,
      decoration: appInputDecoration(context, label, prefixIcon: prefixIcon),
    );
  }
}

/// The same [InputDecoration] [AppTextField] uses, for the remaining
/// `DropdownButtonFormField`s so they match the text fields.
InputDecoration appInputDecoration(
  BuildContext context,
  String label, {
  IconData? prefixIcon,
  String? hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
    border: OutlineInputBorder(borderRadius: AppDesign.borderMedium),
    filled: true,
    fillColor: Theme.of(context).colorScheme.surface,
  );
}
