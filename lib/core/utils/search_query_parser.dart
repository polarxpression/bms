import 'package:diacritic/diacritic.dart';
import 'package:bms/core/models/battery.dart';

class SearchQueryParser {
  static bool matches(Battery b, String query) {
    if (query.trim().isEmpty) return true;

    List<String> tokens = _tokenize(query);

    for (String token in tokens) {
      if (!_evaluateToken(b, token)) {
        return false;
      }
    }
    return true;
  }

  static List<String> _tokenize(String query) {
    List<String> tokens = [];
    StringBuffer buffer = StringBuffer();
    int parensDepth = 0;
    bool inQuotes = false;

    for (int i = 0; i < query.length; i++) {
      String char = query[i];

      if (char == '"') {
        inQuotes = !inQuotes;
        buffer.write(char);
      } else if (char == '(' && !inQuotes) {
        parensDepth++;
        buffer.write(char);
      } else if (char == ')' && !inQuotes) {
        if (parensDepth > 0) parensDepth--;
        buffer.write(char);
      } else if (char == ' ' && parensDepth == 0 && !inQuotes) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }
    return tokens;
  }

  static bool _evaluateToken(Battery b, String token) {
    token = token.trim();
    if (token.isEmpty) return true;

    if (token.startsWith('-')) {
      return !_evaluateToken(b, token.substring(1));
    }

    if (token.startsWith('(') && token.endsWith(')')) {
      String content = token.substring(1, token.length - 1);
      List<String> orParts = content.split('~');
      for (String part in orParts) {
        if (_evaluateToken(b, part)) return true;
      }
      return false;
    }

    if (token.length >= 2 && token.startsWith('"') && token.endsWith('"')) {
      return _matchAnyField(
        b,
        token.substring(1, token.length - 1),
        isLiteral: true,
      );
    }

    if (token.contains(':')) {
      return _evaluateMetatag(b, token);
    }

    return _matchAnyField(b, token);
  }

  static bool _evaluateMetatag(Battery b, String token) {
    int colonIndex = token.indexOf(':');
    String key = removeDiacritics(token.substring(0, colonIndex).toLowerCase());
    String expression = token.substring(colonIndex + 1).toLowerCase();

    bool isLiteral = false;
    if (expression.length >= 2 &&
        expression.startsWith('"') &&
        expression.endsWith('"')) {
      expression = expression.substring(1, expression.length - 1);
      isLiteral = true;
    }

    String op = '=';
    String valStr = expression;

    if (!isLiteral) {
      if (expression.startsWith('>=')) {
        op = '>=';
        valStr = expression.substring(2);
      } else if (expression.startsWith('<=')) {
        op = '<=';
        valStr = expression.substring(2);
      } else if (expression.startsWith('>')) {
        op = '>';
        valStr = expression.substring(1);
      } else if (expression.startsWith('<')) {
        op = '<';
        valStr = expression.substring(1);
      }
    }

    // NEW: Added aliases for gondola and stock searches
    if (['qty', 'quantity', 'count', 'estoque', 'stock'].contains(key)) {
      return _compareInt(b.quantity, op, int.tryParse(valStr) ?? 0);
    }
    if (['gondola', 'gondolaqty', 'display'].contains(key)) {
      return _compareInt(b.gondolaQuantity, op, int.tryParse(valStr) ?? 0);
    }
    if (['limit', 'gondolalimit', 'max'].contains(key)) {
      return _compareInt(b.gondolaLimit, op, int.tryParse(valStr) ?? 0);
    }
    if (['pack', 'packsize'].contains(key)) {
      return _compareInt(b.packSize, op, int.tryParse(valStr) ?? 0);
    }

    String? fieldVal;
    if (key == 'brand' || key == 'marca') {
      fieldVal = b.brand;
    }
    if (key == 'model' || key == 'modelo') {
      fieldVal = b.model;
    }
    if (key == 'type' || key == 'tipo') {
      fieldVal = b.type;
    }
    if (key == 'loc' || key == 'location' || key == 'local') {
      fieldVal = b.location;
    }
    if (key == 'volt' || key == 'voltage') {
      fieldVal = b.voltage;
    }
    if (key == 'chem' || key == 'chemistry') {
      fieldVal = b.chemistry;
    }

    if (fieldVal != null) {
      return _matchString(fieldVal, valStr, isLiteral: isLiteral);
    }

    return false;
  }

  static bool _compareInt(int actual, String op, int target) {
    switch (op) {
      case '>':
        return actual > target;
      case '<':
        return actual < target;
      case '>=':
        return actual >= target;
      case '<=':
        return actual <= target;
      default:
        return actual == target;
    }
  }

  static bool _matchAnyField(
    Battery b,
    String pattern, {
    bool isLiteral = false,
  }) {
    List<String> haystack = [
      b.name,
      b.brand,
      b.model,
      b.type,
      b.location,
      b.notes,
      b.voltage,
      b.chemistry,
    ];
    return haystack.any((s) => _matchString(s, pattern, isLiteral: isLiteral));
  }

  static bool _matchString(
    String text,
    String pattern, {
    bool isLiteral = false,
  }) {
    // Normalize both to remove diacritics
    text = removeDiacritics(text.toLowerCase());
    pattern = removeDiacritics(pattern.toLowerCase().replaceAll('_', ' '));

    if (!isLiteral && pattern.contains('*')) {
      String regexPattern = pattern.split('*').map(RegExp.escape).join('.*');
      return RegExp(regexPattern).hasMatch(text);
    }

    return text.contains(pattern);
  }
}
