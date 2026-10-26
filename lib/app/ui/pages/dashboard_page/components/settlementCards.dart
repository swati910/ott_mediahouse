import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_house/app/core/utils/currency_formatter.dart' as app_currency;
import 'package:media_house/app/provider/settelementProvider.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/data/models/response/media_house_settlement.dart';
import 'package:media_house/device/utils/ResponsiveWidget.dart';
import 'package:media_house/app/ui/pages/settlemet_page/weekly_settlement_report_page.dart';
import 'package:provider/provider.dart';

class SettlementCard extends StatefulWidget {
  final ValueChanged<String>? onSearchChanged;
  final bool autoLoad;
  const SettlementCard({
    super.key,
    this.onSearchChanged,
    this.autoLoad = true,
  });

  @override
  State<SettlementCard> createState() => _SettlementCardState();
}

class _SettlementCardState extends State<SettlementCard> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SettelementProvider>().fetchForCurrentMediaHouse();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().getTheme;
    final provider = context.watch<SettelementProvider>();
    final settlements = _filtered(provider.settlements);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ResponsiveWidget.isMobile(context)
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _title(theme),
              const SizedBox(height: 12),
              _search(theme),
            ])
          : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _title(theme),
              SizedBox(width: 400, child: _search(theme)),
            ]),
      const SizedBox(height: 6),
      Text('Search applies to the current page',
          style: TextStyle(
              color: theme.canvasColor.withValues(alpha: .55), fontSize: 11)),
      const SizedBox(height: 10),
      if (!provider.isLoading && settlements.isNotEmpty)
        SizedBox(
          height: 205,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: settlements.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, index) => _card(settlements[index], theme),
          ),
        )
      else if (!provider.isLoading && provider.errorMessage == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Text(
              provider.settlements.isEmpty
                  ? 'No settlement data available.'
                  : 'No settlement records match your search.',
              style: TextStyle(color: theme.canvasColor.withValues(alpha: .7)),
            ),
          ),
        ),
    ]);
  }

  Widget _title(ThemeData theme) => Text('Weekly Settlement',
      style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.w800,
          fontSize: 18));

  Widget _search(ThemeData theme) => TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {});
          widget.onSearchChanged?.call(value);
        },
        style: TextStyle(color: theme.canvasColor),
        decoration: InputDecoration(
          hintText: 'Search settlements on this page ...',
          filled: true,
          fillColor: theme.cardColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );

  List<MediaHouseSettlement> _filtered(List<MediaHouseSettlement> values) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return values;
    return values.where((item) {
      final haystack = [
        item.settlementId ?? 'N/A',
        item.settlementStatusValue,
        item.contentTypeLabel,
        item.mediaHouseName,
        formatSettlementDate(item.periodStartDate),
        formatSettlementDate(item.periodEndDate),
        formatSettlementDate(item.settlementDate, includeTime: true),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  Widget _card(MediaHouseSettlement item, ThemeData theme) => SizedBox(
        width: 330,
        child: Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => openSettlementReport(context, item),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: theme.dividerColor.withValues(alpha: .35)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              'Settlement ID: ${item.settlementId ?? 'N/A'}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12))),
                      _badge(item.settlementStatusValue, theme),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                        item.settlementPeriod.isEmpty
                            ? 'N/A'
                            : item.settlementPeriod,
                        style: TextStyle(
                            color: theme.canvasColor,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text(formatPeriod(item),
                        style: TextStyle(
                            color: theme.canvasColor.withValues(alpha: .72),
                            fontSize: 12)),
                    const Spacer(),
                    Row(children: [
                      _metric(theme, 'Revenue',
                          formatCurrency(item.customerPayment)),
                      _metric(
                          theme, 'Transactions', '${item.totalTransactions}'),
                      _metric(theme, 'Content', item.contentTypeLabel),
                    ]),
                    const SizedBox(height: 8),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'Payable: ${formatCurrency(item.finalPayableAmount)}',
                              style: TextStyle(
                                  color: theme.canvasColor,
                                  fontWeight: FontWeight.w800)),
                          Text('View',
                              style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w700)),
                        ]),
                  ]),
            ),
          ),
        ),
      );

  Widget _metric(ThemeData theme, String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(7)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    color: theme.canvasColor.withValues(alpha: .65),
                    fontSize: 9)),
            const SizedBox(height: 3),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: theme.canvasColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      );

  Widget _badge(String value, ThemeData theme) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: _statusColor(value).withValues(alpha: .16),
            borderRadius: BorderRadius.circular(12)),
        child: Text(value,
            style: TextStyle(
                color: _statusColor(value),
                fontSize: 10,
                fontWeight: FontWeight.w800)),
      );
}

