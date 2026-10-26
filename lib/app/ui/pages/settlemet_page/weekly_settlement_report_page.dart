import 'package:flutter/material.dart';
import 'package:media_house/app/core/utils/sharepreferences.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/ui/pages/dashboard_page/components/settlementCards.dart';
import 'package:media_house/data/models/response/weekly_settlement_report.dart';
import 'package:media_house/data/services/settlement_service.dart';
import 'package:provider/provider.dart';

class WeeklySettlementReportPage extends StatefulWidget {
  final String settlementBatchReference;
  const WeeklySettlementReportPage({
    super.key,
    required this.settlementBatchReference,
  });

  @override
  State<WeeklySettlementReportPage> createState() =>
      _WeeklySettlementReportPageState();
}

class _WeeklySettlementReportPageState
    extends State<WeeklySettlementReportPage> {
  final SettlementService _service = SettlementService();
  WeeklySettlementReportData? _report;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final mediaHouse = await LocalSharePreferences().getMediaHouse();
    final id = mediaHouse?.id;
    if (id == null || id <= 0) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Media house ID is unavailable. Please refresh your profile.';
        });
      }
      return;
    }
    try {
      final response = await _service.getWeeklySettlementReport(
          id, widget.settlementBatchReference);
      if (mounted) {
        setState(() {
          _report = response.data;
          _loading = false;
        });
      }
    } on SettlementServiceException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().getTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settlement Report')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : _error != null
              ? _errorView(theme)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: _content(theme, _report!),
                  ),
                ),
    );
  }

  Widget _errorView(ThemeData theme) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 44, color: theme.primaryColor),
          const SizedBox(height: 12),
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.canvasColor)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry')),
        ]),
      );

  List<Widget> _content(ThemeData theme, WeeklySettlementReportData report) {
    final beneficiary = report.beneficiary;
    return [
      _panel(theme, [
        Text(report.title.isEmpty ? 'Weekly Settlement Report' : report.title,
            style: TextStyle(
                color: theme.primaryColor,
                fontSize: 24,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _row(
            theme,
            'Settlement batch reference',
            report.settlementBatchReference.isEmpty
                ? widget.settlementBatchReference
                : report.settlementBatchReference),
        _row(theme, 'Settlement status', report.settlementStatus),
        _row(theme, 'Beneficiary name', beneficiary?.beneficiaryName ?? 'N/A'),
        _row(theme, 'Beneficiary type', beneficiary?.beneficiaryType ?? 'N/A'),
        _row(theme, 'Report type', report.reportType),
      ]),
      if (!report.hasCalculations)
        _panel(theme, [
          Text(
            'No settlement calculation details are available for this report.',
            style: TextStyle(color: theme.canvasColor),
          )
        ]),
      if (report.summaryCards.isNotEmpty)
        _summarySection(theme, report.summaryCards),
      ...report.sections.map((section) => _entrySection(
          theme,
          section.title.isEmpty ? 'Report section' : section.title,
          section.entries.isEmpty
              ? _mapEntries(section.fields)
              : section.entries)),
      if (report.beneficiarySettlementSummary.isNotEmpty)
        _entrySection(theme, 'Beneficiary settlement summary',
            report.beneficiarySettlementSummary),
      if (report.taxAndChargeSummary.isNotEmpty)
        _entrySection(theme, 'Tax and charge summary',
            _mapEntries(report.taxAndChargeSummary)),
      if (report.finalSummary.isNotEmpty)
        _entrySection(theme, 'Final summary', report.finalSummary,
            prominent: true),
    ];
  }

  Widget _summarySection(ThemeData theme, List<ReportEntry> entries) =>
      _panel(theme, [
        Text('Summary',
            style: TextStyle(
                color: theme.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 3
              : constraints.maxWidth >= 560
                  ? 2
                  : 1;
          final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
          return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: entries
                  .expand(_displayFields)
                  .map((field) => SizedBox(
                        width: width,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor
                                .withValues(alpha: .45),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    theme.dividerColor.withValues(alpha: .22)),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_label(field.key),
                                    style: TextStyle(
                                        color: theme.canvasColor
                                            .withValues(alpha: .7))),
                                const SizedBox(height: 8),
                                Text(_formatValue(field.key, field.value),
                                    style: TextStyle(
                                        color: theme.canvasColor,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800)),
                              ]),
                        ),
                      ))
                  .toList(growable: false));
        }),
      ]);

  Widget _entrySection(ThemeData theme, String title, List<ReportEntry> entries,
          {bool prominent = false}) =>
      _panel(theme, [
        Text(title,
            style: TextStyle(
                color: theme.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...entries.expand((entry) => _displayFields(entry).map((field) => _row(
            theme, field.key, _formatValue(field.key, field.value),
            prominent: prominent || _isFinalPayable(field.key)))),
      ]);

  List<MapEntry<String, dynamic>> _displayFields(ReportEntry entry) {
    if (entry.label.isNotEmpty && entry.value != null) {
      return [MapEntry(entry.label, entry.value)];
    }
    return _flattenFields(entry.fields);
  }

  List<MapEntry<String, dynamic>> _flattenFields(Map<String, dynamic> fields,
      [String? parent]) {
    final result = <MapEntry<String, dynamic>>[];
    for (final field in fields.entries) {
      final key = parent == null ? field.key : '$parent ${field.key}';
      if (field.value is Map) {
        result.addAll(
            _flattenFields(Map<String, dynamic>.from(field.value as Map), key));
      } else if (field.value is List) {
        final values = field.value as List;
        if (values.every((item) => item is! Map && item is! List)) {
          result.add(MapEntry(key, values.join(', ')));
        }
      } else if (field.value != null &&
          !_metadataKeys.contains(field.key.toLowerCase())) {
        result.add(MapEntry(key, field.value));
      }
    }
    return result;
  }

  static const _metadataKeys = {
    'label',
    'title',
    'name',
    'key',
    'description',
    'displayname',
    'metric',
    'type',
    'valuetype',
    'currency'
  };

  List<ReportEntry> _mapEntries(Map<String, dynamic> map) => map.entries
      .map((entry) => ReportEntry({'label': entry.key, 'value': entry.value}))
      .toList(growable: false);

  Widget _panel(ThemeData theme, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: .3))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _row(ThemeData theme, String label, String value,
          {bool prominent = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(_label(label),
                  style: TextStyle(
                      color: theme.canvasColor.withValues(alpha: .7)))),
          const SizedBox(width: 16),
          Expanded(
              child: Text(value.isEmpty ? 'N/A' : value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      color: prominent ? theme.primaryColor : theme.canvasColor,
                      fontWeight:
                          prominent ? FontWeight.w900 : FontWeight.w700))),
        ]),
      );

  String _label(String key) {
    if (key.toLowerCase() == 'grossrevenue') return 'Gross Revenue';
    return key.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (match) => '${match[1]} ${match[2]}');
  }

  bool _isFinalPayable(String key) =>
      key.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase() ==
      'finalpayableamount';

  String _formatValue(String key, dynamic value) {
    if (value == null) return 'N/A';
    final normalized = key.toLowerCase();
    final number = value is num ? value : num.tryParse(value.toString());
    if (number != null &&
        (normalized.contains('amount') ||
            normalized.contains('revenue') ||
            normalized.contains('payment') ||
            normalized.contains('charge') ||
            normalized.contains('deduction') ||
            normalized == 'tds' ||
            normalized.contains('commission') &&
                !normalized.contains('percentage'))) {
      return formatCurrency(number);
    }
    if (number != null && normalized.contains('percentage')) {
      return formatPercentage(number);
    }
    return value.toString();
  }
}
