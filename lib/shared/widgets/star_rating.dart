import 'package:flutter/material.dart';

/// A row of five stars. Read-only when [onChanged] is null (e.g. showing
/// an existing review), interactive otherwise (picking a rating). Used by
/// the review screen and can back a future read-only rating display
/// elsewhere without duplicating this five-icon-row logic.
class StarRating extends StatelessWidget {
  const StarRating({
    required this.rating,
    this.onChanged,
    this.size = 28,
    super.key,
  });

  final int rating;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color filledColor = theme.colorScheme.primary;
    final Color emptyColor = theme.disabledColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final int starValue = index + 1;
        final bool filled = starValue <= rating;
        final Widget icon = Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: filled ? filledColor : emptyColor,
        );
        if (onChanged == null) return icon;
        return GestureDetector(
          onTap: () => onChanged!(starValue),
          child: icon,
        );
      }),
    );
  }
}
