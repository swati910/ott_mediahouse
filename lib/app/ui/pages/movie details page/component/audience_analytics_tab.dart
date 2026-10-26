import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_house/domain/entities/content.dart';
import 'package:media_house/data/models/response/audience_analytics_response.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/provider/videoProvider.dart';

class AudienceAnalyticsTab extends StatefulWidget {
  final Content movie;
  final ThemeData theme;

  const AudienceAnalyticsTab({
    super.key,
    required this.movie,
    required this.theme,
  });

  @override
  State<AudienceAnalyticsTab> createState() => _AudienceAnalyticsTabState();
}

class _AudienceAnalyticsTabState extends State<AudienceAnalyticsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.movie.id != null) {
        Provider.of<VideoProvider>(context, listen: false)
            .fetchAudienceAnalytics(widget.movie.id!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).getTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<VideoProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingAudienceAnalytics) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: theme.primaryColor),
            ),
          );
        }

        final locations = provider.locationAudience;
        final ages = provider.ageAudience;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            if (locations.isEmpty && ages.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No audience demographic analytics recorded yet for this content.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDemographicCard(
                          context,
                          title: 'Geographic Distribution (Location-Wise)',
                          subtitle: 'Audience density across top regions',
                          icon: Icons.location_on_outlined,
                          color: const Color(0xFF3B82F6),
                          items: locations,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDemographicCard(
                          context,
                          title: 'Age Demographics (Age-Wise Views)',
                          subtitle: 'Viewership breakdown by viewer age group',
                          icon: Icons.group_outlined,
                          color: const Color(0xFF10B981),
                          items: ages,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildDemographicCard(
                        context,
                        title: 'Geographic Distribution (Location-Wise)',
                        subtitle: 'Audience density across top regions',
                        icon: Icons.location_on_outlined,
                        color: const Color(0xFF3B82F6),
                        items: locations,
                      ),
                      const SizedBox(height: 16),
                      _buildDemographicCard(
                        context,
                        title: 'Age Demographics (Age-Wise Views)',
                        subtitle: 'Viewership breakdown by viewer age group',
                        icon: Icons.group_outlined,
                        color: const Color(0xFF10B981),
                        items: ages,
                      ),
                    ],
                  );
          },
        );
      },
    );
  }

  Widget _buildDemographicCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<AudienceMetricItem> items,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final maxVal = items.isEmpty
        ? 1.0
        : items
            .map((e) => e.value)
            .reduce((curr, next) => curr > next ? curr : next);

    return Container(
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No metrics available',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            )
          else
            ...items.map((item) {
              final pct = (item.percentage != null)
                  ? item.percentage! / 100
                  : (maxVal > 0 ? (item.value / maxVal).clamp(0.0, 1.0) : 0.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          '${item.value.toInt()} views (${(pct * 100).toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
