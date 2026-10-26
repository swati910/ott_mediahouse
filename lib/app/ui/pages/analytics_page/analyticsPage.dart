import 'package:flutter/material.dart';
import '../../../core/content/content_type.dart';
import 'package:intl/intl.dart';
import 'package:media_house/app/provider/graphProvider.dart';
import 'package:media_house/app/provider/mediaHouseProvider.dart';
import 'package:media_house/app/ui/pages/movie%20details%20page/MovieDetailsPage.dart';
import 'package:media_house/app/widget/TopMoviesLineGraph.dart';
import 'package:media_house/app/widget/show_toast.dart';
import 'package:media_house/data/models/response/reportAndDataResponse.dart';
import 'package:provider/provider.dart';
import 'package:media_house/app/provider/themeProvider.dart';

import '../../../core/utils/sharepreferences.dart';
import '../../../core/utils/currency_formatter.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _isAscending = true;
  bool _sortByRevenue = true;
  final NumberFormat _numberFormat = NumberFormat("#,##0.##");
  String _reportContentType = 'ALL';
  String _reportCountry = '';
  String _reportState = '';
  String _reportAgeGroup = 'ALL';
  String _reportGender = 'ALL';
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _talukaController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  DateTimeRange? _reportDateRange;

  static const List<String> _contentTypeOptions = [
    'ALL',
    'MOVIE',
    'SHORT_FILM',
    'SERIES',
    'MINI SERIES'
  ];
  static const List<String> _ageGroupOptions = [
    'ALL',
    '13-17',
    '18-24',
    '25-34',
    '35-44',
    '45-54',
    '55+',
  ];
  static const List<String> _genderOptions = [
    'ALL',
    'male',
    'female',
    'other',
  ];

  void _toggleSortOrder() {
    setState(() {
      _isAscending = !_isAscending;
    });
  }

  void _toggleSortCriteria() {
    setState(() {
      _sortByRevenue = !_sortByRevenue;
    });
  }

  List<ReportAndDataObject> getSortedMovies(GraphProvider provider) {
    List<ReportAndDataObject> sortedMovies =
        List.from(provider.reportAndDataList);
    sortedMovies.sort((a, b) {
      if (_sortByRevenue) {
        return _isAscending
            ? _toDouble(a.netRevenue).compareTo(_toDouble(b.netRevenue))
            : _toDouble(b.netRevenue).compareTo(_toDouble(a.netRevenue));
      } else {
        return _isAscending
            ? (a.movieName ?? '').compareTo(b.movieName ?? '')
            : (b.movieName ?? '').compareTo(a.movieName ?? '');
      }
    });
    return sortedMovies;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _formatNumber(num value) {
    return _numberFormat.format(value);
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    var selectedThemeData =
        Provider.of<ThemeProvider>(context, listen: true).getTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selectedThemeData.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        selectedThemeData.primaryColor.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: selectedThemeData.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieTable(
      List<ReportAndDataObject> movies, ThemeData selectedThemeData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Content Performance",
                    style: TextStyle(
                      color: selectedThemeData.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${movies.length} records found",
                    style: TextStyle(
                      color:
                          selectedThemeData.canvasColor.withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _toggleSortCriteria,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(_sortByRevenue ? "Sort: Revenue" : "Sort: Name"),
                ),
                OutlinedButton.icon(
                  onPressed: _toggleSortOrder,
                  icon: Icon(_isAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded),
                  label: Text(_isAscending ? "Ascending" : "Descending"),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selectedThemeData.scaffoldBackgroundColor
                      .withValues(alpha: 0.38),
                  border: Border.all(
                    color:
                        selectedThemeData.dividerColor.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTableTheme(
                      data: DataTableThemeData(
                        headingRowColor: WidgetStatePropertyAll(
                          selectedThemeData.primaryColor.withValues(alpha: 0.1),
                        ),
                        dataRowColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return selectedThemeData.primaryColor
                                .withValues(alpha: 0.05);
                          }
                          return Colors.transparent;
                        }),
                        dividerThickness: 0.6,
                      ),
                      child: DataTable(
                        columnSpacing: 28,
                        horizontalMargin: 16,
                        headingRowHeight: 48,
                        dataRowMinHeight: 58,
                        dataRowMaxHeight: 68,
                        headingTextStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selectedThemeData.primaryColor,
                          fontSize: 12,
                        ),
                        dataTextStyle: TextStyle(
                          color: selectedThemeData.canvasColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        columns: [
                          DataColumn(label: _tableHeader("Content")),
                          DataColumn(label: _tableHeader("Release Date")),
                          DataColumn(
                            label: _tableHeader("Views"),
                            numeric: true,
                          ),
                          DataColumn(
                            label: _tableHeader("Price"),
                            numeric: true,
                          ),
                          DataColumn(
                            label: _tableHeader("Revenue"),
                            numeric: true,
                          ),
                          DataColumn(
                            label: _tableHeader("Net Revenue"),
                            numeric: true,
                          ),
                          DataColumn(label: _tableHeader("Details")),
                        ],
                        rows: movies.asMap().entries.map(
                          (entry) {
                            final index = entry.key;
                            final movie = entry.value;
                            return DataRow(
                              color: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.hovered)) {
                                  return selectedThemeData.primaryColor
                                      .withValues(alpha: 0.06);
                                }
                                return index.isEven
                                    ? selectedThemeData.cardColor
                                        .withValues(alpha: 0.32)
                                    : Colors.transparent;
                              }),
                              cells: [
                                DataCell(
                                    _contentCell(movie, selectedThemeData)),
                                DataCell(_tableText(
                                  movie.releasedDate == null
                                      ? '-'
                                      : DateFormat('dd MMM yyyy')
                                          .format(movie.releasedDate!),
                                )),
                                DataCell(_metricCell(
                                  _formatNumber(_toInt(movie.views)),
                                  Icons.visibility_outlined,
                                  selectedThemeData,
                                )),
                                DataCell(_moneyCell(
                                  "${movie.price ?? 0}",
                                  selectedThemeData,
                                )),
                                DataCell(_moneyCell(
                                  formatAmount(movie.revenue),
                                  selectedThemeData,
                                )),
                                DataCell(_moneyCell(
                                  formatAmount(movie.netRevenue),
                                  selectedThemeData,
                                )),
                                DataCell(
                                  TextButton.icon(
                                    onPressed: movie.views == null
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    MovieDetailsPage(
                                                  movieId: movie.views!,
                                                ),
                                              ),
                                            );
                                          },
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 15,
                                    ),
                                    label: const Text("Open"),
                                  ),
                                ),
                              ],
                            );
                          },
                        ).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _tableHeader(String label) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _tableText(String value) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _contentCell(
    ReportAndDataObject movie,
    ThemeData selectedThemeData,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 320),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: selectedThemeData.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.movie_creation_outlined,
              color: selectedThemeData.primaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              movie.movieName ?? '-',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selectedThemeData.canvasColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCell(
    String value,
    IconData icon,
    ThemeData selectedThemeData,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: selectedThemeData.primaryColor),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: selectedThemeData.canvasColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _moneyCell(String value, ThemeData selectedThemeData) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  DateTimeRange _defaultCurrentMonthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  @override
  void initState() {
    super.initState();
    _reportDateRange = _defaultCurrentMonthRange();
    _initData();
  }

  @override
  void dispose() {
    _districtController.dispose();
    _talukaController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final provider = Provider.of<GraphProvider>(context, listen: false);
    await _fetchDashboardSummary();
    await provider.fetchCountriesIfNeeded();
    await _applyReportFilters();
  }

  Future<void> _fetchDashboardSummary() async {
    final mediaHouse = await LocalSharePreferences().getMediaHouse();
    final mediaHouseId = mediaHouse?.id;
    if (mediaHouseId == null || mediaHouseId == 0) return;
    if (!mounted) return;
    await context
        .read<MediaHouseProvider>()
        .fetchMediaHouseDashboardData(mediaHouseId);
  }

  Future<void> _applyReportFilters() async {
    final district = _districtController.text.trim();
    final taluka = _talukaController.text.trim();
    final city = _cityController.text.trim();

    if (_reportCountry.isEmpty &&
        (_reportState.isNotEmpty ||
            district.isNotEmpty ||
            taluka.isNotEmpty ||
            city.isNotEmpty)) {
      CustomToast.show(context, "Select country first.", isSuccess: false);
      return;
    }
    if (_reportState.isEmpty &&
        (district.isNotEmpty || taluka.isNotEmpty || city.isNotEmpty)) {
      CustomToast.show(context, "Select state after country.",
          isSuccess: false);
      return;
    }
    if (district.isEmpty && (taluka.isNotEmpty || city.isNotEmpty)) {
      CustomToast.show(context, "Enter district before taluka/city.",
          isSuccess: false);
      return;
    }
    if (taluka.isEmpty && city.isNotEmpty) {
      CustomToast.show(context, "Enter taluka before city.", isSuccess: false);
      return;
    }

    final provider = Provider.of<GraphProvider>(context, listen: false);
    await provider.getReportAndData(
      context,
      contentType: _reportContentType,
      country: _reportCountry,
      state: _reportState,
      district: district,
      taluka: taluka,
      city: city,
      startDate: _reportDateRange?.start,
      endDate: _reportDateRange?.end,
      ageGroup: _reportAgeGroup,
      gender: _reportGender,
    );
  }

  Future<void> _clearReportFilters() async {
    final provider = Provider.of<GraphProvider>(context, listen: false);
    setState(() {
      _reportContentType = 'ALL';
      _reportCountry = '';
      _reportState = '';
      _reportAgeGroup = 'ALL';
      _reportGender = 'ALL';
      _districtController.clear();
      _talukaController.clear();
      _cityController.clear();
      _reportDateRange = _defaultCurrentMonthRange();
    });
    provider.clearStateOptions();
    await _applyReportFilters();
  }

  Future<void> _pickReportDateRange() async {
    final initial = _reportDateRange ?? _defaultCurrentMonthRange();
    final picked = await showDialog<DateTimeRange>(
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
              lastDate: DateTime.now(),
              initialDateRange: initial,
              helpText: 'Select Date Range',
              confirmText: 'Apply',
              cancelText: 'Cancel',
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _reportDateRange = picked;
    });
  }

  Future<String?> _showSearchableSelectionDialog({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String initialValue,
    required ThemeData theme,
  }) async {
    final searchController = TextEditingController();
    var filtered = List<String>.from(options);

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                width: 420,
                height: 480,
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
                                fontWeight: FontWeight.w600,
                                color: theme.canvasColor,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(
                              Icons.close,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      TextField(
                        controller: searchController,
                        onChanged: (value) {
                          final query = value.trim().toLowerCase();
                          setStateDialog(() {
                            filtered = options
                                .where((e) => e.toLowerCase().contains(query))
                                .toList();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Search...",
                          prefixIcon: Icon(
                            Icons.search,
                            color: theme.canvasColor,
                          ),
                          border: const OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext, ''),
                          child: Text(
                            "Clear Selection",
                            style: TextStyle(color: theme.primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  "No country found.",
                                  style: TextStyle(
                                    color: theme.primaryColor
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: theme.dividerColor
                                      .withValues(alpha: 0.35),
                                ),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final isSelected =
                                      item.trim() == initialValue.trim();
                                  return ListTile(
                                    title: Text(
                                      item,
                                      style:
                                          TextStyle(color: theme.canvasColor),
                                    ),
                                    trailing: isSelected
                                        ? Icon(Icons.check,
                                            color: theme.primaryColor)
                                        : null,
                                    onTap: () =>
                                        Navigator.pop(dialogContext, item),
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

  Widget _buildReportFilters(GraphProvider provider, ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width > 1100
            ? (width - 48) / 4
            : width > 700
                ? (width - 24) / 2
                : width;

        final dateLabel = _reportDateRange == null
            ? "Select Date Range"
            : "${DateFormat('dd MMM yyyy').format(_reportDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_reportDateRange!.end)}";

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: itemWidth,
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: theme.cardColor,
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _reportContentType,
                  dropdownColor: theme.cardColor,
                  style: TextStyle(color: theme.canvasColor),
                  decoration: InputDecoration(
                    labelText: "Content Type",
                    labelStyle: TextStyle(
                      color: theme.primaryColor.withValues(alpha: 0.75),
                    ),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  items: _contentTypeOptions
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            type == 'ALL'
                                ? type
                                : ContentTypeValue.displayLabel(type),
                            style: TextStyle(color: theme.canvasColor),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _reportContentType = value);
                  },
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () async {
                  final selected = await _showSearchableSelectionDialog(
                    context: context,
                    title: "Select Country",
                    options: provider.countryOptions,
                    initialValue: _reportCountry,
                    theme: theme,
                  );
                  if (selected == null) return;
                  final country = selected.trim();
                  setState(() {
                    _reportCountry = country;
                    _reportState = '';
                    _districtController.clear();
                    _talukaController.clear();
                    _cityController.clear();
                  });
                  if (country.isEmpty) {
                    provider.clearStateOptions();
                    return;
                  }
                  await provider.fetchStatesByCountry(country);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: "Country",
                    labelStyle: TextStyle(
                      color: theme.primaryColor.withValues(alpha: 0.75),
                    ),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.55),
                      ),
                    ),
                    suffixIcon: Icon(
                      Icons.search,
                      color: theme.primaryColor.withValues(alpha: 0.85),
                    ),
                  ),
                  child: Text(
                    _reportCountry.isEmpty ? "Search country" : _reportCountry,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: _reportCountry.isEmpty
                    ? null
                    : () async {
                        final selected = await _showSearchableSelectionDialog(
                          context: context,
                          title: "Select State",
                          options: provider.stateOptions,
                          initialValue: _reportState,
                          theme: theme,
                        );
                        if (selected == null) return;
                        setState(() {
                          _reportState = selected.trim();
                          _districtController.clear();
                          _talukaController.clear();
                          _cityController.clear();
                        });
                      },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: "State",
                    labelStyle: TextStyle(
                      color: theme.primaryColor.withValues(alpha: 0.75),
                    ),
                    border: const OutlineInputBorder(),
                    enabled: _reportCountry.isNotEmpty,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.55),
                      ),
                    ),
                    suffixIcon: Icon(
                      Icons.search,
                      color: theme.primaryColor.withValues(alpha: 0.85),
                    ),
                  ),
                  child: Text(
                    _reportState.isEmpty ? "Search state" : _reportState,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: TextField(
                controller: _districtController,
                enabled: _reportState.isNotEmpty,
                decoration: const InputDecoration(
                  labelText: "District",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setState(() {
                    _talukaController.clear();
                    _cityController.clear();
                  });
                },
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: TextField(
                controller: _talukaController,
                enabled: _districtController.text.trim().isNotEmpty,
                decoration: const InputDecoration(
                  labelText: "Taluka",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setState(() {
                    _cityController.clear();
                  });
                },
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: TextField(
                controller: _cityController,
                enabled: _talukaController.text.trim().isNotEmpty,
                decoration: const InputDecoration(
                  labelText: "City",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: theme.cardColor,
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _reportAgeGroup,
                  dropdownColor: theme.cardColor,
                  style: TextStyle(color: theme.canvasColor),
                  decoration: InputDecoration(
                    labelText: "Age Group",
                    labelStyle: TextStyle(
                      color: theme.primaryColor.withValues(alpha: 0.75),
                    ),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  items: _ageGroupOptions
                      .map(
                        (ageGroup) => DropdownMenuItem<String>(
                          value: ageGroup,
                          child: Text(
                            ageGroup,
                            style: TextStyle(color: theme.canvasColor),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _reportAgeGroup = value);
                  },
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: theme.cardColor,
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _reportGender,
                  dropdownColor: theme.cardColor,
                  style: TextStyle(color: theme.canvasColor),
                  decoration: InputDecoration(
                    labelText: "Gender",
                    labelStyle: TextStyle(
                      color: theme.primaryColor.withValues(alpha: 0.75),
                    ),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  items: _genderOptions
                      .map(
                        (gender) => DropdownMenuItem<String>(
                          value: gender,
                          child: Text(
                            gender == 'ALL'
                                ? gender
                                : "${gender[0].toUpperCase()}${gender.substring(1)}",
                            style: TextStyle(color: theme.canvasColor),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _reportGender = value);
                  },
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: OutlinedButton.icon(
                onPressed: _pickReportDateRange,
                icon: const Icon(Icons.date_range),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dateLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  side: BorderSide(color: theme.dividerColor),
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: ElevatedButton.icon(
                onPressed: () async => _applyReportFilters(),
                icon: const Icon(Icons.filter_alt),
                label: const Text("Apply Filters"),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: OutlinedButton.icon(
                onPressed: _clearReportFilters,
                icon: const Icon(Icons.refresh),
                label: const Text("Reset"),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactReportList(
      List<ReportAndDataObject> movies, ThemeData selectedThemeData) {
    return Column(
      children: movies
          .map(
            (movie) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selectedThemeData.scaffoldBackgroundColor
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selectedThemeData.dividerColor.withValues(alpha: 0.36),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: selectedThemeData.primaryColor
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.movie_creation_outlined,
                          color: selectedThemeData.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          movie.movieName ?? '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: selectedThemeData.primaryColor,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: movie.views == null
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MovieDetailsPage(
                                      movieId: movie.views!,
                                    ),
                                  ),
                                );
                              },
                        child: const Text("Open"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _compactReportChip(
                        selectedThemeData,
                        Icons.event_outlined,
                        "Release",
                        movie.releasedDate == null
                            ? '-'
                            : DateFormat('dd MMM yyyy')
                                .format(movie.releasedDate!),
                      ),
                      _compactReportChip(
                        selectedThemeData,
                        Icons.visibility_outlined,
                        "Views",
                        _formatNumber(_toInt(movie.views)),
                      ),
                      _compactReportChip(
                        selectedThemeData,
                        Icons.currency_rupee_rounded,
                        "Revenue",
                        formatAmount(movie.revenue),
                      ),
                      _compactReportChip(
                        selectedThemeData,
                        Icons.percent_rounded,
                        "Commission",
                        "${movie.price ?? 0}%",
                      ),
                      _compactReportChip(
                        selectedThemeData,
                        Icons.account_balance_wallet_outlined,
                        "Net Revenue",
                        formatAmount(movie.netRevenue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _compactReportChip(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.primaryColor),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: TextStyle(
              color: theme.canvasColor.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.canvasColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportTotalChip(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: theme.primaryColor),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(
              color: theme.canvasColor.withValues(alpha: 0.62),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.primaryColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /*
  Widget _legacyCompactReportList(
      List<ReportAndDataObject> movies, ThemeData selectedThemeData) {
    return Column(
      children: movies
          .map(
            (movie) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: selectedThemeData.scaffoldBackgroundColor,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.movieName ?? '-',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MovieDetailsPage(
                                      movieId: movie.views!,
                                    ),
                                  ),
                                );
                              },
                        child: const Text("Open"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
  */

  Widget _buildDashboardCards(
    MediaHouseProvider mediaHouseProvider,
    ThemeData theme,
  ) {
    final data = mediaHouseProvider.mediaHouseDashboardData;
    final approved = data.approvedContent ?? 0;
    final upcoming = data.upcomingContentCount ?? 0;
    final pending = data.pendingContentCount ?? 0;
    final rejected = data.rejectedContentCount ?? 0;
    final totalContent = approved + upcoming + pending + rejected;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width > 1180
            ? (width - 36) / 4
            : width > 760
                ? (width - 24) / 3
                : width > 520
                    ? (width - 12) / 2
                    : width;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: "Total Content",
                value: _formatNumber(totalContent),
                icon: Icons.video_library_outlined,
                color: Colors.blue,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: "Approved Content",
                value: _formatNumber(approved),
                icon: Icons.verified_outlined,
                color: Colors.green,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: "Pending Content",
                value: _formatNumber(pending),
                icon: Icons.pending_actions_outlined,
                color: Colors.orange,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: "Upcoming Content",
                value: _formatNumber(upcoming),
                icon: Icons.upcoming_outlined,
                color: Colors.indigo,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: "Rejected Content",
                value: _formatNumber(rejected),
                icon: Icons.cancel_outlined,
                color: Colors.red,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: "Total Views",
                value: _formatNumber(data.totalViews ?? 0),
                icon: Icons.visibility_outlined,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: "Net Revenue",
                value: "₹${_formatNumber(data.viewRevenue ?? 0)}",
                icon: Icons.currency_rupee_rounded,
                color: Colors.teal,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var selectedThemeData =
        Provider.of<ThemeProvider>(context, listen: true).getTheme;

    return Scaffold(
      backgroundColor: selectedThemeData.scaffoldBackgroundColor,
      body: Consumer2<GraphProvider, MediaHouseProvider>(
        builder: (context, provider, mediaHouseProvider, child) {
          final isCompact = MediaQuery.of(context).size.width < 820;
          final sortedMovies = getSortedMovies(provider);
          final totalViews = sortedMovies.fold<int>(
            0,
            (sum, movie) => sum + _toInt(movie.views),
          );
          final totalRevenue = sortedMovies.fold<double>(
            0,
            (sum, movie) => sum + _toDouble(movie.revenue),
          );
          final totalNetRevenue = sortedMovies.fold<int>(
            0,
            (sum, movie) => sum + _toInt(movie.netRevenue),
          );

          return RefreshIndicator(
            onRefresh: _initData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Analytics",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: selectedThemeData.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Monitor performance and revenue across all published content.",
                    style: TextStyle(
                      color:
                          selectedThemeData.primaryColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDashboardCards(mediaHouseProvider, selectedThemeData),
                  const SizedBox(height: 14),
                  Text(
                    "Performance Overview",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: selectedThemeData.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: isCompact ? 290 : 360,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selectedThemeData.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 5)
                      ],
                    ),
                    child: TopMoviesLineGraph(isRevenue: false),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Reports & Data",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: selectedThemeData.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    color: selectedThemeData.cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _buildReportFilters(provider, selectedThemeData),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _reportTotalChip(
                        selectedThemeData,
                        Icons.filter_list_rounded,
                        "Filtered Items",
                        "${sortedMovies.length}",
                      ),
                      _reportTotalChip(
                        selectedThemeData,
                        Icons.visibility_outlined,
                        "Filtered Views",
                        _formatNumber(totalViews),
                      ),
                      _reportTotalChip(
                        selectedThemeData,
                        Icons.currency_rupee_rounded,
                        "Filtered Revenue",
                        _formatNumber(totalRevenue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: selectedThemeData.cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: provider.isLoadingReportData
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : sortedMovies.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 24),
                                    child: Text(
                                      "No report data found.",
                                      style: TextStyle(
                                        color: selectedThemeData.primaryColor
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                )
                              : isCompact
                                  ? _buildCompactReportList(
                                      sortedMovies, selectedThemeData)
                                  : _buildMovieTable(
                                      sortedMovies, selectedThemeData),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Net Revenue: ${_formatNumber(totalNetRevenue)}",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selectedThemeData.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
