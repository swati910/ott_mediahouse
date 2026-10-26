import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_house/domain/entities/content.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../../core/utils/currency_formatter.dart';

import '../../../../../data/models/response/graphResponse.dart';
import '../../../../provider/mediaHouseProvider.dart';
import '../../../../provider/themeProvider.dart';
import '../../../../provider/videoProvider.dart';

class MovieRevenueGraph extends StatefulWidget {
  final String title;
  final String yAxisLabel;
  final int graphNumber;
  final Content contentId;
  final List<String> metrics;
  final bool canPop;

  const MovieRevenueGraph({
    super.key,
    required this.title,
    required this.yAxisLabel,
    required this.metrics,
    this.canPop = false,
    required this.graphNumber,
    required this.contentId,
  });

  @override
  State<MovieRevenueGraph> createState() => _MovieRevenueGraphState();
}

class _MovieRevenueGraphState extends State<MovieRevenueGraph> {
  DateTimeRange? selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  DateTime get today => DateTime.now();
  DateTime? startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime? endDate = DateTime.now();
  String activeButton = 'Week';

  bool _isLoading = false;
  double _revenueTotal = 0;
  double _viewsTotal = 0;
  double _likesTotal = 0;

  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _talukaController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchGraphData(
        0,
        DateTime.now().subtract(const Duration(days: 7)),
        DateTime.now(),
      );
    });
  }

  @override
  void dispose() {
    _countryController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _talukaController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  int _currentRangeIndex() {
    if (activeButton == 'Month') return 1;
    if (activeButton == 'Year') return 2;
    if (activeButton == 'Custom Dates') return 3;
    return 0;
  }

  Future<void> _applyCurrentFilters() async {
    if (startDate == null || endDate == null) return;
    await _fetchGraphData(_currentRangeIndex(), startDate!, endDate!);
  }

  Future<void> _fetchGraphData(
      int selectedTimeRange, DateTime startDate, DateTime endDate) async {
    final videoProvider = Provider.of<VideoProvider>(context, listen: false);
    final startDateString = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateString = DateFormat('yyyy-MM-dd').format(endDate);

    final country = _countryController.text.trim().isEmpty
        ? null
        : _countryController.text.trim();
    final state = _stateController.text.trim().isEmpty
        ? null
        : _stateController.text.trim();
    final district = _districtController.text.trim().isEmpty
        ? null
        : _districtController.text.trim();
    final taluka = _talukaController.text.trim().isEmpty
        ? null
        : _talukaController.text.trim();
    final city = _cityController.text.trim().isEmpty
        ? null
        : _cityController.text.trim();

    setState(() => _isLoading = true);
    try {
      await videoProvider.contentRevenueGraph(
        selectedTimeRange,
        widget.contentId.id!,
        startDateString,
        endDateString,
        contentType: widget.contentId.type,
        country: country,
        state: state,
        district: district,
        taluka: taluka,
        city: city,
      );

      final totals = await videoProvider.fetchContentMetricGraphData(
        selectedTimeRange,
        widget.contentId.id!,
        startDateString,
        endDateString,
        contentType: widget.contentId.type,
        country: country,
        state: state,
        district: district,
        taluka: taluka,
        city: city,
      );
      final totalValue = _sumValues(totals);

      if (mounted) {
        setState(() {
          _revenueTotal = totalValue;
          _viewsTotal = totalValue;
          _likesTotal = totalValue;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _sumValues(List<GraphData> data) {
    double total = 0;
    for (final row in data) {
      total += row.value ?? 0;
    }
    return total;
  }

  int _xLabelStep(int count) {
    if (count <= 12) return 1;
    if (count <= 24) return 2;
    if (count <= 45) return 3;
    if (count <= 75) return 5;
    if (count <= 120) return 7;
    return 10;
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 560,
            child: DateRangePickerDialog(
              firstDate: DateTime(2020),
              lastDate: today,
              initialDateRange:
                  activeButton == 'Custom Dates' ? selectedDateRange : null,
              helpText: 'Select Custom Date Range',
              confirmText: 'Apply',
              cancelText: 'Cancel',
            ),
          ),
        );
      },
    );
    if (!mounted || picked == null) return;

    setState(() {
      selectedDateRange = picked;
      activeButton = 'Custom Dates';
      startDate = picked.start;
      endDate = picked.end;
    });
    await _fetchGraphData(3, picked.start, picked.end);
  }

  Future<void> _setDateRange(String label, int days) async {
    final selectedTimeRange = label == 'Week'
        ? 0
        : label == 'Month'
            ? 1
            : 2;
    final calculatedEndDate = DateTime.now();
    final calculatedStartDate =
        calculatedEndDate.subtract(Duration(days: days));

    setState(() {
      activeButton = label;
      startDate = calculatedStartDate;
      endDate = calculatedEndDate;
      selectedDateRange =
          DateTimeRange(start: calculatedStartDate, end: calculatedEndDate);
    });
    await _fetchGraphData(
        selectedTimeRange, calculatedStartDate, calculatedEndDate);
  }

  Future<void> _showLocationDialog(ThemeData theme) async {
    final mediaHouseProvider =
        Provider.of<MediaHouseProvider>(context, listen: false);
    await mediaHouseProvider.fetchCustomGraphCountriesIfNeeded();
    if (_countryController.text.trim().isNotEmpty &&
        mediaHouseProvider.customGraphStateOptions.isEmpty) {
      await mediaHouseProvider
          .fetchCustomGraphStatesByCountry(_countryController.text.trim());
    }
    if (!mounted) return;

    final cCountry = TextEditingController(text: _countryController.text);
    final cState = TextEditingController(text: _stateController.text);
    final cDistrict = TextEditingController(text: _districtController.text);
    final cTaluka = TextEditingController(text: _talukaController.text);
    final cCity = TextEditingController(text: _cityController.text);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                width: MediaQuery.of(context).size.width > 900
                    ? 600
                    : MediaQuery.of(context).size.width > 600
                        ? 500
                        : MediaQuery.of(context).size.width * 0.9,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Location Wise Filters',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(
                              Icons.close,
                              color: theme.canvasColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildSearchableSelectorField(
                        context: context,
                        theme: theme,
                        label: 'Country',
                        value: cCountry.text.trim().isEmpty
                            ? null
                            : cCountry.text.trim(),
                        isLoading:
                            mediaHouseProvider.isLoadingCustomGraphCountries,
                        onTap: () async {
                          final selectedCountry = await _showSearchPickerDialog(
                            context: context,
                            theme: theme,
                            title: 'Search Country',
                            options:
                                mediaHouseProvider.customGraphCountryOptions,
                            initialValue: cCountry.text,
                          );
                          if (selectedCountry == null) return;
                          cCountry.text = selectedCountry.trim();
                          cState.clear();
                          cDistrict.clear();
                          cTaluka.clear();
                          cCity.clear();
                          await mediaHouseProvider
                              .fetchCustomGraphStatesByCountry(
                                  cCountry.text.trim());
                          if (dialogContext.mounted) {
                            setDialogState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildSearchableSelectorField(
                        context: context,
                        theme: theme,
                        label: 'State',
                        value: cState.text.trim().isEmpty
                            ? null
                            : cState.text.trim(),
                        isLoading:
                            mediaHouseProvider.isLoadingCustomGraphStates,
                        enabled: cCountry.text.trim().isNotEmpty,
                        onTap: () async {
                          final selectedState = await _showSearchPickerDialog(
                            context: context,
                            theme: theme,
                            title: 'Search State',
                            options: mediaHouseProvider.customGraphStateOptions,
                            initialValue: cState.text,
                          );
                          if (selectedState == null) return;
                          cState.text = selectedState.trim();
                          cDistrict.clear();
                          cTaluka.clear();
                          cCity.clear();
                          if (dialogContext.mounted) {
                            setDialogState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildDialogTextField(
                        theme,
                        'District',
                        cDistrict,
                        enabled: cState.text.trim().isNotEmpty,
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 8),
                      _buildDialogTextField(
                        theme,
                        'Taluka',
                        cTaluka,
                        enabled: cDistrict.text.trim().isNotEmpty,
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 8),
                      _buildDialogTextField(
                        theme,
                        'City',
                        cCity,
                        enabled: cTaluka.text.trim().isNotEmpty,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (cCountry.text.trim().isEmpty) {
                                  _showError('Please select Country');
                                  return;
                                }

                                _countryController.text = cCountry.text.trim();
                                _stateController.text = cState.text.trim();
                                _districtController.text =
                                    cDistrict.text.trim();
                                _talukaController.text = cTaluka.text.trim();
                                _cityController.text = cCity.text.trim();

                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                                if (mounted) {
                                  setState(() {});
                                  await _applyCurrentFilters();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    cCountry.dispose();
    cState.dispose();
    cDistrict.dispose();
    cTaluka.dispose();
    cCity.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: true).getTheme;
    final hasDates = startDate != null && endDate != null;
    final rangeText = hasDates
        ? '${DateFormat.yMMMd().format(startDate!)} - ${DateFormat.yMMMd().format(endDate!)}'
        : 'Select Date Range';

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          widget.canPop
              ? Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios_sharp,
                        color: theme.canvasColor,
                      ),
                    ),
                  ],
                )
              : const SizedBox(height: 5),
          Text(
            'Revenue Graph',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              rangeText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Visibility(
            visible: false,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(theme,
                    'Revenue Total: ${formatAmount(_revenueTotal)}'),
                _chip(theme, 'Views Total: ${_viewsTotal.toStringAsFixed(0)}'),
                _chip(theme, 'Likes Total: ${_likesTotal.toStringAsFixed(0)}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: theme.dividerColor.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showLocationDialog(theme),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Location'),
                ),
                const Spacer(),
                if (_isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.primaryColor,
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _applyCurrentFilters,
                  icon: const Icon(Icons.search_rounded, size: 18),
                ),
                IconButton(
                  onPressed: () async {
                    _countryController.clear();
                    _stateController.clear();
                    _districtController.clear();
                    _talukaController.clear();
                    _cityController.clear();
                    setState(() {});
                    await _applyCurrentFilters();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildActiveFilterChips(theme),
          const SizedBox(height: 10),
          Expanded(
            child: Consumer<VideoProvider>(
              builder: (context, provider, child) {
                final indexedPoints =
                    provider.chartData.asMap().entries.toList();
                final labelStep = _xLabelStep(indexedPoints.length);
                final lastIndex =
                    indexedPoints.isEmpty ? 0 : indexedPoints.length - 1;
                return SfCartesianChart(
                  primaryXAxis: NumericAxis(
                    title: AxisTitle(
                      text: '<-------------- Time -------------->',
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    interval: 1,
                    decimalPlaces: 0,
                    axisLabelFormatter: (details) {
                      final index = details.value.round();
                      if (index < 0 || index >= indexedPoints.length) {
                        return ChartAxisLabel('', details.textStyle);
                      }
                      final shouldShow = index == 0 ||
                          index == lastIndex ||
                          (index % labelStep == 0);
                      final label = shouldShow
                          ? (indexedPoints[index].value.label ?? '')
                          : '';
                      return ChartAxisLabel(label, details.textStyle);
                    },
                  ),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries>[
                    LineSeries<MapEntry<int, GraphData>, int>(
                      dataSource: indexedPoints,
                      xValueMapper: (entry, _) => entry.key,
                      yValueMapper: (entry, _) => entry.value.value ?? 0,
                      color: theme.primaryColor,
                      markerSettings: MarkerSettings(
                        isVisible: true,
                        color: theme.primaryColor,
                        shape: DataMarkerType.circle,
                      ),
                      width: 3,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _dateBtn(theme, 'Week', 7),
              _dateBtn(theme, 'Month', 30),
              _dateBtn(theme, 'Year', 365),
              _dateBtn(theme, 'Custom Dates', 0, isCustom: true),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildDialogTextField(
    ThemeData theme,
    String label,
    TextEditingController controller, {
    bool enabled = true,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      style: TextStyle(
        color: enabled ? theme.canvasColor : Colors.grey,
      ),
      decoration: _filterInputDecoration(theme, label).copyWith(
        filled: true,
        fillColor: enabled ? null : Colors.grey.withOpacity(0.1),
      ),
    );
  }

  Widget _buildSearchableSelectorField({
    required BuildContext context,
    required ThemeData theme,
    required String label,
    required String? value,
    required VoidCallback onTap,
    bool enabled = true,
    bool isLoading = false,
  }) {
    final displayText = (value == null || value.trim().isEmpty)
        ? 'Select $label'
        : value.trim();
    return InkWell(
      onTap: enabled && !isLoading ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _filterInputDecoration(theme, label).copyWith(
          suffixIcon: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.search_rounded, size: 18),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: enabled
                ? theme.canvasColor
                : theme.canvasColor.withValues(alpha: 0.4),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<String?> _showSearchPickerDialog({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required List<String> options,
    String initialValue = '',
  }) async {
    final searchController = TextEditingController(text: initialValue);
    List<String> filtered = List<String>.from(options);

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void applyFilter(String query) {
              final q = query.trim().toLowerCase();
              setDialogState(() {
                filtered = options
                    .where((item) => item.toLowerCase().contains(q))
                    .toList(growable: false);
              });
            }

            return Dialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: SizedBox(
                width: 420,
                height: 500,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.canvasColor,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(Icons.close, color: theme.canvasColor),
                          ),
                        ],
                      ),
                      TextField(
                        controller: searchController,
                        onChanged: applyFilter,
                        decoration: _filterInputDecoration(theme, 'Search'),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No result found',
                                  style: TextStyle(
                                    color: theme.canvasColor
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color:
                                      theme.dividerColor.withValues(alpha: 0.4),
                                ),
                                itemBuilder: (context, index) {
                                  final value = filtered[index];
                                  return ListTile(
                                    title: Text(
                                      value,
                                      style:
                                          TextStyle(color: theme.canvasColor),
                                    ),
                                    onTap: () =>
                                        Navigator.pop(dialogContext, value),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
    return selected;
  }

  InputDecoration _filterInputDecoration(ThemeData theme, String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.primaryColor, width: 1.2),
      ),
    );
  }

  Widget _chip(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.canvasColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActiveFilterChips(ThemeData theme) {
    final chips = <String>[];
    if (_countryController.text.trim().isNotEmpty) {
      chips.add('Country: ${_countryController.text.trim()}');
    }
    if (_stateController.text.trim().isNotEmpty) {
      chips.add('State: ${_stateController.text.trim()}');
    }
    if (_districtController.text.trim().isNotEmpty) {
      chips.add('District: ${_districtController.text.trim()}');
    }
    if (_talukaController.text.trim().isNotEmpty) {
      chips.add('Taluka: ${_talukaController.text.trim()}');
    }
    if (_cityController.text.trim().isNotEmpty) {
      chips.add('City: ${_cityController.text.trim()}');
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children:
            chips.map((chip) => _chip(theme, chip)).toList(growable: false),
      ),
    );
  }

  Widget _dateBtn(ThemeData theme, String label, int days,
      {bool isCustom = false}) {
    final isActive = activeButton == label;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: isCustom ? _pickDateRange : () => _setDateRange(label, days),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? theme.primaryColor : theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? theme.primaryColor : Colors.grey,
            width: 0.4,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(color: isActive ? Colors.white : theme.canvasColor),
        ),
      ),
    );
  }
}
