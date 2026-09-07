/// Client-side validators used for immediate form feedback only. The
/// backend must re-validate everything — client validation is UX, not a
/// security boundary (spec section 34).
class Validators {
  const Validators._();

  static final RegExp _mongolianMobile = RegExp(r'^(\+976)?\s?[5-9]\d{7}$');

  /// Accepts Mongolian mobile numbers, with or without the +976 prefix,
  /// 8 digits starting 5-9 (the range Mongolian operators issue from).
  static bool isValidMongolianPhone(String input) {
    final String trimmed = input.trim().replaceAll(' ', '');
    return _mongolianMobile.hasMatch(trimmed);
  }

  static String normalizePhone(String input) {
    final String trimmed = input.trim().replaceAll(' ', '');
    if (trimmed.startsWith('+976')) return trimmed;
    if (trimmed.startsWith('976')) return '+$trimmed';
    return '+976$trimmed';
  }

  static bool isValidOtp(String input, {int length = 6}) {
    return RegExp('^\\d{$length}\$').hasMatch(input.trim());
  }

  static String? requiredField(String? value, {String message = 'required'}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  // Mongolian регистрийн дугаар: two Cyrillic letters followed by eight
  // digits (e.g. АА12345678). Client-side UX only — the real constraint
  // lives on `public.identity_details.register_number` (`char_length`
  // between 7 and 12, unique) since a client check can never be trusted
  // as the security boundary (spec section 34).
  static final RegExp _registerNumber = RegExp(r'^[А-ЯЁӨҮа-яёөү]{2}\d{8}$');

  static bool isValidRegisterNumber(String input) {
    return _registerNumber.hasMatch(normalizeRegisterNumber(input));
  }

  static String normalizeRegisterNumber(String input) {
    return input.trim().toUpperCase().replaceAll(' ', '');
  }
}
