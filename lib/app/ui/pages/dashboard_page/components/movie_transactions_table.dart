import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/provider/settelementProvider.dart';
import 'package:media_house/data/models/response/movie_transaction.dart';
import 'package:media_house/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';

class MovieTransactionsTable extends StatelessWidget {
  final List<MovieTransaction> transactions;
  final bool isLoading;

  const MovieTransactionsTable({
    super.key,
    required this.transactions,
    this.isLoading = false,
  });

  String _formatCurrency(double? amount) {
    final val = amount ?? 0.0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(val);
  }

  String _formatDate(int? epochMs) {
    if (epochMs == null || epochMs <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    return DateFormat('dd MMM yyyy').format(dt);
  }

  void _showTransactionAuditDialog(BuildContext context, MovieTransaction txn) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).getTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(24),
                child: FutureBuilder(
                  future: Provider.of<SettelementProvider>(context, listen: false)
                      .fetchTransactionSettlementAudit(txn.transactionId ?? ''),
                  builder: (context, snapshot) {
                    final audit = Provider.of<SettelementProvider>(context)
                        .selectedTransactionAudit
                        ?.data;
                    final isAuditLoading = snapshot.connectionState == ConnectionState.waiting;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Transaction Settlement Audit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                        Text(
                          'Txn ID: ${txn.transactionId ?? "—"} • ${txn.movieTitle ?? "Movie"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        if (isAuditLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 36),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          _auditRow(
                            'Customer Payment (Gross)',
                            _formatCurrency(audit?.grossAmount ?? txn.customerPayment),
                            isDark: isDark,
                            isBold: true,
                          ),
                          _auditRow(
                            'GST (18%)',
                            '- ${_formatCurrency(audit?.gstAmount ?? txn.gstAmount)}',
                            isDark: isDark,
                            isDeduction: true,
                          ),
                          _auditRow(
                            'Base Amount (Excl. Tax)',
                            _formatCurrency(audit?.baseAmount ?? txn.baseAmount),
                            isDark: isDark,
                          ),
                          _auditRow(
                            'Payment Gateway Fee',
                            '- ${_formatCurrency(audit?.gatewayFee ?? txn.gatewayFee)}',
                            isDark: isDark,
                            isDeduction: true,
                          ),
                          _auditRow(
                            'Net Distributable Revenue',
                            _formatCurrency(audit?.netRevenue ?? txn.netRevenue),
                            isDark: isDark,
                            isHighlight: true,
                          ),
                          _auditRow(
                            'Platform Share',
                            _formatCurrency(audit?.platformShare ?? txn.adminRevenueShare),
                            isDark: isDark,
                          ),
                          _auditRow(
                            'Production House Gross Share',
                            _formatCurrency(audit?.mediaHouseShare ?? txn.mediaHouseRevenueShare),
                            isDark: isDark,
                          ),
                          if (audit?.tdsAmount != null && audit!.tdsAmount! > 0)
                            _auditRow(
                              'TDS Deducted (1%)',
                              '- ${_formatCurrency(audit.tdsAmount)}',
                              isDark: isDark,
                              isDeduction: true,
                            ),
                          const Divider(height: 20, thickness: 1.5),
                          _auditRow(
                            'Final Net Payout',
                            _formatCurrency(audit?.finalDisbursedAmount ?? txn.mediaHouseRevenueShare),
                            isDark: isDark,
                            isFinal: true,
                          ),
                        ],
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _auditRow(
    String label,
    String value, {
    required bool isDark,
    bool isBold = false,
    bool isDeduction = false,
    bool isHighlight = false,
    bool isFinal = false,
  }) {
    Color valColor;
    if (isFinal) {
      valColor = const Color(0xFF10B981);
    } else if (isDeduction) {
      valColor = const Color(0xFFEF4444);
    } else if (isHighlight) {
      valColor = const Color(0xFF8B5CF6);
    } else {
      valColor = isDark ? Colors.white : Colors.black87;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isFinal ? 14 : 12,
              fontWeight: (isBold || isFinal || isHighlight) ? FontWeight.bold : FontWeight.w500,
              color: isFinal
                  ? const Color(0xFF10B981)
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isFinal ? 15 : 13,
              fontWeight: (isBold || isFinal || isHighlight) ? FontWeight.bold : FontWeight.w600,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).getTheme;
    final isMobile = ResponsiveWidget.isMobile(context);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.teal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Movie Transactions',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: theme.canvasColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Itemized revenue per title and customer purchase',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.canvasColor.withValues(alpha: .6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (transactions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${transactions.length} Total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_outlined,
                      size: 44,
                      color: theme.canvasColor.withValues(alpha: .3),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No movie transactions found yet.',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.canvasColor.withValues(alpha: .6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (isMobile)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _mobileTransactionCard(context, transactions[index], theme),
            )
          else
            _desktopTable(context, transactions, theme),
        ],
      ),
    );
  }

  Widget _desktopTable(BuildContext context, List<MovieTransaction> list, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        horizontalMargin: 8,
        headingRowColor: WidgetStateProperty.all(
          theme.scaffoldBackgroundColor.withValues(alpha: .5),
        ),
        columns: const [
          DataColumn(label: Text('Txn ID', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Movie Title', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Period', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Customer Paid', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Base (Excl. Tax)', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Your Share', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Platform Share', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Audit', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: list.map((txn) {
          final isCompleted = (txn.status ?? '').toUpperCase() == 'COMPLETED';
          return DataRow(
            cells: [
              DataCell(Text(
                txn.transactionId ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w600),
              )),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.movie_outlined, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Text(
                    txn.movieTitle ?? 'Movie #${txn.movieId ?? ""}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              )),
              DataCell(Text(
                '${_formatDate(txn.dateFrom)} - ${_formatDate(txn.dateTo)}',
                style: const TextStyle(fontSize: 12),
              )),
              DataCell(Text(
                _formatCurrency(txn.customerPayment),
                style: const TextStyle(fontWeight: FontWeight.w600),
              )),
              DataCell(Text(
                _formatCurrency(txn.baseAmount),
              )),
              DataCell(Text(
                _formatCurrency(txn.mediaHouseRevenueShare),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade600,
                ),
              )),
              DataCell(Text(
                _formatCurrency(txn.adminRevenueShare),
                style: const TextStyle(color: Colors.purple),
              )),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withValues(alpha: .15)
                        : Colors.orange.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    txn.status ?? 'PENDING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.green.shade700 : Colors.orange.shade800,
                    ),
                  ),
                ),
              ),
              DataCell(
                IconButton(
                  tooltip: 'View Audit & Breakdown',
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  onPressed: () => _showTransactionAuditDialog(context, txn),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _mobileTransactionCard(BuildContext context, MovieTransaction txn, ThemeData theme) {
    final isCompleted = (txn.status ?? '').toUpperCase() == 'COMPLETED';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  txn.movieTitle ?? 'Movie #${txn.movieId ?? ""}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withValues(alpha: .15)
                      : Colors.orange.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  txn.status ?? 'PENDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.green.shade700 : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Txn: ${txn.transactionId ?? "—"} • ${_formatDate(txn.dateFrom)} to ${_formatDate(txn.dateTo)}',
            style: TextStyle(
              fontSize: 11,
              color: theme.canvasColor.withValues(alpha: .6),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Paid',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.canvasColor.withValues(alpha: .6),
                    ),
                  ),
                  Text(
                    _formatCurrency(txn.customerPayment),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Your Share',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.canvasColor.withValues(alpha: .6),
                    ),
                  ),
                  Text(
                    _formatCurrency(txn.mediaHouseRevenueShare),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showTransactionAuditDialog(context, txn),
              icon: const Icon(Icons.analytics_outlined, size: 14),
              label: const Text('View Breakdown', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}
