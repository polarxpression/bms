import 'package:diacritic/diacritic.dart';
import 'package:bms/core/models/battery.dart';

class SearchQueryParser {
  static bool matches(dynamic item, String query) {
    if (query.trim().isEmpty) return true;

    List<String> tokens = _tokenize(query);

    for (String token in tokens) {
      if (!_evaluateToken(item, token)) {
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

  static bool _evaluateToken(dynamic item, String token) {
    token = token.trim();
    if (token.isEmpty) return true;

    if (token.startsWith('-')) {
      return !_evaluateToken(item, token.substring(1));
    }

    if (token.startsWith('(') && token.endsWith(')')) {
      String content = token.substring(1, token.length - 1);
      List<String> orParts = content.split('~');
      for (String part in orParts) {
        if (_evaluateToken(item, part)) return true;
      }
      return false;
    }

    if (token.length >= 2 && token.startsWith('"') && token.endsWith('"')) {
      return _matchAnyField(
        item,
        token.substring(1, token.length - 1),
        isLiteral: true,
      );
    }

    if (token.contains(':')) {
      return _evaluateMetatag(item, token);
    }

    return _matchAnyField(item, token);
  }

  static bool _evaluateMetatag(dynamic item, String token) {
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

    int? valInt = int.tryParse(valStr);

    if (['qty', 'quantity', 'count', 'estoque', 'stock', 'qtd'].contains(key)) {
      return _compareInt(_getProperty(item, 'quantity') ?? 0, op, valInt ?? 0);
    }
    if (['gondola', 'gondolaqty', 'display'].contains(key)) {
      return _compareInt(_getProperty(item, 'gondolaQuantity') ?? 0, op, valInt ?? 0);
    }
    if (['limit', 'gondolalimit', 'max'].contains(key)) {
      return _compareInt(_getProperty(item, 'gondolaLimit') ?? 0, op, valInt ?? 0);
    }
    if (['pack', 'packsize'].contains(key)) {
      return _compareInt(_getProperty(item, 'packSize') ?? 0, op, valInt ?? 0);
    }

    String? fieldVal;
    if (key == 'brand' || key == 'marca') fieldVal = _getProperty(item, 'brand');
    if (key == 'model' || key == 'modelo') fieldVal = _getProperty(item, 'model');
    if (key == 'type' || key == 'tipo') fieldVal = _getProperty(item, 'type');
    if (key == 'barcode' || key == 'ean' || key == 'code') fieldVal = _getProperty(item, 'barcode');
    if (key == 'loc' || key == 'location' || key == 'local') fieldVal = _getProperty(item, 'location');
    if (key == 'volt' || key == 'voltage') fieldVal = _getProperty(item, 'voltage');
    if (key == 'chem' || key == 'chemistry') fieldVal = _getProperty(item, 'chemistry');
    
    // History specific
    if (key == 'reason' || key == 'motivo') fieldVal = _getProperty(item, 'reason');
    if (key == 'source' || key == 'fonte') fieldVal = _getProperty(item, 'source');
    if (key == 'battery' || key == 'bateria') fieldVal = _getProperty(item, 'batteryName');
    if (key == 'movement' || key == 'movimento') fieldVal = _getProperty(item, 'movement');

    if (fieldVal != null) {
      return _matchString(fieldVal, valStr, isLiteral: isLiteral);
    }

    return false;
  }

  static dynamic _getProperty(dynamic item, String prop) {
    if (item is Map) return item[prop];
    if (item is Battery) {
        switch(prop) {
            case 'quantity': return item.quantity;
            case 'gondolaQuantity': return item.gondolaQuantity;
            case 'gondolaLimit': return item.gondolaLimit;
            case 'packSize': return item.packSize;
            case 'brand': return item.brand;
            case 'model': return item.model;
            case 'type': return item.type;
            case 'barcode': return item.barcode;
            case 'location': return item.location;
            case 'voltage': return item.voltage;
            case 'chemistry': return item.chemistry;
            case 'name': return item.name;
            case 'notes': return item.notes;
        }
    }
    return null;
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
    dynamic item,
    String pattern, {
    bool isLiteral = false,
  }) {
    List<String?> haystack = [
      _getProperty(item, 'name'),
      _getProperty(item, 'batteryName'),
      _getProperty(item, 'brand'),
      _getProperty(item, 'model'),
      _getProperty(item, 'type'),
      _getProperty(item, 'barcode'),
      _getProperty(item, 'location'),
      _getProperty(item, 'notes'),
      _getProperty(item, 'voltage'),
      _getProperty(item, 'chemistry'),
      _getProperty(item, 'reason'),
      _getProperty(item, 'source'),
    ];
    return haystack.any((s) => s != null && _matchString(s, pattern, isLiteral: isLiteral));
  }

  static bool _matchString(
    String text,
    String pattern, {
    bool isLiteral = false,
  }) {
    text = removeDiacritics(text.toLowerCase());
    pattern = removeDiacritics(pattern.toLowerCase().replaceAll('_', ' '));

    if (!isLiteral && pattern.contains('*')) {
      String regexPattern = pattern.split('*').map(RegExp.escape).join('.*');
      return RegExp(regexPattern).hasMatch(text);
    }

    return text.contains(pattern);
  }
}
