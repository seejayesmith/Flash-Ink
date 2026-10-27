import 'dart:math';
import 'package:flutter/services.dart';

/// Automatically formats 10-digit US phone numbers as '(XXX) XXX-XXXX'
/// in real-time as the user types, while allowing deletion and preserving valid cursor placement.
class PhoneNumberInputFormatter extends TextInputFormatter {
  const PhoneNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final trimmed = newValue.text.trim();
    if (trimmed.startsWith('+')) {
      final digits = trimmed.replaceAll(RegExp(r'\D'), '');
      final formatted = '+$digits';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    final rawDigits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final normalized = rawDigits.length == 11 && rawDigits.startsWith('1')
        ? rawDigits.substring(1)
        : rawDigits;
    final clean = normalized.length > 10 ? normalized.substring(0, 10) : normalized;

    if (clean.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    String formatted;
    if (clean.length <= 3) {
      formatted = '($clean';
    } else if (clean.length <= 6) {
      formatted = '(${clean.substring(0, 3)}) ${clean.substring(3)}';
    } else {
      formatted = '(${clean.substring(0, 3)}) ${clean.substring(3, 6)}-${clean.substring(6)}';
    }

    // Determine how many digits were before the cursor in newValue
    final end = min(newValue.selection.end.clamp(0, newValue.text.length), newValue.text.length);
    int digitsBeforeCursor = 0;
    for (int i = 0; i < end; i++) {
      final codeUnit = newValue.text.codeUnitAt(i);
      if (codeUnit >= 48 && codeUnit <= 57) {
        digitsBeforeCursor++;
      }
    }
    if (rawDigits.length == 11 && rawDigits.startsWith('1') && digitsBeforeCursor > 0) {
      digitsBeforeCursor--;
    }
    digitsBeforeCursor = digitsBeforeCursor.clamp(0, clean.length);

    // Find the cursor position in formatted text after digitsBeforeCursor digits
    int newCursorOffset = 0;
    int digitCount = 0;
    for (int i = 0; i < formatted.length; i++) {
      final codeUnit = formatted.codeUnitAt(i);
      if (codeUnit >= 48 && codeUnit <= 57) {
        digitCount++;
      }
      if (digitCount == digitsBeforeCursor) {
        newCursorOffset = i + 1;
        break;
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorOffset.clamp(0, formatted.length)),
    );
  }
}
