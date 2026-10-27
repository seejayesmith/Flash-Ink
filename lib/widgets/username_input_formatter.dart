import 'package:flutter/services.dart';

/// Automatically ensures username has '@' prefix when typing,
/// while allowing the field to be cleared back to empty so hint text appears.
class UsernameInputFormatter extends TextInputFormatter {
  const UsernameInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final stripped = newValue.text.replaceAll('@', '');
    if (stripped.isEmpty) {
      return const TextEditingValue(
        text: '@',
        selection: TextSelection.collapsed(offset: 1),
      );
    }

    final formatted = '@$stripped';

    int nonAtBeforeCursor = 0;
    final end = newValue.selection.end.clamp(0, newValue.text.length);
    for (int i = 0; i < end; i++) {
      if (newValue.text[i] != '@') {
        nonAtBeforeCursor++;
      }
    }

    final newOffset = (1 + nonAtBeforeCursor).clamp(0, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

/// Automatically strips leading '@' characters for input fields that
/// already render '@' as an InputDecoration prefixText.
class StripLeadingAtFormatter extends TextInputFormatter {
  const StripLeadingAtFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.startsWith('@')) {
      final stripped = newValue.text.replaceAll('@', '');
      return TextEditingValue(
        text: stripped,
        selection: TextSelection.collapsed(
          offset: (newValue.selection.baseOffset - 1).clamp(0, stripped.length),
        ),
      );
    }
    return newValue;
  }
}
