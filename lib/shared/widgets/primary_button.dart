import 'package:flutter/material.dart';

/// Full-width primary CTA with a built-in loading state, used for every
/// "main action" across the app (onboarding CTA, phone continue, booking
/// confirm, etc.) so press feedback and disabled/loading states stay
/// consistent everywhere (spec section 36: subtle premium press feedback).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || isLoading;

    return AnimatedScale(
      scale: 1,
      duration: const Duration(milliseconds: 120),
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}
