import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/data/models/response/mediaHouseDashboardCount.dart';
import 'package:media_house/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';

class FinancialBreakdownCard extends StatelessWidget {
  final MediaHouseDashboardData data;

  const FinancialBreakdownCard({super.key, required this.data});

  String _formatCurrency(double? amount) {
    final val = amount ?? 0.0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(val);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).getTheme;
    final isMobile = ResponsiveWidget.isMobile(context);

    final customerPaid = data.customerPayment ?? 0.0;
    final gst = data.gstCharges ?? (customerPaid > 0 ? customerPaid * 0.18 / 1.18 : 0.0);
    final baseAmount = data.baseAmountAfterGST ?? (customerPaid - gst);
    final gatewayFee = data.paymentGatewayFees ?? 0.0;
    final netRev = data.netRevenue ?? (baseAmount - gatewayFee);
    final platformRev = data.platformRevenue ?? 0.0;
    final finalShare = data.finalProductionHouseRevenue ?? data.productionHouseRevenue ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.pie_chart_outline_rounded,
                  color: theme.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial & Revenue Split Summary',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: theme.canvasColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Itemized breakdown from gross customer payment to final net payout',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.canvasColor.withValues(alpha: .6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final double itemWidth = isMobile
                  ? (constraints.maxWidth - 8) / 2
                  : constraints.maxWidth >= 1000
                      ? (constraints.maxWidth - 36) / 4
                      : (constraints.maxWidth - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _metricPill(
                      title: 'Customer Payment',
                      value: _formatCurrency(customerPaid),
                      subtitle: '${data.purchaseCount ?? 0} Purchases',
                      icon: Icons.payments_outlined,
                      color: Colors.blue,
                      theme: theme,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricPill(
                      title: 'GST Charges',
                      value: '- ${_formatCurrency(gst)}',
                      subtitle: 'Statutory GST Tax',
                      icon: Icons.receipt_outlined,
                      color: Colors.deepOrange,
                      theme: theme,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricPill(
                      title: 'Base Amount (Excl. GST)',
                      value: _formatCurrency(baseAmount),
                      subtitle: 'Tax-exclusive Base',
                      icon: Icons.account_balance_outlined,
                      color: Colors.indigo,
                      theme: theme,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricPill(
                      title: 'Payment Gateway Fee',
                      value: '- ${_formatCurrency(gatewayFee)}',
                      subtitle: 'PG Processing Fee',
                      icon: Icons.credit_card_outlined,
                      color: Colors.amber.shade800,
                      theme: theme,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricPill(
                      title: 'Net Pool Revenue',
                      value: _formatCurrency(netRev),
                      subtitle: 'Distributable Pool',
                      icon: Icons.calculate_outlined,
                      color: Colors.teal,
                      theme: theme,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricPill(
                      title: 'Platform Share',
                      value: _formatCurrency(platformRev),
                      subtitle: 'Admin / Platform Split',
                      icon: Icons.corporate_fare_outlined,
                      color: Colors.purple,
                      theme: theme,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricPill(
                      title: 'Production House Revenue',
                      value: _formatCurrency(data.productionHouseRevenue ?? finalShare),
                      subtitle: 'Contracted Share',
                      icon: Icons.movie_creation_outlined,
                      color: Colors.cyan.shade700,
                      theme: theme,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _metricPill(
                      title: 'Final Net Share',
                      value: _formatCurrency(finalShare),
                      subtitle: 'Net Credited to Wallet',
                      icon: Icons.verified_outlined,
                      color: Colors.green.shade600,
                      theme: theme,
                      isHighlighted: true,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metricPill({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? color.withValues(alpha: .1)
            : theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? color.withValues(alpha: .5)
              : theme.dividerColor.withValues(alpha: .2),
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.canvasColor.withValues(alpha: .75),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isHighlighted ? color : theme.canvasColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: theme.canvasColor.withValues(alpha: .5),
            ),
          ),
        ],
      ),
    );
  }
}
