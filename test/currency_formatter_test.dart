import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/app/core/utils/currency_formatter.dart';

void main() {
  group('currency_formatter', () {
    test('formats whole numbers without decimals', () {
      expect(formatCurrency(500), '₹500');
      expect(formatCurrency(500.0), '₹500');
      expect(formatAmount(500), '500');
      expect(formatCurrency('500'), '₹500');
      expect(formatCurrency(0), '₹0');
      expect(formatCurrency(0.0), '₹0');
    });

    test('preserves two decimal places exactly as received', () {
      expect(formatCurrency(125.75), '₹125.75');
      expect(formatCurrency(999.99), '₹999.99');
      expect(formatCurrency(10.25), '₹10.25');
      expect(formatCurrency('100.50'), '₹100.50');
      expect(formatAmount(125.75), '125.75');
      expect(formatAmount('100.50'), '100.50');
    });

    test('preserves single and arbitrary decimal precision', () {
      expect(formatCurrency(100.5), '₹100.5');
      expect(formatCurrency(100.125), '₹100.125');
      expect(formatCurrency('100.1250'), '₹100.1250');
      expect(formatCurrency(15.2542), '₹15.2542');
      expect(formatAmount(100.125), '100.125');
      expect(formatAmount('100.1250'), '100.1250');
    });

    test('formats large numbers with locale comma grouping and exact decimals', () {
      expect(formatCurrency(1234567.89), '₹12,34,567.89');
      expect(formatAmount(1234567.89), '12,34,567.89');
    });

    test('supports custom symbols and existing currency prefixes', () {
      expect(formatCurrency(125.75, symbol: 'Rs '), 'Rs 125.75');
      expect(formatCurrency('₹ 125.75'), '₹125.75');
      expect(formatCurrency('Rs. 2110.00'), 'Rs. 2,110.00');
    });

    test('handles null and empty values gracefully', () {
      expect(formatCurrency(null), '₹0');
      expect(formatCurrency(''), '₹0');
      expect(formatAmount(null), '0');
      expect(formatAmount(''), '0');
    });

    test('percentage formatter works correctly', () {
      expect(formatPercentage(70), '70%');
      expect(formatPercentage(70.5), '70.5%');
      expect(formatPercentage('18.25%'), '18.25%');
    });
  });
}
