import 'package:flutter/material.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/ui/pages/shorts/components/short_master_page.dart';
import 'package:media_house/app/widget/show_toast.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/content.dart';
import '../ui/pages/movie details page/MovieDetailsPage.dart';
import '../ui/pages/movie details page/component/setPercentageDialog.dart';
import '../ui/pages/sereis/components/series_details_page.dart';
import '../core/content/content_type.dart';

class MovieCardHorizontal extends StatelessWidget {
  final Content movie;

  const MovieCardHorizontal({
    super.key,
    required this.movie,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: true).getTheme;
    final isRejected = (movie.approvalStatus ?? '').toLowerCase() == 'rejected';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDetails(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRejected
                ? const Color(0xFFD14343).withValues(alpha: 0.55)
                : Colors.grey.shade300,
            width: isRejected ? 1.0 : 0.6,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _poster(),
                  const SizedBox(width: 14),
                  Expanded(child: _details(theme)),
                ],
              ),
            ),
            if (isRejected) ...[
              const SizedBox(height: 8),
              _rejectionReasonBox(theme),
            ],
            const SizedBox(height: 6),
            _ratingBar(),
            const SizedBox(height: 6),
            _metaRow(),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    if (ContentTypeValue.isMovieLike(movie.type)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieDetailsPage(movieId: movie.id!),
        ),
      );
      return;
    }
    if (movie.type == "SERIES") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeriesDetailsPage(
            seriesId: movie.id!,
            content: movie,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShortMasterPage(
            shortId: movie.id!,
          ),
        ),
      );
    }
  }

  Widget _poster() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 110,
        height: 155,
        child: movie.posterUrlList != null && movie.posterUrlList!.isNotEmpty
            ? Image.network(
                movie.posterUrlList!.first,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => _errorPoster(),
              )
            : _errorPoster(),
      ),
    );
  }

  Widget _errorPoster() {
    return Container(
      width: 110,
      height: 155,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.movie, size: 45, color: Colors.black54),
    );
  }

  Widget _details(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                movie.title ?? '',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_languageLabel().isNotEmpty) ...[
              const SizedBox(width: 8),
              _languageBadge(theme),
            ],
            /*   const SizedBox(width: 8),
            _contentTypeBadge(theme), */
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _keyValue("Director", _join(movie.directorList)),
              _keyValue("Cast", _join(movie.castList)),
              _keyValue("Price", movie.price?.toString() ?? "N/A"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contentTypeBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        ContentTypeValue.displayLabel(movie.type),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _languageBadge(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.32)),
      ),
      child: Text(
        _languageLabel(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: theme.primaryColor,
        ),
      ),
    );
  }

  Widget _ratingBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ratingChip(),
        const SizedBox(width: 8),
        _likesChip(),
        const SizedBox(width: 8),
        _statusChip(),
      ],
    );
  }

  Widget _ratingChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, size: 15, color: Colors.amber),
          const SizedBox(width: 4),
          Text("${movie.ratings ?? 0}"),
        ],
      ),
    );
  }

  Widget _likesChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.pink.withOpacity(.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.thumb_up_alt_outlined, size: 14, color: Colors.pink),
          const SizedBox(width: 4),
          Text(
            "${movie.ratingCount ?? 0}",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _statusChip() {
    final normalized = (movie.approvalStatus ?? '').toLowerCase();
    final isApproved = normalized == "approved";
    final isRejected = normalized == "rejected";
    final statusColor = isApproved
        ? Colors.green
        : isRejected
            ? const Color(0xFFD14343)
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved
            ? Colors.green.withOpacity(.12)
            : isRejected
                ? const Color(0xFFD14343).withOpacity(.12)
                : Colors.orange.withOpacity(.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isApproved
                ? Icons.verified
                : isRejected
                    ? Icons.cancel_outlined
                    : Icons.pending,
            size: 14,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            movie.approvalStatus ?? "Pending",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rejectionReasonBox(ThemeData theme) {
    final reason = (movie.reason ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD14343).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD14343).withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.report_gmailerrorred_rounded,
              size: 18,
              color: Color(0xFFD14343),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.canvasColor.withValues(alpha: 0.86),
                  height: 1.3,
                ),
                children: [
                  const TextSpan(
                    text: 'Rejection Reason: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD14343),
                    ),
                  ),
                  TextSpan(
                    text: reason.isEmpty
                        ? 'No reason provided by admin.'
                        : reason,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metaItem(
          movie.type == "SERIES" ? Icons.video_library_outlined : Icons.timer,
          movie.type == "SERIES"
              ? "${_seriesEpisodes()} Episodes"
              : "${movie.runtime ?? 0} min",
        ),
        const SizedBox(width: 14),
        _metaItem(Icons.date_range, movie.releaseDate ?? "N/A"),
        const SizedBox(width: 14),
        _metaItem(Icons.visibility, "${movie.views ?? 0} Views"),
      ],
    );
  }

  int _seriesEpisodes() {
    final dynamic value = movie.episodeId;
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _keyValue(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.grey),
          children: [
            TextSpan(
              text: "$key: ",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _join(List<String>? list) {
    if (list == null || list.isEmpty) return "N/A";
    return list.join(', ');
  }

  String _languageLabel() {
    final languages = movie.languageList
            ?.map((item) => (item.language ?? '').trim())
            .where((item) => item.isNotEmpty)
            .toList() ??
        [];
    if (languages.isEmpty) return '';
    if (languages.length == 1) return languages.first;
    return '${languages.first} +${languages.length - 1}';
  }

  showSetPercentageDialog(BuildContext context, Content content) async {
    final double? result = await showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return SetPercentageDialog(content: content);
      },
    );

    if (result != null) {
      debugPrint("Selected Percentage: ${result.toInt()}%");
      CustomToast.show(
        context,
        'Selected Percentage : ${result.toInt()}%',
        isSuccess: false,
      );
    }
  }
}
