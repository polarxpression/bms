export class SearchQueryParser {
  static removeDiacritics(str: string): string {
    return str.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  }

  static matches(item: any, query: string): boolean {
    if (!query || query.trim().length === 0) return true;

    const tokens = this._tokenize(query);

    for (const token of tokens) {
      if (!this._evaluateToken(item, token)) {
        return false;
      }
    }
    return true;
  }

  private static _tokenize(query: string): string[] {
    const tokens: string[] = [];
    let buffer = "";
    let parensDepth = 0;
    let inQuotes = false;

    for (let i = 0; i < query.length; i++) {
      const char = query[i];

      if (char === '"') {
        inQuotes = !inQuotes;
        buffer += char;
      } else if (char === '(' && !inQuotes) {
        parensDepth++;
        buffer += char;
      } else if (char === ')' && !inQuotes) {
        if (parensDepth > 0) parensDepth--;
        buffer += char;
      } else if (char === ' ' && parensDepth === 0 && !inQuotes) {
        if (buffer.length > 0) {
          tokens.push(buffer);
          buffer = "";
        }
      } else {
        buffer += char;
      }
    }
    if (buffer.length > 0) {
      tokens.push(buffer);
    }
    return tokens;
  }

  private static _evaluateToken(item: any, token: string): boolean {
    token = token.trim();
    if (token.length === 0) return true;

    if (token.startsWith('-')) {
      return !this._evaluateToken(item, token.substring(1));
    }

    if (token.startsWith('(') && token.endsWith(')')) {
      const content = token.substring(1, token.length - 1);
      const orParts = content.split('~');
      for (const part of orParts) {
        if (this._evaluateToken(item, part)) return true;
      }
      return false;
    }

    if (token.length >= 2 && token.startsWith('"') && token.endsWith('"')) {
      return this._matchAnyField(
        item,
        token.substring(1, token.length - 1),
        true
      );
    }

    if (token.includes(':')) {
      return this._evaluateMetatag(item, token);
    }

    return this._matchAnyField(item, token);
  }

  private static _evaluateMetatag(item: any, token: string): boolean {
    const colonIndex = token.indexOf(':');
    const key = this.removeDiacritics(token.substring(0, colonIndex).toLowerCase());
    let expression = token.substring(colonIndex + 1).toLowerCase();

    let isLiteral = false;
    if (expression.length >= 2 && expression.startsWith('"') && expression.endsWith('"')) {
      expression = expression.substring(1, expression.length - 1);
      isLiteral = true;
    }

    let op = '=';
    let valStr = expression;

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

    const valInt = parseInt(valStr);

    if (['qty', 'quantity', 'count', 'estoque', 'stock', 'qtd'].includes(key)) {
      return this._compareInt(item.quantity || 0, op, isNaN(valInt) ? 0 : valInt);
    }
    if (['gondola', 'gondolaqty', 'display'].includes(key)) {
      return this._compareInt(item.gondolaQuantity || 0, op, isNaN(valInt) ? 0 : valInt);
    }
    if (['limit', 'gondolalimit', 'max'].includes(key)) {
      return this._compareInt(item.gondolaLimit || 0, op, isNaN(valInt) ? 0 : valInt);
    }
    if (['pack', 'packsize'].includes(key)) {
      return this._compareInt(item.packSize || 0, op, isNaN(valInt) ? 0 : valInt);
    }

    let fieldVal: string | undefined;
    if (key === 'brand' || key === 'marca') fieldVal = item.brand;
    if (key === 'model' || key === 'modelo') fieldVal = item.model;
    if (key === 'type' || key === 'tipo') fieldVal = item.type;
    if (key === 'barcode' || key === 'ean' || key === 'code') fieldVal = item.barcode;
    if (key === 'loc' || key === 'location' || key === 'local') fieldVal = item.location;
    if (key === 'volt' || key === 'voltage') fieldVal = item.voltage;
    if (key === 'chem' || key === 'chemistry') fieldVal = item.chemistry;
    
    // History specific
    if (key === 'reason' || key === 'motivo') fieldVal = item.reason;
    if (key === 'source' || key === 'fonte') fieldVal = item.source;
    if (key === 'battery' || key === 'bateria') fieldVal = item.batteryName;
    if (key === 'movement' || key === 'movimento') fieldVal = item.movement;

    if (fieldVal !== undefined) {
      return this._matchString(fieldVal, valStr, isLiteral);
    }

    return false;
  }

  private static _compareInt(actual: number, op: string, target: number): boolean {
    switch (op) {
      case '>': return actual > target;
      case '<': return actual < target;
      case '>=': return actual >= target;
      case '<=': return actual <= target;
      default: return actual === target;
    }
  }

  private static _matchAnyField(item: any, pattern: string, isLiteral: boolean = false): boolean {
    const haystack = [
      item.name || "",
      item.batteryName || "",
      item.brand || "",
      item.model || "",
      item.type || "",
      item.barcode || "",
      item.location || "",
      item.notes || "",
      item.voltage || "",
      item.chemistry || "",
      item.reason || "",
      item.source || "",
    ];
    return haystack.some(s => this._matchString(s, pattern, isLiteral));
  }

  private static _matchString(text: string, pattern: string, isLiteral: boolean = false): boolean {
    text = this.removeDiacritics(text.toLowerCase());
    pattern = this.removeDiacritics(pattern.toLowerCase().replace(/_/g, ' '));

    if (!isLiteral && pattern.includes('*')) {
      const parts = pattern.split('*');
      const escapedParts = parts.map(s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
      const regexPattern = escapedParts.join('.*');
      return new RegExp(regexPattern).test(text);
    }

    return text.includes(pattern);
  }
}
