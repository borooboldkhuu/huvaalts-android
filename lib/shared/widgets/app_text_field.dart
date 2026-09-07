import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    this.label,
    this.hintText,
    this.errorText,
    this.keyboardType,
    this.obscureText = false,
    this.autofocus = false,
    this.prefixText,
    this.onChanged,
    this.maxLength,
    this.maxLines = 1,
    this.suffixText,
    super.key,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autofocus;
  final String? prefixText;
  final String? suffixText;
  final ValueChanged<String>? onChanged;
  final int? maxLength;

  /// Number of visible text lines — pass >1 for multiline fields like a
  /// description. Defaults to a single line, matching every call site that
  /// predates this option (phone/OTP entry).
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofocus: autofocus,
          maxLength: maxLength,
          maxLines: obscureText ? 1 : maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            prefixText: prefixText,
            suffixText: suffixText,
            counterText: '',
          ),
        ),
      ],
    );
  }
}