Color _statusColor(String status) {
  switch (status.toUpperCase()) {
    case 'PAID':
      return Colors.green;
    case 'FAILED':
      return Colors.red;
    case 'CANCELLED':
      return Colors.grey;
    case 'PROCESSING':
      return Colors.blue;
    default:
      return Colors.orange;
  }
}

String formatSettlementDate(DateTime? date, {bool includeTime = false}) {
  if (date == null) return 'N/A';
  final local = date.toLocal();
  return DateFormat(includeTime ? 'dd-MM-yyyy, hh:mm a' : 'dd-MM-yyyy')
      .format(local);
}

String formatPeriod(MediaHouseSettlement item) {
  if (item.periodStartDate == null || item.periodEndDate == null) {
    return 'Period dates unavailable';
  }
  return '${formatSettlementDate(item.periodStartDate)} - ${formatSettlementDate(item.periodEndDate)}';
}

String formatCurrency(dynamic value) =>
    app_currency.formatCurrency(value);

String formatPercentage(dynamic value) =>
    app_currency.formatPercentage(value);

void openSettlementReport(BuildContext context, MediaHouseSettlement item) {
  final reference = item.batchReference;
  if (reference == null || reference.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Settlement batch reference is unavailable.'),
    ));
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => WeeklySettlementReportPage(
      settlementBatchReference: reference,
    ),
  ));
}

void showSettlementDetails(BuildContext context, MediaHouseSettlement item) {
  final theme = context.read<ThemeProvider>().getTheme;
  final rows = <MapEntry<String, String>>[
    MapEntry('Settlement ID', item.settlementId ?? 'N/A'),
    MapEntry('Media house',
        item.mediaHouseName.isEmpty ? 'N/A' : item.mediaHouseName),
    MapEntry('Settlement period',
        item.settlementPeriod.isEmpty ? 'N/A' : item.settlementPeriod),
    MapEntry('Period start', formatSettlementDate(item.periodStartDate)),
    MapEntry('Period end', formatSettlementDate(item.periodEndDate)),
    MapEntry('Settlement date',
        formatSettlementDate(item.settlementDate, includeTime: true)),
    MapEntry('Status', item.settlementStatusValue),
    MapEntry('Content type', item.contentTypeLabel),
    MapEntry('Total transactions', '${item.totalTransactions}'),
    MapEntry('Customer payment', formatCurrency(item.customerPayment)),
    MapEntry('GST charges', formatCurrency(item.gstCharges)),
    MapEntry('Customer platform charges',
        formatCurrency(item.customerPlatformCharges)),
    MapEntry('Net revenue', formatCurrency(item.netRevenue)),
    MapEntry('Commission percentage',
        formatPercentage(item.mediaHouseCommissionPercentage)),
    MapEntry(
        'Media house commission', formatCurrency(item.mediaHouseCommission)),
    MapEntry('Gross Revenue', formatCurrency(item.grossRevenue)),
    MapEntry('TDS', formatCurrency(item.tds)),
    MapEntry('Settlement platform charges',
        formatCurrency(item.settlementPlatformCharges)),
    MapEntry('Other deductions', formatCurrency(item.otherDeductions)),
    MapEntry('Total deductions', formatCurrency(item.totalDeductions)),
    MapEntry('Final payable amount', formatCurrency(item.finalPayableAmount)),
    if (item.walletCredited) ...[
      const MapEntry('Wallet status', 'Credited to Wallet'),
      MapEntry(
          'Wallet transaction', item.walletTransactionReference ?? 'N/A'),
      MapEntry('Credited amount', formatCurrency(item.walletCreditedAmount)),
      MapEntry('Credited date',
          formatSettlementDate(item.walletCreditedAt, includeTime: true)),
    ],
  ];
  showDialog(
      context: context,
      builder: (_) => Dialog(
            backgroundColor: theme.cardColor,
            child: Container(
              width: 560,
              constraints: const BoxConstraints(maxHeight: 650),
              padding: const EdgeInsets.all(22),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settlement details',
                        style: TextStyle(
                            color: theme.canvasColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    Flexible(
                        child: SingleChildScrollView(
                            child: Column(
                                children: rows
                                    .map((row) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 5),
                                          child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                    child: Text(row.key,
                                                        style: TextStyle(
                                                            color: theme
                                                                .canvasColor
                                                                .withValues(
                                                                    alpha:
                                                                        .7)))),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                    child: Text(row.value,
                                                        textAlign:
                                                            TextAlign.end,
                                                        style: TextStyle(
                                                            color: theme
                                                                .canvasColor,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700))),
                                              ]),
                                        ))
                                    .toList()))),
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'))),
                  ]),
            ),
          ));
}
