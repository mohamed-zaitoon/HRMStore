// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

class WhatsappUtils {
  WhatsappUtils._();

  static final RegExp _validEgyptianWhatsapp = RegExp(r'^01\d{9}$');

  static String _toAsciiDigits(String value) {
    if (value.isEmpty) return '';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + (rune - 0x0660));
        continue;
      }
      if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + (rune - 0x06F0));
        continue;
      }
      buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }

  /// AR: تطبيع رقم الواتساب إلى الصيغة المصرية المحلية: 01XXXXXXXXX.
  static String normalizeEgyptianWhatsapp(String value) {
    var digits = _toAsciiDigits(value).replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (digits.isEmpty) return '';

    if (digits.startsWith('0020')) {
      digits = digits.substring(2); // -> 20XXXXXXXXXX
    }

    if (digits.startsWith('20') && digits.length == 12 && digits[2] == '1') {
      digits = '0${digits.substring(2)}';
    }

    return digits;
  }

  static bool isValidEgyptianWhatsapp(String value) {
    final normalized = normalizeEgyptianWhatsapp(value);
    return _validEgyptianWhatsapp.hasMatch(normalized);
  }

  static String? validateRequiredEgyptianWhatsapp(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'رقم الواتساب مطلوب';
    if (!isValidEgyptianWhatsapp(raw)) {
      return 'رقم الواتساب يجب أن يكون 11 رقم ويبدأ بـ 01';
    }
    return null;
  }
}
