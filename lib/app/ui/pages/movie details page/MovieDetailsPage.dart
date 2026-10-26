import 'dart:math' as math;

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/content/content_type.dart';
import '../../../widget/show_toast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/currency_formatter.dart';

import '../../../../domain/entities/content.dart';
import '../../../provider/themeProvider.dart';
import '../../../provider/videoProvider.dart';
import '../DisplayTrailer.dart';
import '../editMovie.dart';
import '../secure_content_page.dart';
import '../../../../data/models/response/signed_playback.dart';
import 'component/movieRevenueGraph.dart';
import 'component/pending_agreement_tab.dart';
import 'component/content_revenue_breakdown_tab.dart';
import 'component/purchased_users_tab.dart';
import 'component/audience_analytics_tab.dart';

class MovieDetailsPage extends StatefulWidget {
  final int movieId;
  final int initialTab;

  const MovieDetailsPage({
    super.key,
    required this.movieId,
    this.initialTab = 0,
  });

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage>
    with SingleTickerProviderStateMixin {
  static const int _overviewTab = 0;
  static const int _trailersTab = 1;
  static const int _reviewsTab = 2;
  static const int _agreementTab = 3;
  static const int _revenueTab = 4;
  static const int _purchasedUsersTab = 5;
  static const int _analyticsTab = 6;

  bool isLoading = true;
  int _selectedTab = _overviewTab;
  int _currentPosterIndex = 0;
  int _posterCount = 0;
  int? _pendingPosterCount;
  final PageController _posterPageController = PageController();
  Timer? _posterAutoSlideTimer;

  AnimationController? _entryController;
  Animation<double> _fadeAnimation = const AlwaysStoppedAnimation<double>(1);
  Animation<Offset> _slideAnimation =
      const AlwaysStoppedAnimation<Offset>(Offset.zero);

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _initAnimations();
    _fetchData();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => isLoading = false);
      }
    });
  }

  void _initAnimations() {
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryController!,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(_fadeAnimation);

    _entryController?.forward();
  }

  @override
  void dispose() {
    _posterAutoSlideTimer?.cancel();
    _posterPageController.dispose();
    _entryController?.dispose();
    super.dispose();
  }

  void _configurePosterAutoSlide(int count) {
    if (_posterCount == count) return;

    _posterCount = count;
    _posterAutoSlideTimer?.cancel();
    _posterAutoSlideTimer = null;

    if (count <= 1) {
      _currentPosterIndex = 0;
      return;
    }

    _posterAutoSlideTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_posterPageController.hasClients) return;
      final nextIndex = (_currentPosterIndex + 1) % _posterCount;
      _posterPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  void _schedulePosterAutoSlideConfig(int count) {
    if (_posterCount == count || _pendingPosterCount == count) return;
    _pendingPosterCount = count;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pendingPosterCount = null;
      _configurePosterAutoSlide(count);
    });
  }

  Future<void> _fetchData() async {
    final provider = Provider.of<VideoProvider>(context, listen: false);
    await provider.getContentById(widget.movieId);
    await provider.fetchCastByContentId(widget.movieId);
    await provider.fetchRatingReviewByContentId(widget.movieId);
  }

  @override
  Widget build(BuildContext context) {
    final selectedThemeData = Provider.of<ThemeProvider>(context).getTheme;
    final colorScheme = selectedThemeData.colorScheme;

    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: selectedThemeData.primaryColor,
          ),
        ),
      );
    }

    return Consumer<VideoProvider>(
      builder: (context, provider, child) {
        final movie = provider.content;

        if (movie == null) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: selectedThemeData.primaryColor,
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isDesktop = width >= 1100;
            final isTablet = width >= 760 && width < 1100;
            final horizontalPadding =
                isDesktop ? 28.0 : (isTablet ? 18.0 : 12.0);

            return Scaffold(
              backgroundColor: selectedThemeData.scaffoldBackgroundColor,
              appBar: AppBar(
                elevation: 0,
                backgroundColor: selectedThemeData.primaryColor,
                iconTheme: IconThemeData(color: Colors.white),
                title: Text(
                  movie.title ?? 'Movie Details',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.white),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    tooltip: 'Delete Content',
                    icon: Icon(Icons.delete_outline, color: Colors.white),
                    onPressed: () => _confirmDelete(movie),
                  ),
                ],
              ),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  //  _darkOverlay(),
                  SafeArea(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 14,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1360),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _staggeredSection(
                                    index: 0,
                                    child: _heroSection(
                                      context,
                                      movie,
                                      provider,
                                      isDesktop: isDesktop,
                                      isTablet: isTablet,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _staggeredSection(
                                    index: 1,
                                    child: _tabSelector(),
                                  ),
                                  const SizedBox(height: 14),
                                  _staggeredSection(
                                    index: 2,
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 260),
                                      switchInCurve: Curves.easeOut,
                                      switchOutCurve: Curves.easeIn,
                                      child: _tabContent(
                                        key: ValueKey<int>(_selectedTab),
                                        movie: movie,
                                        provider: provider,
                                        selectedThemeData: selectedThemeData,
                                        isDesktop: isDesktop,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _heroSection(
    BuildContext context,
    Content movie,
    VideoProvider provider, {
    required bool isDesktop,
    required bool isTablet,
  }) {
    final info = _heroInfoCard(context, movie, provider);
    final poster = _heroPosterCard(movie);

    if (isDesktop) {
      return _surfaceCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: poster),
            const SizedBox(width: 16),
            Expanded(flex: 7, child: info),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (!isTablet) poster,
        if (!isTablet) const SizedBox(height: 12),
        if (isTablet)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: info),
              const SizedBox(width: 12),
              Expanded(flex: 4, child: poster),
            ],
          )
        else
          info,
      ],
    );
  }

  Widget _heroInfoCard(
    BuildContext context,
    Content movie,
    VideoProvider provider,
  ) {
    final selectedThemeData = Provider.of<ThemeProvider>(context).getTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusPill(_displayValue(movie.approvalStatus)),
              _metaPill(Icons.category_outlined,
                  ContentTypeValue.displayLabel(movie.type)),
              _metaPill(Icons.schedule, _displayValue(movie.runtime)),
              _metaPill(Icons.currency_rupee, _formatPrice(movie.price)),
              _metaPill(Icons.shopping_cart_outlined,
                  '${_compactNum(movie.totalPurchase ?? 0)} Purchases'),
              _metaPill(Icons.workspace_premium_outlined,
                  _displayValue(movie.ageRating)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _displayValue(movie.title),
            style: TextStyle(
              color: selectedThemeData.canvasColor,
              fontSize: 31,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _heroMetaLine(movie),
            style: TextStyle(
              color: selectedThemeData.canvasColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _displayValue(movie.description),
            style: TextStyle(
              color: selectedThemeData.canvasColor,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          _adminActionsRow(context, movie, provider),
        ],
      ),
    );
  }

  Widget _heroPosterCard(Content movie) {
    final posters = (movie.posterUrlList ?? const [])
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    _schedulePosterAutoSlideConfig(posters.length);

    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (posters.isNotEmpty)
                    PageView.builder(
                      controller: _posterPageController,
                      itemCount: posters.length,
                      onPageChanged: (index) {
                        if (!mounted) return;
                        setState(() => _currentPosterIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return Image.network(
                          posters[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _posterFallback(),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return _posterFallback();
                          },
                        );
                      },
                    )
                  else
                    _posterFallback(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Text(
                      _displayValue(movie.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (posters.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(posters.length, (index) {
                final isActive = index == _currentPosterIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: isActive ? 18 : 6,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabSelector() {
    final selectedThemeData = Provider.of<ThemeProvider>(context).getTheme;
    final movie = Provider.of<VideoProvider>(context, listen: false).content;
    final normalizedStatus = (movie?.approvalStatus ?? '').toLowerCase();
    final showAgreementTab = movie?.isAggrement != null ||
        normalizedStatus == 'agreement_pending' ||
        normalizedStatus == 'pending';
    final tabs = [
      ('Overview', _overviewTab),
      ('Revenue Breakdown', _revenueTab),
      ('Purchased Users', _purchasedUsersTab),
      ('Audience Analytics', _analyticsTab),
      ('Trailers & More', _trailersTab),
      ('User Reviews', _reviewsTab),
      if (showAgreementTab)
        (
          movie?.isAggrement == true ? 'Agreement' : 'Pending Agreement',
          _agreementTab
        ),
    ];

    return _surfaceCard(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tabs.map((entry) {
          final label = entry.$1;
          final index = entry.$2;
          final selected = _selectedTab == index;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _selectedTab = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected
                    ? selectedThemeData.primaryColor
                    : selectedThemeData.splashColor,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white.withValues(alpha: 1)
                      : Colors.black.withValues(alpha: 1),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _tabContent({
    required Key key,
    required Content movie,
    required VideoProvider provider,
    required ThemeData selectedThemeData,
    required bool isDesktop,
  }) {
    if (_selectedTab == _revenueTab) {
      return KeyedSubtree(
        key: key,
        child: ContentRevenueBreakdownTab(
          movie: movie,
          theme: selectedThemeData,
        ),
      );
    }

    if (_selectedTab == _purchasedUsersTab) {
      return KeyedSubtree(
        key: key,
        child: PurchasedUsersTab(
          movie: movie,
          theme: selectedThemeData,
        ),
      );
    }

    if (_selectedTab == _analyticsTab) {
      return KeyedSubtree(
        key: key,
        child: AudienceAnalyticsTab(
          movie: movie,
          theme: selectedThemeData,
        ),
      );
    }

    if (_selectedTab == _trailersTab) {
      return _trailersTabContent(key, movie, provider);
    }

    if (_selectedTab == _reviewsTab) {
      return _reviewsTabContent(key, movie, provider);
    }

    if (_selectedTab == _agreementTab) {
      return KeyedSubtree(
        key: key,
        child: PendingAgreementTab(
          movie: movie,
          theme: selectedThemeData,
        ),
      );
    }

    return _overviewTabContent(
      key: key,
      movie: movie,
      provider: provider,
      selectedThemeData: selectedThemeData,
      isDesktop: isDesktop,
    );
  }

  Widget _overviewTabContent({
    required Key key,
    required Content movie,
    required VideoProvider provider,
    required ThemeData selectedThemeData,
    required bool isDesktop,
  }) {
    final leftColumn = Column(
      children: [
        _surfaceCard(
          child: _isPending(movie, selectedThemeData)
              ? _pendingStatusContainer(movie, selectedThemeData)
              : _analysisContainer(movie, selectedThemeData),
        ),
        const SizedBox(height: 14),
        _surfaceCard(child: _castPanel(movie, provider, selectedThemeData)),
        const SizedBox(height: 14),
        _surfaceCard(child: _censorCertificateCard(movie)),
      ],
    );

    final rightColumn = Column(
      children: [
        /*   _surfaceCard(child: _actionContainer(context, movie, provider)),
        const SizedBox(height: 14), */
        _detailsSection(movie, selectedThemeData),
      ],
    );

    return KeyedSubtree(
      key: key,
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: leftColumn),
                const SizedBox(width: 14),
                Expanded(flex: 7, child: rightColumn),
              ],
            )
          : Column(
              children: [
                rightColumn,
                const SizedBox(height: 14),
                leftColumn,
              ],
            ),
    );
  }

  Widget _trailersTabContent(Key key, Content movie, VideoProvider provider) {
    return KeyedSubtree(
      key: key,
      child: Column(
        children: [
          _surfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trailers & Streams',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final previews = [
                      _mediaPreviewCard(
                        title: 'Movie Trailer',
                        url: movie.trailerUrl,
                      ),
                      _mediaPreviewCard(
                        title: 'Movie Teaser',
                        url: movie.teaserUrl,
                      ),
                    ];
                    if (constraints.maxWidth >= 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: previews[0]),
                          const SizedBox(width: 12),
                          Expanded(child: previews[1]),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        previews[0],
                        const SizedBox(height: 12),
                        previews[1],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          /*  _surfaceCard(child: _actionContainer(context, movie, provider)), */
        ],
      ),
    );
  }

  Widget _reviewsTabContent(Key key, Content movie, VideoProvider provider) {
    final reviews = provider.ratingReviews;
    return KeyedSubtree(
      key: key,
      child: _surfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Reviews & Engagement',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metricChip(
                    'Rating', '${provider.ratingAvg.toStringAsFixed(1)} *'),
                _metricChip('Rating Count', '${reviews.length}'),
                _metricChip('Total Purchases',
                    _compactNum(movie.totalPurchase ?? 0)),
                _metricChip('Views', _compactNum(movie.views)),
                _metricChip('Comments',
                    _compactNum(movie.fullAttempt ?? movie.numberOfAttempt)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: provider.isLoadingRatingReviews
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : reviews.isEmpty
                      ? const Text(
                          'No reviews available for this content.',
                          style: TextStyle(height: 1.4),
                        )
                      : Column(
                          children: reviews
                              .map((r) => _reviewCard(r))
                              .toList(growable: false),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard(RatingReviewItem review) {
    final username =
        review.username.trim().isEmpty ? 'Anonymous' : review.username.trim();
    final title = review.title.trim().isEmpty ? 'Review' : review.title.trim();
    final comment =
        review.comment.trim().isEmpty ? 'No comment' : review.comment.trim();
    final dateLabel = _formatReviewDate(review.createdAt);
    final initial = username.isEmpty ? 'A' : username.substring(0, 1);
    final rating = review.rating.clamp(0, 5);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.red.withValues(alpha: 0.22),
                child: Text(
                  initial.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (dateLabel.isNotEmpty)
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$rating/5',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 2,
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                size: 16,
                color: Colors.amber,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            comment,
            style: const TextStyle(
              height: 1.35,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatReviewDate(int? createdAt) {
    if (createdAt == null || createdAt <= 0) return '';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(createdAt).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  Widget _analysisContainer(Content movie, ThemeData selectedThemeData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics Snapshot',
          style: TextStyle(
            color: selectedThemeData.primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metricChip(
              'Gross Revenue',
              _compactNum(movie.effectiveMediaHouseGrossRevenue),
            ),
            _metricChip(
              'Net Revenue',
              _compactNum(movie.effectiveMediaHouseNetRevenue),
            ),
            _metricChip(
              'Total Purchases',
              _compactNum(movie.totalPurchase ?? 0),
            ),
            _metricChip('Views', _compactNum(movie.views)),
            _metricChip('Likes', _compactNum(movie.ratingCount)),
            _metricChip(
              'Comments',
              _compactNum(movie.fullAttempt ?? movie.numberOfAttempt),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 460,
          child: MovieRevenueGraph(
            title: 'MovieDetailsGraph',
            yAxisLabel: 'sales',
            graphNumber: 0,
            contentId: movie,
            metrics: const ['revenue'],
          ),
        ),
      ],
    );
  }

  Widget _pendingStatusContainer(Content movie, ThemeData selectedThemeData) {
    final reason = (movie.reason ?? '').trim();
    final normalizedStatus = (movie.approvalStatus ?? '').toLowerCase();
    final isAgreementPending = normalizedStatus == 'agreement_pending';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Status',
          style: TextStyle(
            color: selectedThemeData.primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isAgreementPending
                ? const Color(0xFF7C3AED)
                : const Color(0xFFF5A524),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isAgreementPending ? 'APPROVED' : 'PENDING',
            style: TextStyle(
              color: isAgreementPending ? Colors.white : Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          reason.isEmpty
              ? (isAgreementPending
                  ? 'This content is waiting for signed agreement submission and onboarding charges before admin approval.'
                  : 'This content is pending for approval.')
              : 'Review Note: $reason',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _castPanel(
      Content movie, VideoProvider provider, ThemeData selectedThemeData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cast And Crew',
              style: TextStyle(
                color: selectedThemeData.primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddCastCrewDialog(context, movie, provider),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Cast & Crew', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedThemeData.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _castList(movie, provider),
      ],
    );
  }

  Widget _adminActionsRow(
    BuildContext context,
    Content movie,
    VideoProvider provider,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _actionButton(
          label: 'Play Trailer',
          icon: Icons.play_circle_fill,
          color: const Color(0xFFD81F26),
          onTap: () {
            provider.setValu(movie);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TrailerPage(trailerUrl: movie.trailerUrl ?? ''),
              ),
            );
          },
        ),
        if ((movie.teaserUrl ?? '').trim().isNotEmpty)
          _actionButton(
            label: 'Play Teaser',
            icon: Icons.play_circle_outline,
            color: const Color(0xFFE65100),
            onTap: () {
              provider.setValu(movie);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TrailerPage(trailerUrl: movie.teaserUrl!),
                ),
              );
            },
          ),
        _actionButton(
          label: 'Watch Movie',
          icon: Icons.movie_filter,
          color: const Color(0xFF125B50),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SecureContentPage(
                  contentId: (movie.id ?? widget.movieId).toString(),
                  contentUrl: movie.contentUrl ?? '',
                  contentType: secureContentType(movie.type),
                ),
              ),
            );
          },
        ),
        _actionButton(
          label: ContentTypeValue.isShortFilm(movie.type)
              ? 'Edit Short Film'
              : 'Edit Movie',
          icon: Icons.edit,
          color: const Color(0xFF1D4ED8),
          onTap: () async {
            provider.setValu(movie);
            final updated = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => EditVideoMovie(movie: movie),
              ),
            );
            if (updated == true && mounted) {
              await _fetchData();
            }
          },
        ),
        _actionButton(
          label: 'Delete',
          icon: Icons.delete_outline,
          color: const Color(0xFF8B1E1E),
          onTap: () => _confirmDelete(movie),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final selectedThemeData = Provider.of<ThemeProvider>(context).getTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailsSection(Content movie, ThemeData selectedThemeData) {
    final languageNames = (movie.languageList ?? [])
        .map((e) => e.language)
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Movie Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: selectedThemeData.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _statusInfoBanner(movie),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(4),
              },
              border: const TableBorder(
                horizontalInside: BorderSide(color: Colors.white24, width: 0.5),
              ),
              children: [
                _tableRow('Title', _displayValue(movie.title)),
                _tableRow(
                    'Content Type', ContentTypeValue.displayLabel(movie.type)),
                _tableRow(
                    'Approval Status', _displayValue(movie.approvalStatus)),
                _tableRow('Active', _boolLabel(movie.active)),
                _tableRow('Featured', _boolLabel(movie.isFeatured)),
                _tableRow('Downloadable', _boolLabel(movie.isDownloadable)),
                _tableRow('Edit Request Reason', movie.reason ?? 'N/A'),
                _tableRow(
                  'Director',
                  movie.directorList?.isNotEmpty == true
                      ? movie.directorList!.first
                      : 'Unknown',
                ),
                _tableRow(
                  'Cast',
                  movie.castList?.isNotEmpty == true
                      ? movie.castList!.join(', ')
                      : 'N/A',
                ),
                _tableRow(
                  'Genres',
                  movie.genreList?.isNotEmpty == true
                      ? movie.genreList!.join(', ')
                      : 'N/A',
                ),
                _tableRow('Runtime', _displayValue(movie.runtime)),
                _tableRow('Release Date', _displayValue(movie.releaseDate)),
                _tableRow(
                  'Languages',
                  languageNames.isNotEmpty ? languageNames.join(', ') : 'N/A',
                ),
                _tableRow('Rating', '${movie.ratings ?? 0} *'),
                _tableRow('Rating Count', _displayValue(movie.ratingCount)),
                _tableRow(
                    'Audio Formats', (movie.audioFormatList ?? []).join(', ')),
                _tableRow(
                  'Subtitles',
                  (movie.subtitleLanguageList ?? []).join(', '),
                ),
                _tableRow('Age Rating', movie.ageRating ?? 'N/A'),
                _tableRow(
                    'Production House', _displayValue(movie.mediaHouseName)),
                _tableRow('Price', _formatPrice(movie.price)),
                _tableRow(
                    'Total Purchases', _compactNum(movie.totalPurchase ?? 0)),
                _tableRow(
                    'Rental Duration', _displayValue(movie.rentlDuration)),
                _tableRow(
                    'No. of Attempts', _displayValue(movie.numberOfAttempt)),
                _tableRow(
                  'Registration Fee Paid',
                  _displayValue(movie.registrationFeePaid),
                ),
                _tableRow(
                  'Registration Fee Details',
                  _displayValue(movie.registrationFeeDetails),
                ),
                _tableRow(
                  'Regions',
                  (movie.availability?.regions ?? []).isNotEmpty
                      ? movie.availability!.regions!.join(', ')
                      : 'N/A',
                ),
                _tableRow(
                  'Platforms',
                  (movie.availability?.platforms ?? []).isNotEmpty
                      ? movie.availability!.platforms!.join(', ')
                      : 'N/A',
                ),
                _tableRow('Uploaded On', _formatEpoch(movie.uploadDateTime)),
                _tableRow('Approved On', _formatEpoch(movie.approvedDateTime)),
                _tableRow(
                  'Platform Percentage',
                  _displayValue(movie.adminIncentivePecentage),
                ),
                _tableRow(
                  'MediaHouse Percentage',
                  _displayValue(movie.mediaHouseIncentivePecentage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusInfoBanner(Content movie) {
    final status = (movie.approvalStatus ?? '').toLowerCase();
    final reason = (movie.reason ?? '').trim();
    if (status != 'pending' && status != 'rejected') {
      return const SizedBox();
    }

    final isRejected = status == 'rejected';
    final title = isRejected ? 'Rejected' : 'Pending Approval';
    final notePrefix = isRejected ? 'Reason For Rejection' : 'Review Note';

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:
            (isRejected ? Colors.red : Colors.orange).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        reason.isEmpty ? title : '$title\n$notePrefix : $reason',
        style: TextStyle(
          color: isRejected ? Colors.redAccent : Colors.orangeAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _censorCertificateCard(Content movie) {
    final certUrl = movie.sensorCertificate;
    final selectedThemeData = Provider.of<ThemeProvider>(context).getTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Censor Certificate',
          style: TextStyle(
            color: selectedThemeData.primaryColor,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        if (certUrl != null && certUrl.trim().isNotEmpty)
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.black,
                  child: InteractiveViewer(child: Image.network(certUrl)),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                certUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 180,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 180,
                    alignment: Alignment.center,
                    child: Text(
                      'Image not available',
                      style: TextStyle(color: selectedThemeData.canvasColor),
                    ),
                  );
                },
              ),
            ),
          )
        else
          Container(
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selectedThemeData.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Certificate not available',
              style: TextStyle(color: selectedThemeData.canvasColor),
            ),
          ),
      ],
    );
  }

  Widget _mediaPreviewCard({
    required String title,
    required String? url,
  }) {
    final selectedThemeData = Provider.of<ThemeProvider>(context).getTheme;
    final mediaUrl = url?.trim() ?? '';
    if (mediaUrl.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selectedThemeData.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: selectedThemeData.canvasColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: Center(
                child: Text(
                  '$title not available',
                  style: TextStyle(
                    color:
                        selectedThemeData.canvasColor.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: selectedThemeData.canvasColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 320,
            width: double.infinity,
            child: TrailerPage(trailerUrl: mediaUrl),
          ),
        ],
      ),
    );
  }

  Widget _castList(Content movie, VideoProvider provider) {
    final selectedThemeData = Provider.of<ThemeProvider>(context).getTheme;
    final apiCast = provider.contentCastList;
    if (apiCast.isNotEmpty) {
      return SizedBox(
        height: 125,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: apiCast.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = apiCast[index];
            final name = (item['name'] ?? item['castName'] ?? '').toString().trim();
            final role = (item['role'] ?? item['castRole'] ?? '').toString().trim();
            final image = (item['image'] ?? item['imageUrl'] ?? item['castImage'] ?? '').toString().trim();
            return SizedBox(
              width: 84,
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: _avatarColor(index),
                        backgroundImage:
                            image.isNotEmpty ? NetworkImage(image) : null,
                        child: image.isEmpty
                            ? Text(
                                _initials(name),
                                style: TextStyle(
                                  color: selectedThemeData.cardColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: InkWell(
                          onTap: () => _showEditCastCrewDialog(
                              context, item, movie, provider),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: selectedThemeData.primaryColor,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name.isEmpty ? 'N/A' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: selectedThemeData.canvasColor, fontSize: 11),
                  ),
                  Text(
                    role.isEmpty ? '-' : role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: selectedThemeData.canvasColor, fontSize: 10),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    final cast =
        (movie.castList ?? []).where((e) => e.trim().isNotEmpty).toList();
    if (cast.isEmpty) {
      return const Text('N/A', style: TextStyle(color: Colors.white70));
    }

    return SizedBox(
      height: 115,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cast.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final name = cast[index];
          final fallbackItem = {
            'castId': 0,
            'contentId': widget.movieId,
            'name': name,
            'role': '',
            'description': '',
            'image': '',
          };
          return SizedBox(
            width: 76,
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: _avatarColor(index),
                      child: Text(
                        _initials(name),
                        style: TextStyle(
                          color: selectedThemeData.canvasColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: InkWell(
                        onTap: () => _showEditCastCrewDialog(
                            context, fallbackItem, movie, provider),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: selectedThemeData.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: selectedThemeData.canvasColor, fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddCastCrewDialog(
    BuildContext pageContext,
    Content movie,
    VideoProvider provider,
  ) {
    final selectedThemeData = Provider.of<ThemeProvider>(context, listen: false).getTheme;
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    final descriptionController = TextEditingController();

    PlatformFile? selectedImageFile;
    String uploadedImageUrl = '';
    bool isUploadingImage = false;
    bool isSaving = false;

    showDialog(
      context: pageContext,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickImage() async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
                  withData: true,
                );
                if (result != null && result.files.isNotEmpty) {
                  setDialogState(() {
                    selectedImageFile = result.files.single;
                    isUploadingImage = true;
                  });
                  final url = await provider.uploadSingleImageFile(selectedImageFile!);
                  setDialogState(() {
                    if (url != null && url.isNotEmpty) {
                      uploadedImageUrl = url;
                    }
                    isUploadingImage = false;
                  });
                }
              } catch (e) {
                setDialogState(() {
                  isUploadingImage = false;
                });
                CustomToast.show(dialogContext, 'Failed to pick image: $e', isSuccess: false);
              }
            }

            Future<void> onAddPressed() async {
              final name = nameController.text.trim();
              final role = roleController.text.trim();
              if (name.isEmpty || role.isEmpty) {
                CustomToast.show(dialogContext, 'Please enter name and role.', isSuccess: false);
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              if (selectedImageFile != null && uploadedImageUrl.isEmpty) {
                final url = await provider.uploadSingleImageFile(selectedImageFile!);
                if (url != null && url.isNotEmpty) {
                  uploadedImageUrl = url;
                }
              }

              final success = await provider.addDirectCastMember(
                dialogContext,
                contentId: widget.movieId,
                name: name,
                role: role,
                description: descriptionController.text.trim(),
                image: uploadedImageUrl,
              );

              if (success) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                await _fetchData();
              } else {
                setDialogState(() {
                  isSaving = false;
                });
              }
            }

            return Dialog(
              backgroundColor: selectedThemeData.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add Cast & Crew',
                            style: TextStyle(
                              color: selectedThemeData.primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: selectedThemeData.canvasColor),
                            onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: selectedThemeData.primaryColor.withOpacity(0.15),
                              backgroundImage: uploadedImageUrl.isNotEmpty
                                  ? NetworkImage(uploadedImageUrl)
                                  : (selectedImageFile != null && selectedImageFile!.bytes != null
                                      ? MemoryImage(selectedImageFile!.bytes!)
                                      : null) as ImageProvider?,
                              child: isUploadingImage
                                  ? const CircularProgressIndicator(strokeWidth: 2)
                                  : (uploadedImageUrl.isEmpty && selectedImageFile == null
                                      ? Icon(Icons.person, size: 40, color: selectedThemeData.primaryColor)
                                      : null),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: InkWell(
                                onTap: (isSaving || isUploadingImage) ? null : pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: selectedThemeData.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        enabled: !isSaving,
                        style: TextStyle(color: selectedThemeData.canvasColor),
                        decoration: InputDecoration(
                          labelText: 'Name *',
                          labelStyle: TextStyle(color: selectedThemeData.canvasColor.withOpacity(0.7)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: roleController,
                        enabled: !isSaving,
                        style: TextStyle(color: selectedThemeData.canvasColor),
                        decoration: InputDecoration(
                          labelText: 'Role / Designation *',
                          labelStyle: TextStyle(color: selectedThemeData.canvasColor.withOpacity(0.7)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descriptionController,
                        enabled: !isSaving,
                        maxLines: 2,
                        style: TextStyle(color: selectedThemeData.canvasColor),
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          labelStyle: TextStyle(color: selectedThemeData.canvasColor.withOpacity(0.7)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                            child: Text('Cancel', style: TextStyle(color: selectedThemeData.canvasColor)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: (isSaving || isUploadingImage) ? null : onAddPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedThemeData.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Add'),
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
  }

  void _showEditCastCrewDialog(
    BuildContext pageContext,
    Map<String, dynamic> item,
    Content movie,
    VideoProvider provider,
  ) {
    final selectedThemeData = Provider.of<ThemeProvider>(context, listen: false).getTheme;

    final int castId = int.tryParse(item['castId']?.toString() ?? item['id']?.toString() ?? '0') ?? 0;
    final int contentId = int.tryParse(item['contentId']?.toString() ?? '0') ?? widget.movieId;
    final String initialName = (item['name'] ?? item['castName'] ?? '').toString();
    final String initialRole = (item['role'] ?? item['castRole'] ?? '').toString();
    final String initialDesc = (item['description'] ?? '').toString();
    final String initialImage = (item['image'] ?? item['imageUrl'] ?? item['castImage'] ?? '').toString();
    final int seasonId = int.tryParse(item['seasonId']?.toString() ?? '0') ?? 0;
    final int shortId = int.tryParse(item['shortId']?.toString() ?? '0') ?? 0;

    final nameController = TextEditingController(text: initialName);
    final roleController = TextEditingController(text: initialRole);
    final descriptionController = TextEditingController(text: initialDesc);

    PlatformFile? selectedImageFile;
    String currentImageUrl = initialImage;
    bool isUploadingImage = false;
    bool isSaving = false;

    showDialog(
      context: pageContext,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickImage() async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
                  withData: true,
                );
                if (result != null && result.files.isNotEmpty) {
                  setDialogState(() {
                    selectedImageFile = result.files.single;
                    isUploadingImage = true;
                  });
                  final url = await provider.uploadSingleImageFile(selectedImageFile!);
                  setDialogState(() {
                    if (url != null && url.isNotEmpty) {
                      currentImageUrl = url;
                    }
                    isUploadingImage = false;
                  });
                }
              } catch (e) {
                setDialogState(() {
                  isUploadingImage = false;
                });
                CustomToast.show(dialogContext, 'Failed to pick image: $e', isSuccess: false);
              }
            }

            Future<void> onUpdatePressed() async {
              final name = nameController.text.trim();
              final role = roleController.text.trim();
              if (name.isEmpty || role.isEmpty) {
                CustomToast.show(dialogContext, 'Please enter name and role.', isSuccess: false);
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              if (selectedImageFile != null && currentImageUrl == initialImage) {
                final url = await provider.uploadSingleImageFile(selectedImageFile!);
                if (url != null && url.isNotEmpty) {
                  currentImageUrl = url;
                }
              }

              final success = await provider.updateCastMember(
                dialogContext,
                castId: castId,
                contentId: contentId > 0 ? contentId : widget.movieId,
                name: name,
                role: role,
                description: descriptionController.text.trim(),
                image: currentImageUrl,
                seasonId: seasonId,
                shortId: shortId,
              );

              if (success) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                await _fetchData();
              } else {
                setDialogState(() {
                  isSaving = false;
                });
              }
            }

            return Dialog(
              backgroundColor: selectedThemeData.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Edit Cast & Crew',
                            style: TextStyle(
                              color: selectedThemeData.primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: selectedThemeData.canvasColor),
                            onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: selectedThemeData.primaryColor.withOpacity(0.15),
                              backgroundImage: currentImageUrl.isNotEmpty
                                  ? NetworkImage(currentImageUrl)
                                  : (selectedImageFile != null && selectedImageFile!.bytes != null
                                      ? MemoryImage(selectedImageFile!.bytes!)
                                      : null) as ImageProvider?,
                              child: isUploadingImage
                                  ? const CircularProgressIndicator(strokeWidth: 2)
                                  : (currentImageUrl.isEmpty && selectedImageFile == null
                                      ? Icon(Icons.person, size: 40, color: selectedThemeData.primaryColor)
                                      : null),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: InkWell(
                                onTap: (isSaving || isUploadingImage) ? null : pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: selectedThemeData.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        enabled: !isSaving,
                        style: TextStyle(color: selectedThemeData.canvasColor),
                        decoration: InputDecoration(
                          labelText: 'Name *',
                          labelStyle: TextStyle(color: selectedThemeData.canvasColor.withOpacity(0.7)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: roleController,
                        enabled: !isSaving,
                        style: TextStyle(color: selectedThemeData.canvasColor),
                        decoration: InputDecoration(
                          labelText: 'Role / Designation *',
                          labelStyle: TextStyle(color: selectedThemeData.canvasColor.withOpacity(0.7)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descriptionController,
                        enabled: !isSaving,
                        maxLines: 2,
                        style: TextStyle(color: selectedThemeData.canvasColor),
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          labelStyle: TextStyle(color: selectedThemeData.canvasColor.withOpacity(0.7)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                            child: Text('Cancel', style: TextStyle(color: selectedThemeData.canvasColor)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: (isSaving || isUploadingImage) ? null : onUpdatePressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedThemeData.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Update'),
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
  }

  Widget _surfaceCard({Widget? child, EdgeInsets? padding}) {
    final selectedThemeData = Provider.of<ThemeProvider>(context).getTheme;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [selectedThemeData.cardColor, selectedThemeData.cardColor],
        ),
      ),
      child: child,
    );
  }

  Widget _staggeredSection({required int index, required Widget child}) {
    final start = math.min(0.16 * index, 0.68);
    final animation = CurvedAnimation(
      parent: _fadeAnimation,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(animation);

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
  }

  Widget _statusPill(String label) {
    final normalized = label.toLowerCase();
    final isPending = normalized == 'pending';
    final isRejected = normalized == 'rejected';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPending
            ? const Color(0xFFF5A524)
            : (isRejected ? const Color(0xFF8B1E1E) : const Color(0xFF1F9D55)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isPending ? Colors.black : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _metaPill(IconData icon, String value) {
    final selectedThemeData = Provider.of<ThemeProvider>(context).getTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: selectedThemeData.canvasColor),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: selectedThemeData.canvasColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    final selectedThemeData = Provider.of<ThemeProvider>(context).getTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: selectedThemeData.splashColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: selectedThemeData.canvasColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: selectedThemeData.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posterFallback() {
    final selectedThemeData = Provider.of<ThemeProvider>(context).getTheme;
    return Container(
      color: selectedThemeData.cardColor,
      alignment: Alignment.center,
      child: const Icon(
        Icons.movie_creation_outlined,
        color: Colors.white38,
        size: 52,
      ),
    );
  }

  TableRow _tableRow(String title, String value) {
    final selectedThemeData = Provider.of<ThemeProvider>(context).getTheme;
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selectedThemeData.canvasColor,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selectedThemeData.canvasColor,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(Content movie) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).getTheme;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Do you want to delete ${movie.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<VideoProvider>(context, listen: false)
                  .deleteVideo(movie.id!, context);
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  bool _isPending(Content movie, ThemeData selectedThemeData) =>
      (movie.approvalStatus ?? '').toLowerCase() == 'pending' ||
      (movie.approvalStatus ?? '').toLowerCase() == 'agreement_pending';

  String _moviePoster(Content movie) {
    final list = movie.posterUrlList ?? const [];
    for (final url in list) {
      if (url.trim().isNotEmpty) return url.trim();
    }
    return '';
  }

  String _heroMetaLine(Content movie) {
    final release = _displayValue(movie.releaseDate);
    final runtime = _displayValue(movie.runtime);
    final rating = _displayValue(movie.ageRating);
    final genres =
        (movie.genreList ?? []).where((e) => e.trim().isNotEmpty).join(', ');
    return [release, runtime, rating, if (genres.isNotEmpty) genres]
        .join('  •  ');
  }

  String _displayValue(dynamic value) {
    if (value == null) return 'N/A';
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return 'N/A';
    return text;
  }

  String _formatPrice(dynamic price) {
    if (price == null) return 'N/A';
    return formatCurrency(price, symbol: 'Rs ');
  }

  String _boolLabel(dynamic value) {
    if (value == null) return 'N/A';
    if (value is bool) return value ? 'Yes' : 'No';
    final text = value.toString().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return 'Yes';
    if (text == 'false' || text == '0' || text == 'no') return 'No';
    return _displayValue(value);
  }

  String _formatEpoch(int? epoch) {
    if (epoch == null || epoch <= 0) return 'N/A';
    final isMilliseconds = epoch > 9999999999;
    final date = DateTime.fromMillisecondsSinceEpoch(
      isMilliseconds ? epoch : epoch * 1000,
    );
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$dd-$mm-$yyyy $hh:$min';
  }

  String _compactNum(dynamic value) {
    if (value == null) return '0';
    final n = double.tryParse(value.toString()) ?? 0;
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    if (n % 1 == 0) return n.toInt().toString();
    return n.toStringAsFixed(1);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return 'NA';
    if (list.length == 1) return list.first.substring(0, 1).toUpperCase();
    return (list.first.substring(0, 1) + list.last.substring(0, 1))
        .toUpperCase();
  }

  Color _avatarColor(int index) {
    const palette = [
      Color(0xFF315C8A),
      Color(0xFF7B4B94),
      Color(0xFF5A7D3F),
      Color(0xFF8A5A31),
      Color(0xFF2F7C7B),
    ];
    return palette[index % palette.length];
  }

  Widget _darkOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.52),
            Colors.black.withValues(alpha: 0.9),
          ],
        ),
      ),
    );
  }
}
