import 'package:flutter/material.dart';
import 'app_design.dart';

//Consistant Card
class AppCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double elevation;
  final VoidCallback? onTap;

  const AppCard({
    Key? key,
    required this.child,
    this.backgroundColor,
    this.padding,
    this.borderRadius,
    this.elevation = AppDesign.elevationSmall,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardColor = backgroundColor ?? Theme.of(context).colorScheme.surface;

    final card = Card(
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? AppDesign.borderLarge,
      ),
      color: cardColor,
      child: Padding(
        padding: padding ?? AppDesign.paddingMedium,
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? AppDesign.borderLarge,
        child: card,
      );
    }

    return card;
  }
}

/// Surface variant card (for secondary content)
class AppSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const AppSurfaceCard({
    Key? key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevation: AppDesign.elevationNone,
      backgroundColor:
          Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: borderRadius ?? AppDesign.borderLarge,
      padding: padding ?? AppDesign.paddingLarge,
      onTap: onTap,
      child: child,
    );
  }
}

/// Standardized text input
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final TextInputType keyboardType;

  const AppTextField({
    Key? key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.onChanged,
    this.keyboardType = TextInputType.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: AppDesign.borderMedium,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}

/// Canonical content card — the Attendance-page look (flat, hairline border,
/// soft shadow). Use for list items (events, members, summaries).
class AppContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final Clip clipBehavior;
  const AppContentCard({
    Key? key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.clipBehavior = Clip.antiAlias,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppDesign.borderLarge,
        border: Border.all(color: scheme.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Section header with consistent styling
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;

  const AppSectionHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppDesign.spacingS),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppDesign.spacingXS),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}
