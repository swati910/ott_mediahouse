import 'package:media_house/data/models/response/movie_transaction.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_house/app/core/utils/currency_formatter.dart';
import 'package:media_house/app/core/utils/sharepreferences.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/provider/wallet_provider.dart';
import 'package:media_house/app/ui/pages/settlemet_page/weekly_settlement_report_page.dart';
import 'package:media_house/app/ui/pages/wallet_page/components/withdraw_dialog.dart';
import 'package:media_house/data/models/response/production_house_wallet.dart';
import 'package:media_house/domain/entities/mediaHouse.dart';
import 'package:provider/provider.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _search = TextEditingController();
  final _minAmount = TextEditingController();
  final _maxAmount = TextEditingController();
  String? _type;
  String? _status;
  String? _entryType;
  DateTime? _fromDate;
  DateTime? _toDate;
  MediaHouse? _mediaHouse;

  static const _types = [
    'SETTLEMENT_CREDIT',
    'WITHDRAWAL',
    'PAYOUT',
    'REFUND_DEBIT',
    'ADJUSTMENT_CREDIT',
    'ADJUSTMENT_DEBIT',
    'REVERSAL',
    'HOLD',
    'HOLD_RELEASE',
  ];
  static const _statuses = [
    'PENDING',
    'PROCESSING',
    'COMPLETED',
    'FAILED',
    'REVERSED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _loadMediaHouse();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load(refresh: true);
    });
  }

  Future<void> _loadMediaHouse() async {
    final media = await LocalSharePreferences().getMediaHouse();
    if (mounted) {
      setState(() => _mediaHouse = media);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _minAmount.dispose();
    _maxAmount.dispose();
    super.dispose();
  }

  Future<void> _openWithdrawDialog(double availableBalance) async {
    if (_mediaHouse == null) {
      await _loadMediaHouse();
    }
    if (!mounted) return;

    final success = await WithdrawDialog.show(
      context,
      availableBalance: availableBalance,
      mediaHouse: _mediaHouse,
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawal request submitted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      context.read<WalletProvider>().load(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().getTheme;
    final provider = context.watch<WalletProvider>();
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    final balance = provider.summary?.availableBalance ?? 0;
    final canWithdraw = balance > 0 && !provider.isLoadingSummary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => provider.load(refresh: true),
        child: ListView(
          padding: EdgeInsets.all(isNarrow ? 12 : 24),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        color: theme.primaryColor, size: 30),
                    const SizedBox(width: 10),
                    Text('Wallet',
                        style: TextStyle(
                            color: theme.canvasColor,
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: canWithdraw
                          ? () => _openWithdrawDialog(balance)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.arrow_circle_up_outlined, size: 18),
                      label: const Text('Withdraw Amount',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      tooltip: 'Refresh wallet',
                      onPressed: provider.isLoadingSummary ||
                              provider.isLoadingTransactions
                          ? null
                          : () => provider.load(refresh: true),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Only completed amounts already credited by the backend are shown.',
              style: TextStyle(color: theme.canvasColor.withValues(alpha: .65)),
            ),
            const SizedBox(height: 20),
            _summary(provider, theme),
            const SizedBox(height: 20),
            _filters(provider, theme),
            const SizedBox(height: 16),
            _transactions(provider, theme),
            const SizedBox(height: 28),
            _movieTransactionsSection(provider, theme),
          ],
        ),
      ),
    );
  }

  Widget _summary(WalletProvider provider, ThemeData theme) {
    if (provider.isLoadingSummary && provider.summary == null) {
      return const SizedBox(
          height: 130, child: Center(child: CircularProgressIndicator()));
    }
    if (provider.summaryError != null && provider.summary == null) {
      return _errorCard(provider.summaryError!, provider.loadSummary, theme);
    }
    final value = provider.summary ?? ProductionHouseWalletSummary.empty;

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100
          ? 5
          : constraints.maxWidth >= 700
              ? 3
              : constraints.maxWidth >= 430
                  ? 2
                  : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: width,
                child: _summaryCard(
                  'Available Balance',
                  _currency(value.availableBalance),
                  Icons.account_balance_wallet_outlined,
                  theme,
                  actionButton: value.availableBalance > 0
                      ? InkWell(
                          onTap: () => _openWithdrawDialog(value.availableBalance),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_forward_rounded,
                                    size: 13, color: theme.primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Withdraw',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              SizedBox(
                width: width,
                child: _summaryCard('Total Credited',
                    _currency(value.totalCreditedAmount), Icons.add_circle_outline, theme),
              ),
              SizedBox(
                width: width,
                child: _summaryCard('Total Debited',
                    _currency(value.totalDebitedAmount), Icons.remove_circle_outline, theme),
              ),
              SizedBox(
                width: width,
                child: _summaryCard(
                    'Held Amount', _currency(value.heldAmount), Icons.lock_clock_outlined, theme),
              ),
              SizedBox(
                width: width,
                child: _summaryCard(
                    'Transactions',
                    NumberFormat.decimalPattern('en_IN')
                        .format(value.totalTransactions),
                    Icons.receipt_long_outlined,
                    theme),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _meta('Wallet status', value.walletStatus, theme),
              _meta('Last credit', _dateTime(value.lastCreditDate), theme),
            ],
          ),
        ],
      );
    });
  }

  Widget _summaryCard(
    String label,
    String value,
    IconData icon,
    ThemeData theme, {
    Widget? actionButton,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: theme.primaryColor),
            if (actionButton != null) actionButton,
          ],
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: TextStyle(
                  color: theme.canvasColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: theme.canvasColor.withValues(alpha: .65), fontSize: 12)),
      ]),
    );
  }

  Widget _filters(WalletProvider provider, ThemeData theme) {
    return Card(
      color: theme.cardColor,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text('Transaction filters',
            style: TextStyle(
                color: theme.canvasColor, fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth < 650
                ? constraints.maxWidth
                : (constraints.maxWidth - 24) / 3;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: width,
                  child: _textField(_search, 'Transaction or settlement ID',
                      Icons.search, theme)),
              SizedBox(
                  width: width,
                  child: _dropdown('Transaction type', _type, _types,
                      (value) => setState(() => _type = value), theme)),
              SizedBox(
                  width: width,
                  child: _dropdown('Status', _status, _statuses,
                      (value) => setState(() => _status = value), theme)),
              SizedBox(
                  width: width,
                  child: _dropdown('Credit or debit', _entryType,
                      const ['CREDIT', 'DEBIT'],
                      (value) => setState(() => _entryType = value), theme)),
              SizedBox(
                  width: width,
                  child: _dateField('From date', _fromDate,
                      (value) => setState(() => _fromDate = value), theme)),
              SizedBox(
                  width: width,
                  child: _dateField('To date', _toDate,
                      (value) => setState(() => _toDate = value), theme)),
              SizedBox(
                  width: width,
                  child: _textField(
                      _minAmount, 'Minimum amount', Icons.currency_rupee, theme,
                      number: true)),
              SizedBox(
                  width: width,
                  child: _textField(
                      _maxAmount, 'Maximum amount', Icons.currency_rupee, theme,
                      number: true)),
            ]);
          }),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 8, children: [
            ElevatedButton.icon(
              onPressed: provider.isLoadingTransactions
                  ? null
                  : () => _apply(provider),
              icon: const Icon(Icons.filter_alt_outlined),
              label: const Text('Apply Filter'),
            ),
            OutlinedButton.icon(
              onPressed: provider.isLoadingTransactions
                  ? null
                  : () => _reset(provider),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset Filter'),
            ),
            TextButton.icon(
              onPressed: provider.isLoadingTransactions
                  ? null
                  : () {
                      _search.clear();
                      _apply(provider);
                    },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _transactions(WalletProvider provider, ThemeData theme) {
    if (provider.isLoadingTransactions) {
      return const SizedBox(
          height: 220, child: Center(child: CircularProgressIndicator()));
    }
    if (provider.transactionsError != null) {
      return _errorCard(provider.transactionsError!,
          () => provider.loadTransactions(page: provider.page), theme);
    }
    if (provider.transactions.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: theme.cardColor, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined,
              size: 44, color: theme.canvasColor.withValues(alpha: .45)),
          const SizedBox(height: 10),
          Text('No wallet transactions found.',
              style: TextStyle(color: theme.canvasColor)),
        ]),
      );
    }
    return Card(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: Text('Wallet transactions',
                    style: TextStyle(
                        color: theme.canvasColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold))),
            Text('${provider.totalElements} records',
                style: TextStyle(
                    color: theme.canvasColor.withValues(alpha: .65))),
          ]),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('ID / Reference')),
                DataColumn(label: Text('Date & time')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Description')),
                DataColumn(label: Text('Credit')),
                DataColumn(label: Text('Debit')),
                DataColumn(label: Text('Balance after')),
                DataColumn(label: Text('Settlement')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Action')),
              ],
              rows: provider.transactions
                  .map((item) => DataRow(
                        onSelectChanged: (_) => _details(item, theme),
                        cells: [
                          DataCell(Text(
                              '${item.walletTransactionId}\n${item.transactionReference}')),
                          DataCell(Text(_dateTime(item.transactionDate))),
                          DataCell(Text(_label(item.transactionType))),
                          DataCell(SizedBox(
                              width: 230,
                              child: Text(item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis))),
                          DataCell(Text(
                              item.creditAmount > 0
                                  ? '+${_currency(item.creditAmount)}'
                                  : '-',
                              style: const TextStyle(color: Colors.green))),
                          DataCell(Text(
                              item.debitAmount > 0
                                  ? '-${_currency(item.debitAmount)}'
                                  : '-',
                              style: const TextStyle(color: Colors.red))),
                          DataCell(Text(_currency(item.balanceAfter))),
                          DataCell(Text(item.settlementReference ??
                              item.settlementId?.toString() ??
                              '-')),
                          DataCell(_statusBadge(item.status)),
                          DataCell(IconButton(
                              tooltip: 'View details',
                              onPressed: () => _details(item, theme),
                              icon: const Icon(Icons.visibility_outlined))),
                        ],
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            DropdownButton<int>(
              value: provider.size,
              items: const [10, 20, 50]
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text('$value rows')))
                  .toList(),
              onChanged: (value) {
                if (value != null) provider.changePageSize(value);
              },
            ),
            const SizedBox(width: 16),
            Text('Page ${provider.page + 1} of ${provider.totalPages}'),
            IconButton(
                onPressed: provider.first ? null : provider.previousPage,
                icon: const Icon(Icons.chevron_left)),
            IconButton(
                onPressed: provider.last ? null : provider.nextPage,
                icon: const Icon(Icons.chevron_right)),
          ]),
        ]),
      ),
    );
  }

  Future<void> _apply(WalletProvider provider) async {
    final min = double.tryParse(_minAmount.text.trim());
    final max = double.tryParse(_maxAmount.text.trim());
    if ((_fromDate != null &&
            _toDate != null &&
            _fromDate!.isAfter(_toDate!)) ||
        (min != null && max != null && min > max)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid date and amount range.')));
      return;
    }
    await provider.applyFilter(WalletTransactionFilter(
      search: _search.text.trim(),
      transactionType: _type,
      status: _status,
      entryType: _entryType,
      fromDate: _fromDate,
      toDate: _toDate,
      minAmount: min,
      maxAmount: max,
    ));
  }

  Future<void> _reset(WalletProvider provider) async {
    setState(() {
      _search.clear();
      _minAmount.clear();
      _maxAmount.clear();
      _type = null;
      _status = null;
      _entryType = null;
      _fromDate = null;
      _toDate = null;
    });
    await provider.resetFilter();
  }

  void _details(WalletTransaction item, ThemeData theme) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Wallet transaction details',
            style: TextStyle(color: theme.canvasColor)),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 20,
              runSpacing: 14,
              children: [
                _detail('Transaction ID', '${item.walletTransactionId}', theme),
                _detail('Reference', item.transactionReference, theme),
                _detail('Production house',
                    item.productionHouseName ?? '${item.productionHouseId}', theme),
                _detail('Type', _label(item.transactionType), theme),
                _detail('Date', _dateTime(item.transactionDate), theme),
                _detail('Credit',
                    item.creditAmount > 0 ? _currency(item.creditAmount) : '-', theme),
                _detail('Debit',
                    item.debitAmount > 0 ? _currency(item.debitAmount) : '-', theme),
                _detail('Balance before', _currency(item.balanceBefore), theme),
                _detail('Balance after', _currency(item.balanceAfter), theme),
                _detail('Status', item.status, theme),
                _detail('Description', item.description, theme),
                _detail('Settlement ID', item.settlementId?.toString() ?? '-', theme),
                _detail('Settlement reference',
                    item.settlementReference ?? '-', theme),
                _detail('Settlement period', item.settlementPeriod ?? '-', theme),
                _detail('Wallet credit date',
                    _dateTime(item.walletCreditDate), theme),
              ],
            ),
          ),
        ),
        actions: [
          if (item.isSettlementCredit &&
              item.settlementReference?.isNotEmpty == true)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WeeklySettlementReportPage(
                      settlementBatchReference: item.settlementReference!,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('View Settlement Details'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detail(String label, String value, ThemeData theme) => SizedBox(
        width: 270,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: theme.canvasColor.withValues(alpha: .6))),
          const SizedBox(height: 3),
          SelectableText(value,
              style: TextStyle(
                  color: theme.canvasColor, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _textField(TextEditingController controller, String label,
          IconData icon, ThemeData theme,
          {bool number = false}) =>
      TextField(
        controller: controller,
        keyboardType:
            number ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder()),
      );

  Widget _dropdown(String label, String? value, List<String> values,
          ValueChanged<String?> changed, ThemeData theme) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: values
            .map((item) =>
                DropdownMenuItem(value: item, child: Text(_label(item))))
            .toList(),
        onChanged: changed,
      );

  Widget _dateField(String label, DateTime? value,
          ValueChanged<DateTime?> changed, ThemeData theme) =>
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (picked != null) changed(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.calendar_today_outlined),
              border: const OutlineInputBorder()),
          child: Text(value == null ? 'Any date' : DateFormat('dd MMM yyyy').format(value)),
        ),
      );

  Widget _errorCard(
          String message, Future<void> Function() retry, ThemeData theme) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: theme.cardColor, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message, style: TextStyle(color: theme.canvasColor))),
          TextButton(onPressed: retry, child: const Text('Retry')),
        ]),
      );

  Widget _meta(String label, String value, ThemeData theme) => Text(
      '$label: $value',
      style: TextStyle(color: theme.canvasColor.withValues(alpha: .7)));

  Widget _statusBadge(String status) {
    final normalized = status.toUpperCase();
    final color = normalized == 'COMPLETED' || normalized.contains('CREDITED')
        ? Colors.green
        : normalized == 'FAILED' ||
                normalized == 'CANCELLED' ||
                normalized == 'REVERSED'
            ? Colors.red
            : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(20)),
      child: Text(_label(status),
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _currency(dynamic value) => formatCurrency(value);

  String _dateTime(DateTime? value) => value == null
      ? 'Not available'
      : DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());

  String _label(String value) => value
      .split('_')
      .where((item) => item.isNotEmpty)
      .map((item) =>
          '${item.substring(0, 1).toUpperCase()}${item.substring(1).toLowerCase()}')
      .join(' ');

  Widget _movieTransactionsSection(WalletProvider provider, ThemeData theme) {
    final list = provider.movieTransactions;
    final isNarrow = MediaQuery.sizeOf(context).width < 600;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.movie_filter_outlined, color: theme.primaryColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Movie Revenue Transactions',
                    style: TextStyle(
                      color: theme.canvasColor,
                      fontSize: isNarrow ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (list.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${list.length} Items',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Itemized movie purchases and production house revenue share from user transactions.',
            style: TextStyle(
              fontSize: 12,
              color: theme.canvasColor.withValues(alpha: .65),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          if (provider.isLoadingMovieTransactions)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No movie transactions recorded yet.',
                  style: TextStyle(color: theme.canvasColor.withValues(alpha: .6)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _movieTransactionCard(list[index], theme),
            ),
        ],
      ),
    );
  }

  Widget _movieTransactionCard(MovieTransaction txn, ThemeData theme) {
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
                child: Row(
                  children: [
                    const Icon(Icons.movie_outlined, size: 18, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        txn.movieTitle ?? 'Movie #${txn.movieId ?? ""}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(txn.status ?? 'PENDING'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Txn: ${txn.transactionId ?? "—"} • ${_movieDate(txn.dateFrom)} to ${_movieDate(txn.dateTo)}',
            style: TextStyle(
              fontSize: 11,
              color: theme.canvasColor.withValues(alpha: .6),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _metricText('Customer Paid', _currency(txn.customerPayment), theme),
              _metricText('Base Amount', _currency(txn.baseAmount), theme),
              _metricText('GST', _currency(txn.gstAmount), theme),
              _metricText('Gateway Fee', _currency(txn.gatewayFee), theme),
              _metricText('Admin Share', _currency(txn.adminRevenueShare), theme),
              _metricText(
                'Production House Share',
                _currency(txn.mediaHouseRevenueShare),
                theme,
                highlightColor: Colors.green.shade600,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricText(String label, String value, ThemeData theme, {Color? highlightColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: theme.canvasColor.withValues(alpha: .6),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: highlightColor ?? theme.canvasColor,
          ),
        ),
      ],
    );
  }

  String _movieDate(int? epochMs) {
    if (epochMs == null || epochMs <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    return DateFormat('dd MMM yyyy').format(dt);
  }

}
