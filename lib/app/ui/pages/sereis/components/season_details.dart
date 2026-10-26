import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:media_house/app/ui/pages/secure_content_page.dart';
import 'package:media_house/data/models/response/series_detail_response.dart';
import 'package:media_house/data/models/response/signed_playback.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/currency_formatter.dart';

import '../../../../../domain/entities/cast_crew_model.dart';
import '../../../../provider/series_provider.dart';
import '../../../../provider/themeProvider.dart';
import '../../../../widget/show_toast.dart';
import '../../movie details page/component/actionButtonWidget.dart';
import 'create_episode.dart';
import 'edit_episode_dialog.dart';
import 'edit_season_dialog.dart';

class SeasonDetailPage extends StatefulWidget {
  final int seriesId;
  final SeasonBundle seasonBundle;
  final String seriesLanguage;

  const SeasonDetailPage({
    super.key,
    required this.seriesId,
    required this.seasonBundle,
    required this.seriesLanguage,
  });

  @override
  State<SeasonDetailPage> createState() => _SeasonDetailPageState();
}

class _SeasonDetailPageState extends State<SeasonDetailPage> {
  late List<Episode> _episodes;
  bool _isCastCrewLoading = false;
  List<CastCrewItem> _castCrewMembers = [];

  bool get _isSeasonPublished => widget.seasonBundle.season.active == true;
  bool get _isSeasonDeactivated => widget.seasonBundle.season.active == false;

