import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';

class OnboardingDots extends StatelessWidget {
  const OnboardingDots({required this.count, required this.currentIndex, super.key});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final bool active = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: active ? 20 : 6,
          decoration: BoxDecoration(
            color: active ? theme.colorScheme.primary : theme.colorScheme.secondary.withOpacity(0.3),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }
}
