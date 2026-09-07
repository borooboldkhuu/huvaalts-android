import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Standard skeleton block for loading states (spec sections 5, 35, 43).
/// Respects reduced-motion by disabling the shimmer sweep and showing a
/// static placeholder instead.
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.sm,
    super.key,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final Widget block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.border,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );

    if (reduceMotion) return block;

    return Shimmer.fromColors(
      baseColor: colors.border,
      highlightColor: colors.surface,
      child: block,
    );
  }
}

/// A row of skeleton lines mimicking a card, used while lists/details load.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonLoader(height: 140, borderRadius: AppRadius.lg),
          SizedBox(height: AppSpacing.sm),
          SkeletonLoader(width: 160, height: 14),
          SizedBox(height: AppSpacing.xs),
          SkeletonLoader(width: 100, height: 14),
        ],
      ),
    );
  }
}
