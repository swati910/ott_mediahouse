import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_house/app/widget/movieCardHorizontal.dart';
import 'package:provider/provider.dart';

import '../../../provider/series_provider.dart';
import '../../../../device/utils/ResponsiveWidget.dart';

class SeriesPage extends StatefulWidget {
  const SeriesPage({super.key});

  @override
  State<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<SeriesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _trendingOnly = false;
  bool _suppressSearchListener = false;
  String _lastRequestedFilterKey = '';

  Future<void> _loadSeriesFromFilters({bool force = false}) async {
    final currentKey =
        '${_query.trim()}|${_fromDate?.millisecondsSinceEpoch ?? ''}|${_toDate?.millisecondsSinceEpoch ?? ''}';
    if (!force && currentKey == _lastRequestedFilterKey) return;
    _lastRequestedFilterKey = currentKey;

    await context.read<SeriesProvider>().fetchSeriesByMediaHouseId(
          status: "APPROVED",
          type: "SERIES",
          searchKeyword: _query.trim().isEmpty ? null : _query.trim(),
          startDate: _fromDate != null ? _formatDate(_fromDate!) : null,
          endDate: _toDate != null ? _formatDate(_toDate!) : null,
          page: 0,
          loadMore: false,
        );
  }

  void _resetFilters() {
    _suppressSearchListener = true;
    _searchDebounce?.cancel();
    setState(() {
      _fromDate = null;
      _toDate = null;
      _searchCtrl.clear();
      _query = '';
      _trendingOnly = false;
    });
    _suppressSearchListener = false;
    _loadSeriesFromFilters(force: true);
  }

  Future<void> _pickDateRange() async {
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
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
              initialDateRange: (_fromDate != null && _toDate != null)
                  ? DateTimeRange(start: _fromDate!, end: _toDate!)
                  : null,
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
      _fromDate = picked.start;
      _toDate = picked.end;
    });
    await _loadSeriesFromFilters();
  }

  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  String _formatCompact(num value) {
    if (value >= 10000000) {
      return "${(value / 10000000).toStringAsFixed(1)}Cr";
    }
    if (value >= 100000) {
      return "${(value / 100000).toStringAsFixed(1)}L";
    }
    if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}K";
    }
    return value.toStringAsFixed(0);
  }

  Widget _statTile(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.canvasColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: theme.canvasColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (_suppressSearchListener) return;
      _query = _searchCtrl.text.trim();
      setState(() {});
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        _loadSeriesFromFilters();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSeriesFromFilters(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Consumer<SeriesProvider>(
        builder: (context, provider, _) {
          final filteredSeries = provider.filteredContentList.where((series) {
            final trendingMatches =
                !_trendingOnly || series.isFeatured == true;
            return trendingMatches;
          }).toList();

          final totalRevenue = filteredSeries.fold<num>(
            0,
            (sum, item) => sum + item.effectiveMediaHouseNetRevenue,
          );
          final totalViews = filteredSeries.fold<num>(
            0,
            (sum, item) => sum + (item.views ?? 0),
          );
          final totalLikes = filteredSeries.fold<num>(
            0,
            (sum, item) => sum + (item.ratingCount ?? 0),
          );

          return RefreshIndicator(
            onRefresh: () => _loadSeriesFromFilters(force: true),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /*   Text(
                    "Series Management",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: theme.canvasColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;
                      final tileWidth = isWide
                          ? (constraints.maxWidth - 24) / 3
                          : constraints.maxWidth;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: tileWidth,
                            child: _statTile(
                              theme,
                              icon: Icons.video_collection_outlined,
                              label: "Series Count",
                              value: "${filteredSeries.length}",
                              accent: Colors.blue,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: _statTile(
                              theme,
                              icon: Icons.visibility_outlined,
                              label: "Total Views",
                              value: _formatCompact(totalViews),
                              accent: Colors.orange,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: _statTile(
                              theme,
                              icon: Icons.currency_rupee_rounded,
                              label: "Total Revenue",
                              value: _formatCompact(totalRevenue),
                              accent: Colors.green,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14), */
                  _buildFilterPanel(
                    theme,
                    provider: provider,
                    itemCount: filteredSeries.length,
                  ),
                  const SizedBox(height: 12),
                  if (provider.isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: theme.primaryColor)),
                    )
                  else if (filteredSeries.isEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 42, color: theme.primaryColor),
                              const SizedBox(height: 8),
                              Text(
                                _query.isEmpty
                                    ? "No series available."
                                    : "No series found for current filters.",
                                style: TextStyle(
                                  color: theme.canvasColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ))
                  else
                    ResponsiveWidget.isMobile(context)
                        ? ListView.separated(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: filteredSeries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              return MovieCardHorizontal(
                                movie: filteredSeries[index],
                              );
                            },
                          )
                        : GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: filteredSeries.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 16 / 9,
                            ),
                            itemBuilder: (context, index) {
                              return MovieCardHorizontal(
                                movie: filteredSeries[index],
                              );
                            },
                          ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildFilterPanel(
    ThemeData theme, {
    required SeriesProvider provider,
    required int itemCount,
  }) {
    final dateText = (_fromDate != null && _toDate != null)
        ? "${_formatDate(_fromDate!)} - ${_formatDate(_toDate!)}"
        : "Select Date Range";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.cardColor.withValues(alpha: 0.95),
            theme.cardColor.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.25)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;

          final searchField = TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: "Search title, cast, genre...",
              prefixIcon: Icon(
                Icons.search,
                color: theme.canvasColor,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _searchCtrl.clear(),
                    ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.6),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.6),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.primaryColor.withValues(alpha: 0.9),
                  width: 1.4,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.2),
              ),
            ),
          );

          final topRow = Row(
            children: [
              Icon(Icons.video_collection_rounded, color: theme.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Series Management",
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$itemCount items",
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => _loadSeriesFromFilters(force: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          );

          final customDateButton = OutlinedButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: Text(
              dateText,
              overflow: TextOverflow.ellipsis,
            ),
          );

          final trendingChip = FilterChip(
            selected: _trendingOnly,
            label: const Text('Trending'),
            onSelected: (_) {
              setState(() {
                _trendingOnly = !_trendingOnly;
              });
            },
            selectedColor: theme.primaryColor.withValues(alpha: 0.2),
            checkmarkColor: theme.primaryColor,
            labelStyle: TextStyle(
              color: _trendingOnly ? theme.primaryColor : null,
            ),
          );

          final resetButton = TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text("Reset"),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              topRow,
              const SizedBox(height: 10),
              if (compact) ...[
                searchField,
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(width: 240, child: customDateButton),
                    // trendingChip,
                    resetButton,
                  ],
                )
              ] else ...[
                Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: customDateButton),
                    const SizedBox(width: 8),
                    /*  trendingChip,
                    const SizedBox(width: 8), */
                    resetButton,
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
