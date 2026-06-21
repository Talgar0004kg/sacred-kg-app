import 'package:flutter/services.dart';

/// Авто-форматтер для кыргызских номеров телефона.
///
/// Подставляет префикс `+996 ` и группирует оставшиеся цифры тройками:
/// `+996 XXX XXX XXX`. Пользователь печатает только цифры — пробелы
/// и плюс расставляются сами.
///
/// Использование:
/// ```dart
/// TextField(
///   controller: phone,
///   keyboardType: TextInputType.phone,
///   inputFormatters: [KgPhoneInputFormatter()],
///   decoration: InputDecoration(hintText: '+996 XXX XXX XXX'),
/// )
/// ```
class KgPhoneInputFormatter extends TextInputFormatter {
  static const String _prefix = '+996 ';
  static const int _maxBodyDigits = 9; // 9 цифр после +996

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;

    // Все нецифровые символы выкидываем, оставляем чистые цифры.
    var digits = raw.replaceAll(RegExp(r'\D'), '');

    // Если пользователь ввёл что-то начинающееся с 996 — отрезаем префикс.
    if (digits.startsWith('996')) {
      digits = digits.substring(3);
    }
    // На случай вставки полного номера с 0 в начале (например, 0700123456)
    // тоже отбрасываем ведущий 0.
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // Не больше 9 цифр в теле.
    if (digits.length > _maxBodyDigits) {
      digits = digits.substring(0, _maxBodyDigits);
    }

    final buf = StringBuffer(_prefix);
    if (digits.isNotEmpty) {
      // Первые 3 (код оператора).
      final firstEnd = digits.length < 3 ? digits.length : 3;
      buf.write(digits.substring(0, firstEnd));
    }
    if (digits.length > 3) {
      buf.write(' ');
      final secondEnd = digits.length < 6 ? digits.length : 6;
      buf.write(digits.substring(3, secondEnd));
    }
    if (digits.length > 6) {
      buf.write(' ');
      buf.write(digits.substring(6));
    }

    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Проверка, что номер заполнен полностью: +996 + 9 цифр.
  static bool isValid(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (!digits.startsWith('996')) return false;
    return digits.length == 12;
  }
}
