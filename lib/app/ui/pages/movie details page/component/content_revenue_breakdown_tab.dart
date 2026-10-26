import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_house/domain/entities/content.dart';
import 'package:media_house/app/core/utils/currency_formatter.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/provider/videoProvider.dart';

class ContentRevenueBreakdownTab extends StatefulWidget {
  final Content movie;
  final ThemeData theme;

  const ContentRevenueBreakdownTab({
    super.key,
    required this.movie,
    required this.theme,
  });

  @override
  State<ContentRevenueBreakdownTab> createState() =>
      _ContentRevenueBreakdownTabState();
}

class _ContentRevenueBreakdownTabState
    extends State<ContentRevenueBreakdownTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.movie.id != null) {
        Provider.of<VideoProvider>(context, listen: false)
            .fetchContentRevenueBreakdown(widget.movie.id!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).getTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<VideoProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingContentRevenue) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(
                color: theme.primaryColor,
              ),
            ),
          );
        }

        final breakdown = provider.contentRevenueBreakdown;
        if (breakdown == null) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No revenue breakdown data recorded yet for this content.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (widget.movie.id != null) {
                        provider.fetchContentRevenueBreakdown(widget.movie.id!);
                      }
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final gross = breakdown.customerPayment ?? 0.0;
        final gst = breakdown.gst ?? 0.0;
        final gateway = breakdown.gatewayFee ?? 0.0;
        final netRev = breakdown.netRevenue ?? (gross - gst - gateway);
        final prodGross = breakdown.productionGross ?? 0.0;
        final tds = breakdown.tds ?? 0.0;
        final payout = breakdown.payoutFee ?? 0.0;
        final finalNet = breakdown.finalNetRevenue ?? (prodGross - tds - payout);
        final purchases = breakdown.totalPurchases ?? widget.movie.totalPurchase ?? 0;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Summary Metric Cards
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildKpiCard(
                      context,
                      title: 'Total Customer Collection',
                      value: CurrencyFormatter.format(gross),
                      subtitle: '$purchases Purchases',
                      icon: Icons.payments_outlined,
                      color: const Color(0xFF3B82F6),
                      width: isDesktop
                          ? (constraints.maxWidth - 36) / 4
                          : (constraints.maxWidth - 12) / 2,
                    ),
                    _buildKpiCard(
                      context,
                      title: 'Net Platform Revenue',
                      value: CurrencyFormatter.format(netRev),
                      subtitle: 'After Taxes & Gateway Fee',
                      icon: Icons.account_balance_outlined,
                      color: const Color(0xFF8B5CF6),
                      width: isDesktop
                          ? (constraints.maxWidth - 36) / 4
                          : (constraints.maxWidth - 12) / 2,
                    ),
                    _buildKpiCard(
                      context,
                      title: 'Production House Gross',
                      value: CurrencyFormatter.format(prodGross),
                      subtitle: 'Agreement Share',
                      icon: Icons.movie_creation_outlined,
                      color: const Color(0xFF10B981),
                      width: isDesktop
                          ? (constraints.maxWidth - 36) / 4
                          : (constraints.maxWidth - 12) / 2,
                    ),
                    _buildKpiCard(
                      context,
                      title: 'Final Net Payout',
                      value: CurrencyFormatter.format(finalNet),
                      subtitle: 'Ready / Disbursed',
                      icon: Icons.verified_outlined,
                      color: const Color(0xFFF59E0B),
                      width: isDesktop
                          ? (constraints.maxWidth - 36) / 4
                          : (constraints.maxWidth - 12) / 2,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Detailed Calculation Breakdown Table / Waterfall
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Financial Waterfall & Deduction Audit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Live Backend Dynamic Audit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildAuditRow(
                        context,
                        title: '1. Customer Total Gross Payment',
                        note: 'Aggregate payments received from user purchases',
                        amount: gross,
                        isPositive: true,
                        isBold: true,
                      ),
                      const Divider(height: 20),
                      _buildAuditRow(
                        context,
                        title: '2. Goods & Services Tax (GST 18%)',
                        note: 'Mandatory statutory taxation',
                        amount: -gst,
                        isDeduction: true,
                      ),
                      const Divider(height: 20),
                      _buildAuditRow(
                        context,
                        title: '3. Payment Gateway Fee (2%)',
                        note: 'Razorpay / Cashfree processing fee',
                        amount: -gateway,
                        isDeduction: true,
                      ),
                      const Divider(height: 20),
                      _buildAuditRow(
                        context,
                        title: '4. Net Platform Distributable Pool',
                        note: 'Base pool calculated for revenue sharing',
                        amount: netRev,
                        isPositive: true,
                        isHighlight: true,
                      ),
                      const Divider(height: 20),
                      _buildAuditRow(
                        context,
                        title: '5. Production House Gross Share',
                        note: 'Revenue allocated as per production agreement',
                        amount: prodGross,
                        isPositive: true,
                      ),
                      const Divider(height: 20),
                      _buildAuditRow(
                        context,
                        title: '6. Tax Deducted at Source (TDS 1% u/s 194C)',
                        note: 'Statutory compliance withholding',
                        amount: -tds,
                        isDeduction: true,
                      ),
                      const Divider(height: 20),
                      _buildAuditRow(
                        context,
                        title: '7. Payout Processing Fee',
                        note: 'Bank node routing & IMPS / NEFT transfer charge',
                        amount: -payout,
                        isDeduction: true,
                      ),
                      const Divider(height: 24, thickness: 2),
                      _buildAuditRow(
                        context,
                        title: '8. Final Net Production Payout',
                        note: 'Disbursed / scheduled settlement balance',
                        amount: finalNet,
                        isFinal: true,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditRow(
    BuildContext context, {
    required String title,
    required String note,
    required double amount,
    bool isPositive = false,
    bool isDeduction = false,
    bool isBold = false,
    bool isHighlight = false,
    bool isFinal = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color amountColor;
    if (isFinal) {
      amountColor = const Color(0xFF10B981);
    } else if (isDeduction) {
      amountColor = const Color(0xFFEF4444);
    } else if (isHighlight) {
      amountColor = const Color(0xFF8B5CF6);
    } else {
      amountColor = isDark ? Colors.white : Colors.black87;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isFinal ? 15 : 13,
                    fontWeight:
                        (isBold || isFinal || isHighlight) ? FontWeight.bold : FontWeight.w600,
                    color: isFinal
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isDeduction
                ? '- ${CurrencyFormatter.format(amount.abs())}'
                : CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: isFinal ? 17 : 14,
              fontWeight:
                  (isBold || isFinal || isHighlight) ? FontWeight.w800 : FontWeight.w600,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
