// Create a new file: lib/design/app_widgets.dart

import 'package:flutter/material.dart';
import 'app_design.dart';

/// Reusable cards with consistent styling
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
    final cardColor = backgroundColor ?? 
        Theme.of(context).colorScheme.surface;
    
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
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: borderRadius ?? AppDesign.borderLarge,
      padding: padding ?? AppDesign.paddingLarge,
      onTap: onTap,
      child: child,
    );
  }
}

/// Standardized primary button
class AppPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  
  const AppPrimaryButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final buttonContent = isLoading 
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: AppDesign.spacingS),
              const Text('Loading...'),
            ],
          )
        : icon != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon),
                  const SizedBox(width: AppDesign.spacingS),
                  Text(text),
                ],
              )
            : Text(text);
    
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          vertical: AppDesign.spacingM,
          horizontal: AppDesign.spacingL,
        ),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.borderMedium,
        ),
      ),
      child: buttonContent,
    );
    
    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }
    
    return button;
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