  @override
  void initState() {
    super.initState();
    _episodes = List<Episode>.from(widget.seasonBundle.episodes);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCastCrewForSeason();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).getTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.seasonBundle.season.title ?? "",
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _seasonHeader(context, theme),
            const SizedBox(height: 18),
            _episodeHeader(context, theme),
            const SizedBox(height: 10),
            Expanded(child: _episodeList(theme)),
          ],
        ),
      ),
    );
  }

  Widget _seasonHeader(
    BuildContext context,
    ThemeData theme,
  ) {
    final season = widget.seasonBundle.season;
    final totalEpisodes = _episodes.length;
    final totalViews =
        _episodes.fold<int>(0, (sum, e) => sum + (e.viewCount ?? 0));
    final seasonAmount = season.amount ?? 0;
    final totalRevenue = _episodes.fold<num>(
      0,
      (sum, e) => sum + (seasonAmount * (e.viewCount ?? 0)),
    );
    final posterUrl = "${season.posterUrl ?? ''}";
    final castCrewMembers = _castCrewMembers
        .where((e) => e.name.trim().isNotEmpty)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.cardColor.withValues(alpha: 0.96),
            theme.cardColor.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final poster = ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: posterUrl.trim().isNotEmpty
                    ? Image.network(
                        posterUrl,
                        height: 130,
                        width: 190,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _posterFallback(130, 190),
                      )
                    : _posterFallback(130, 190),
              );

              final details = Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      season.title ?? "",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryColor,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      season.description ?? "",
                      maxLines: compact ? 4 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.canvasColor.withValues(alpha: 0.82),
                        height: 1.4,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _isCastCrewLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _castCrewList(theme, castCrewMembers),
                  ],
                ),
              );

              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: poster),
                        const SizedBox(height: 12),
                        Row(children: [details]),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        poster,
                        const SizedBox(width: 16),
                        details,
                      ],
                    );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statCard(
                theme,
                Icons.price_check,
                "Season Price",
                formatCurrency(season.amount, symbol: 'Rs '),
              ),
              _statCard(
                  theme, Icons.list_alt_rounded, "Episodes", "$totalEpisodes"),
              _statCard(
                  theme, Icons.visibility_outlined, "Views", "$totalViews"),
              _statCard(theme, Icons.favorite_border, "Likes", "0"),
              _statCard(
                theme,
                Icons.currency_rupee_rounded,
                "Revenue",
                formatCurrency(totalRevenue, symbol: 'Rs '),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _isSeasonDeactivated ? null : () => _editSeason(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text("Edit Season"),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSeasonDeactivated
                      ? null
                      : () => _deleteSeason(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text("Delete Season"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _episodeHeader(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Text(
          "Episode Management",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: theme.canvasColor,
          ),
        ),
        const Spacer(),
        ActionButtonWidget(
          label: "Add Episode",
          icon: Icons.add_circle,
          onTap: () {
            _addEpisode(context);
          },
        ),
      ],
    );
  }

  Widget _episodeList(ThemeData theme) {
    final episodes = _episodes;
    if (episodes.isEmpty) {
      return Center(
        child: Text(
          "No episodes added yet",
          style: TextStyle(color: theme.canvasColor.withValues(alpha: 0.7)),
        ),
      );
    }

    return ListView.separated(
      itemCount: episodes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ep = episodes[index];
        final views = ep.viewCount ?? 0;
        final amount = ep.amount ?? widget.seasonBundle.season.amount ?? 0;
        final revenue = views * amount;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SecureContentPage(
                  contentId: ep.id?.toString() ?? '',
                  contentUrl: ep.videoUrl ?? '',
                  contentType: secureContentType(null, episode: true),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: theme.cardColor.withValues(alpha: 0.96),
              border:
                  Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final poster = ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 80,
                    width: 124,
                    child: (ep.posterUrl ?? '').trim().isNotEmpty
                        ? Image.network(
                            ep.posterUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _posterFallback(80, 124),
                          )
                        : _posterFallback(80, 124),
                  ),
                );

                final titleSection = Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 30,
                            width: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "E${ep.episodeNumber ?? '-'}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (ep.title ?? '').trim().isEmpty
                                   ? "Untitled Episode"
                                  : ep.title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.canvasColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ((ep.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          ep.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.canvasColor.withValues(alpha: 0.75),
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _metaChip(
                            theme,
                            Icons.currency_rupee_rounded,
                            "Price ${formatCurrency(amount, symbol: 'Rs ')}",
                          ),
                          _metaChip(
                            theme,
                            Icons.trending_up_rounded,
                            "Revenue ${formatCurrency(revenue, symbol: 'Rs ')}",
                          ),
                          _metaChip(theme, Icons.timer_outlined,
                              "${ep.runtime ?? 0} min"),
                          _metaChip(
                              theme, Icons.visibility_outlined, "$views views"),
                          _metaChip(theme, Icons.favorite_border, "0 likes"),
                          _metaChip(
                              theme, Icons.comment_outlined, "0 comments"),
                        ],
                      ),
                    ],
                  ),
                );

                final actions = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: "Edit Episode",
                      icon:
                          Icon(Icons.edit_outlined, color: theme.primaryColor),
                      onPressed: ep.id == null
                          ? null
                          : () => _editEpisode(context, ep),
                    ),
                    IconButton(
                      tooltip: "Delete Episode",
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: _isSeasonPublished || ep.id == null
                          ? null
                          : () => _deleteEpisode(context, ep.id!),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          poster,
                          const SizedBox(width: 10),
                          titleSection,
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    poster,
                    const SizedBox(width: 12),
                    titleSection,
                    const SizedBox(width: 4),
                    actions,
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _castCrewList(ThemeData theme, List<CastCrewItem> members) {
    if (members.isEmpty) {
      return Column(
        children: [
          Text(
            "Cast & Crew: ",
            style: TextStyle(
              color: theme.canvasColor.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          _castRow(theme, members),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Cast & Crew",
          style: TextStyle(
            color: theme.canvasColor.withValues(alpha: 0.85),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: members.take(8).map((member) {
            return Container(
              constraints: const BoxConstraints(minWidth: 160, maxWidth: 230),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 34,
                      width: 34,
                      child: member.image.trim().isNotEmpty
                          ? Image.network(
                              member.image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _castFallback(),
                            )
                          : _castFallback(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.canvasColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          member.role.trim().isEmpty ? "NA" : member.role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.canvasColor.withValues(alpha: 0.68),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }

  Widget _castFallback() {
    return Container(
      color: Colors.grey.shade800,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_outline,
        color: Colors.white54,
        size: 16,
      ),
    );
  }

  Widget _statCard(ThemeData theme, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 26,
            width: 26,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: theme.primaryColor),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: theme.canvasColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: theme.canvasColor.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(ThemeData theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.primaryColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: theme.canvasColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _posterFallback(double h, double w) {
    return Container(
      height: h,
      width: w,
      color: Colors.grey.shade800,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white54,
        size: 26,
      ),
    );
  }

  Future<void> _editSeason(BuildContext context) async {
    if (_isSeasonDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "This season is deactivated. Raise a ticket to admin for further changes.",
          ),
        ),
      );
      return;
    }

    final seasonId = widget.seasonBundle.season.id;
    if (seasonId == null) return;

    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EditSeasonDialog(season: widget.seasonBundle.season),
    );
    if (body == null) return;

    final provider = Provider.of<SeriesProvider>(context, listen: false);
    final success = await provider.updateSeasonApi(
      body,
      seasonId,
      seriesId: widget.seriesId,
    );
    await provider.loadSeries(widget.seriesId);

    if (success) {
      setState(() {
        final updatedAmount = num.tryParse('${body['amount']}');
        if (updatedAmount != null) {
          widget.seasonBundle.season.amount = updatedAmount;
          for (final episode in _episodes) {
            episode.amount = updatedAmount;
          }
        }
      });
    }

    if (!context.mounted) return;
    CustomToast.show(
      context,
      success ? "Season updated successfully" : "Failed to update season",
      isSuccess: success,
    );
  }

  void _deleteSeason(BuildContext context) {
    if (_isSeasonDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This season is already deactivated."),
        ),
      );
      return;
    }

    final seasonId = widget.seasonBundle.season.id;
    if (seasonId == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Season"),
        content: const Text("Are you sure you want to delete this season?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider =
                  Provider.of<SeriesProvider>(context, listen: false);
              final message = await provider.deleteSeasonApi(
                seasonId,
                seriesId: widget.seriesId,
              );
              final success = message != null;
              await provider.loadSeries(widget.seriesId);

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? (message ?? "Season deactivated successfully")
                        : "Failed to delete season",
                  ),
                ),
              );

              if (success) {
                widget.seasonBundle.season.active = false;
                Navigator.pop(context);
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> _addEpisode(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEpisodeDialog(
        seriesId: widget.seriesId,
        seasonId: widget.seasonBundle.season.id!,
        seasonPrice: widget.seasonBundle.season.amount ?? 0,
        seriesLanguage: widget.seriesLanguage,
        onSuccess: _reloadSeasonEpisodes,
      ),
    );
  }

  Future<void> _reloadSeasonEpisodes() async {
    if (!mounted) return;

    final provider = Provider.of<SeriesProvider>(context, listen: false);
    await provider.loadSeries(widget.seriesId);

    if (!mounted) return;

    final seasonId = widget.seasonBundle.season.id;
    SeasonBundle? refreshedSeason;
    for (final season in provider.data?.seasons ?? <SeasonBundle>[]) {
      if (season.season.id == seasonId) {
        refreshedSeason = season;
        break;
      }
    }

    if (refreshedSeason == null) return;

    setState(() {
      _episodes = List<Episode>.from(refreshedSeason!.episodes);
    });
  }

  void _deleteEpisode(BuildContext context, int episodeId) async {
    if (_isSeasonPublished) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Published seasons cannot delete episodes. Raise a ticket to admin for changes.",
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Delete Episode"),
            content:
                const Text("Are you sure you want to delete this episode?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Delete"),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final seasonId = widget.seasonBundle.season.id;
    if (seasonId == null) return;

    final provider = Provider.of<SeriesProvider>(context, listen: false);
    final success = await provider.deleteEpisodeApi(
      seasonId,
      episodeId,
      seriesId: widget.seriesId,
    );
    if (success) {
      setState(() {
        _episodes.removeWhere((e) => e.id == episodeId);
      });
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? "Episode deleted successfully" : "Failed to delete episode",
        ),
      ),
    );
  }

  Future<void> _editEpisode(BuildContext context, Episode ep) async {
    final seasonId = widget.seasonBundle.season.id;
    if (seasonId == null || ep.id == null) return;

    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EditEpisodeDialog(
        episode: ep,
        seasonPrice: widget.seasonBundle.season.amount ?? ep.amount ?? 0,
      ),
    );
    if (body == null) return;

    final provider = Provider.of<SeriesProvider>(context, listen: false);
    final response = await provider.updateEpisodeApiResponse(
      body,
      seasonId,
      ep.id!,
      seriesId: widget.seriesId,
    );
    final success = response != null &&
        response.statusCode >= 200 &&
        response.statusCode < 300;
    if (success) {
      await _reloadSeasonEpisodes();
    }

    if (context.mounted) {
      await _showEpisodeUpdateDialog(
        success: success,
        message: _episodeResponseMessage(
          response?.body ?? '',
          success
              ? "Episode updated successfully."
              : "Failed to update episode.",
        ),
      );
    }
  }

  String _episodeResponseMessage(String body, String fallback) {
    if (body.trim().isEmpty) return fallback;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        for (final key in const ['message', 'error', 'details']) {
          final value = decoded[key]?.toString().trim();
          if (value != null && value.isNotEmpty) return value;
        }
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _showEpisodeUpdateDialog({
    required bool success,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(success ? "Episode Updated" : "Episode Update Failed"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  String _initials(String input) {
    final parts =
        input.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color _avatarColor(int index) {
    const palette = [
      Color(0xFF2F80ED),
      Color(0xFF9B51E0),
      Color(0xFF27AE60),
      Color(0xFFF2994A),
      Color(0xFFEB5757),
      Color(0xFF56CCF2),
    ];
    return palette[index % palette.length];
  }

  Widget _castRow(ThemeData theme, List<CastCrewItem> cast) {
    if (cast.isEmpty) {
      return Text(
        "NA",
        style: TextStyle(color: theme.canvasColor.withValues(alpha: 0.75)),
      );
    }

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cast.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final item = cast[index];
          final name = item.name;
          final imageUrl = item.image.trim();
          return Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _avatarColor(index),
                backgroundImage:
                    imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                child: imageUrl.isEmpty
                    ? Text(
                        _initials(name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
                onBackgroundImageError: (_, __) {},
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 60,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadCastCrewForSeason() async {
    final seasonId = widget.seasonBundle.season.id;
    final contentId = widget.seasonBundle.season.contentId ?? widget.seriesId;
    if (seasonId == null || contentId <= 0) return;

    if (mounted) {
      setState(() => _isCastCrewLoading = true);
    }

    final provider = Provider.of<SeriesProvider>(context, listen: false);
    final members = await provider.fetchCastCrewListForSeason(
      contentId: contentId,
      seasonId: seasonId,
    );

    if (!mounted) return;
    setState(() {
      _castCrewMembers = members
          .where((e) => e.name.trim().isNotEmpty)
          .toList(growable: false);
      _isCastCrewLoading = false;
    });
  }
}
