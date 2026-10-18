/// Normalisation used to compare typed login details with a stored record.
///
/// This only tolerates formatting differences (case, spacing, +91 prefix).
/// A match is a record lookup — anyone who knows the three values can match.
class IdentityMatcher {
  const IdentityMatcher._();

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  /// Lower-cases, drops dots and collapses whitespace: "Dr.  A. Mehra" →
  /// "dr a mehra".
  static String normalizeName(String value) => value
      .toLowerCase()
      .replaceAll('.', ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .join(' ');

  /// Returns the 10-digit Indian mobile number, or null if [value] is not one.
  /// Accepts spaces, dashes and a leading +91, 91 or 0.
  static String? normalizeMobile(String value) {
    var digits = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.startsWith('+')) digits = digits.substring(1);
    if (!RegExp(r'^\d+$').hasMatch(digits)) return null;
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) return null;
    return digits;
  }

  static bool isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(value.trim());

  static bool matches({
    required String typedName,
    required String typedEmail,
    required String typedMobile,
    required String recordName,
    required String recordEmail,
    required String recordMobile,
  }) {
    final mobile = normalizeMobile(typedMobile);
    return mobile != null &&
        mobile == normalizeMobile(recordMobile) &&
        normalizeEmail(typedEmail) == normalizeEmail(recordEmail) &&
        normalizeName(typedName) == normalizeName(recordName);
  }
}
