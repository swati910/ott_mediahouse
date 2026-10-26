import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(dynamic value, {String symbol = '₹', bool showSymbol = true}) {
    return formatCurrency(value, symbol: symbol, showSymbol: showSymbol);
  }

  static String formatWithPrecision(dynamic value, {String symbol = '₹'}) {
    return formatCurrency(value, symbol: symbol);
  }
}

/// Formats a monetary value preserving exact decimal precision as returned by the API.
///
/// Features:
/// - Preserves exact decimal digits (e.g. 125.75 -> 125.75, 999.99 -> 999.99, 100.50 -> 100.50, 100.125 -> 100.125, 15.2542 -> 15.2542).
/// - Does not round or truncate using fixed decimal places.
/// - Whole numbers (e.g. 500 or 500.0) display as whole numbers (e.g. 500).
/// - Integer parts are formatted with locale grouping (en_IN format with commas).
/// - Supports customizable currency symbols ('₹', 'Rs ', etc.).
String formatCurrency(
  dynamic value, {
  String symbol = '₹',
  bool showSymbol = true,
}) {
  return formatAmount(
    value,
    symbol: symbol,
    showSymbol: showSymbol,
  );
}

/// Formats an amount number/string preserving exact decimal precision.
String formatAmount(
  dynamic value, {
  String symbol = '',
  bool showSymbol = true,
}) {
  if (value == null) {
    return showSymbol && symbol.isNotEmpty ? '$symbol${symbol.endsWith(' ') ? '0' : '0'}' : '0';
  }

  final str = value.toString().trim();
  if (str.isEmpty || str.toLowerCase() == 'null') {
    return showSymbol && symbol.isNotEmpty ? '$symbol${symbol.endsWith(' ') ? '0' : '0'}' : '0';
  }

  // If value is num and not finite (NaN / Infinity)
  if (value is num && !value.isFinite) {
    return showSymbol && symbol.isNotEmpty ? '$symbol${symbol.endsWith(' ') ? '0' : '0'}' : '0';
  }

  String raw = str;
  String effectiveSymbol = symbol;

  // Extract any prefix currency symbol in the string
  if (raw.startsWith('₹')) {
    effectiveSymbol = '₹';
    raw = raw.substring(1).trim();
  } else if (raw.toLowerCase().startsWith('rs.') ||
      raw.toLowerCase().startsWith('rs ')) {
    final spaceIdx = raw.indexOf(' ');
    effectiveSymbol = spaceIdx != -1 ? raw.substring(0, spaceIdx + 1) : 'Rs ';
    raw = spaceIdx != -1 ? raw.substring(spaceIdx + 1).trim() : raw.substring(3).trim();
  } else if (raw.toLowerCase().startsWith('rs')) {
    effectiveSymbol = 'Rs ';
    raw = raw.substring(2).trim();
  }

  final isNegative = raw.startsWith('-');
  if (isNegative) {
    raw = raw.substring(1).trim();
  }

  String formattedNumber;
  if (raw.contains('.')) {
    final parts = raw.split('.');
    final intPartStr = parts[0];
    final decPartStr = parts.sublist(1).join('.');

    final intVal = int.tryParse(intPartStr);
    final formattedInt = intVal != null
        ? NumberFormat.decimalPattern('en_IN').format(intVal)
        : intPartStr;

    String formattedDec;
    if (value is num && value % 1 == 0 && decPartStr == '0') {
      formattedDec = '';
    } else {
      formattedDec = '.$decPartStr';
    }

    final sign = isNegative ? '-' : '';
    formattedNumber = '$sign$formattedInt$formattedDec';
  } else {
    final intVal = int.tryParse(raw);
    final formattedInt = intVal != null
        ? NumberFormat.decimalPattern('en_IN').format(intVal)
        : raw;
    final sign = isNegative ? '-' : '';
    formattedNumber = '$sign$formattedInt';
  }

  if (showSymbol && effectiveSymbol.isNotEmpty) {
    return '$effectiveSymbol$formattedNumber';
  }
  return formattedNumber;
}

/// Percentage formatter that preserves exact precision without forced rounding.
String formatPercentage(dynamic value) {
  if (value == null) return '0%';
  final str = value.toString().trim();
  if (str.isEmpty || str.toLowerCase() == 'null') return '0%';
  if (value is num && !value.isFinite) return '0%';

  String raw = str;
  if (raw.endsWith('%')) {
    raw = raw.substring(0, raw.length - 1).trim();
  }

  if (value is num) {
    if (value % 1 == 0) {
      return '${value.toInt()}%';
    }
  }

  return '$raw%';
}
