import 'package:media_house/app/ui/pages/dashboard_page/components/financial_breakdown_card.dart';
import 'package:media_house/app/ui/pages/dashboard_page/components/movie_transactions_table.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_house/app/provider/mediaHouseProvider.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/provider/user_provider.dart';
import 'package:media_house/app/ui/pages/dashboard_page/components/settlementCards.dart';
import 'package:media_house/app/ui/pages/dashboard_page/components/buildSummaryCard.dart';
import 'package:media_house/app/ui/pages/dashboard_page/components/contentUploadCrad.dart';
import 'package:media_house/app/ui/pages/profile%20page/ProfilePage.dart';
import 'package:media_house/app/ui/pages/uploadContent_page/select_upload_type.dart';
import 'package:media_house/app/widget/CustomLineGraph.dart';
import 'package:media_house/app/widget/TopMoviesLineGraph.dart';
import 'package:media_house/app/widget/show_toast.dart';
import 'package:media_house/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/sharepreferences.dart';

class DashboardPage extends StatefulWidget {
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  ImageProvider? _logoImage(String? value) {
    final url = value?.trim();
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    return NetworkImage(url);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getData();
    });
  }

  Future<void> getData() async {
    final mediaHouseProvider =
        Provider.of<MediaHouseProvider>(context, listen: false);
    final localSharePreferences = LocalSharePreferences();
    final user = await localSharePreferences.getUser();
    print(user!.firstName! + ':::::::::UserName:::::::');
    final mediaHouse = await localSharePreferences.getMediaHouse();
    print(mediaHouse!.mediaHouseName! + ':::::::::MediaHouse:::::::');
    if (mounted) {
      await Provider.of<UserProvider>(context, listen: false)
          .getUserById(user.id!);
      await Provider.of<UserProvider>(context, listen: false)
          .fetchMediaHouseByUserId(user.id!, context);
    }
    await mediaHouseProvider.fetchMediaHouseByUserId(user.id!);
    if (mediaHouseProvider.mediaHouse.id != null && mediaHouseProvider.mediaHouse.id! > 0) {
      await Future.wait([
        mediaHouseProvider.fetchMediaHouseDashboardData(mediaHouseProvider.mediaHouse.id!),
        mediaHouseProvider.fetchMovieTransactions(mediaHouseProvider.mediaHouse.id!),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedThemeData =
        Provider.of<ThemeProvider>(context, listen: true).getTheme;
    Provider.of<UserProvider>(context);

    return Consumer<MediaHouseProvider>(builder: (context, provider, child) {
      return Scaffold(
        backgroundColor: selectedThemeData.scaffoldBackgroundColor,
        body: RefreshIndicator(
          onRefresh: getData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                EdgeInsets.all(ResponsiveWidget.isMobile(context) ? 12 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dashboardHeader(selectedThemeData, provider, context),
                    const SizedBox(height: 24),
                    _sectionTitle(
                      selectedThemeData,
                      'Overview',
                      'A snapshot of revenue, audience and content activity.',
                    ),
                    const SizedBox(height: 12),
                    _summaryGrid(selectedThemeData, provider),
                    const SizedBox(height: 28),
                    _sectionTitle(
                      selectedThemeData,
                      'Financial Breakdown',
                      'Detailed revenue split across taxes, platform fees, and net creator earnings.',
                    ),
                    const SizedBox(height: 12),
                    FinancialBreakdownCard(data: provider.mediaHouseDashboardData),
                    const SizedBox(height: 28),
                    _sectionTitle(
                      selectedThemeData,
                      'Movie Transactions',
                      'Individual purchase orders and earnings per movie title.',
                    ),
                    const SizedBox(height: 12),
                    MovieTransactionsTable(
                      transactions: provider.movieTransactions,
                      isLoading: provider.isLoadingMovieTransactions,
                    ),
                    const SizedBox(height: 28),
                    _sectionTitle(
                      selectedThemeData,
                      'Performance',
                      'Upload content and review your top-performing titles.',
                    ),
                    const SizedBox(height: 12),
                    _performanceSection(selectedThemeData, provider),
                    const SizedBox(height: 28),
                    _sectionTitle(
                      selectedThemeData,
                      'Weekly settlements',
                      'Review settlement batches and open their reports.',
                    ),
                    const SizedBox(height: 12),
                    const SettlementCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _dashboardHeader(
      ThemeData theme, MediaHouseProvider provider, BuildContext context) {
    final approved =
        (provider.mediaHouse.status ?? 'PENDING').toUpperCase() == 'APPROVED';
    final logo = _logoImage(provider.mediaHouse.logo);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => ProfilePage())),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: ResponsiveWidget.isMobile(context) ? 25 : 31,
                  backgroundImage: logo,
                  child: logo == null ? const Icon(Icons.business) : null,
                ),
                if (approved)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified,
                          color: Colors.blue, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.mediaHouse.mediaHouseName ?? 'Production House',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontSize: ResponsiveWidget.isMobile(context) ? 18 : 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.mediaHouse.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: theme.canvasColor.withValues(alpha: .65)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildActionButton(theme, Icons.file_upload_outlined,
              'Upload Content', context, provider),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title, String subtitle) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: theme.canvasColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: TextStyle(color: theme.canvasColor.withValues(alpha: .6))),
        ],
      );

  Widget _summaryGrid(ThemeData theme, MediaHouseProvider provider) {
    final d = provider.mediaHouseDashboardData;
    final finalRevenue = d.finalProductionHouseRevenue ??
        d.productionHouseRevenue ??
        d.mediaHouseNetRevenue ??
        0.0;
    final grossCustPayment = d.customerPayment ?? d.mediaHouseGrossRevenue ?? 0.0;

    final cards = <Widget>[
      BuildSummaryCard(
        icon: Icons.currency_rupee_sharp,
        title: 'Final Net Share',
        value: formatCurrency(finalRevenue),
        onTap: () => _showGraphDialog(
          theme: theme,
          title: 'Revenue Graph',
          yAxisLabel: 'sales',
          graphNumber: 0,
          metrics: const ['revenue'],
        ),
      ),
      BuildSummaryCard(
        icon: Icons.payments_outlined,
        title: 'Customer Payment',
        value: formatCurrency(grossCustPayment),
        onTap: () {},
      ),
      BuildSummaryCard(
        icon: Icons.visibility_outlined,
        title: 'Total Views',
        value: '${d.totalViews ?? 0}',
        onTap: () => _showGraphDialog(
          theme: theme,
          title: 'Views Graph',
          yAxisLabel: 'views',
          graphNumber: 1,
          metrics: const ['views'],
        ),
      ),
      BuildSummaryCard(
        icon: Icons.play_circle_outline_sharp,
        title: 'Live Content',
        value: '${d.liveContent ?? d.approvedContent ?? 0}',
        onTap: () => _showGraphDialog(
          theme: theme,
          title: 'Released Content',
          yAxisLabel: 'Released',
          graphNumber: 2,
          metrics: const ['Released'],
        ),
      ),
      BuildSummaryCard(
        icon: Icons.hourglass_top_outlined,
        title: 'Pending Content',
        value: '${d.pendingContent ?? d.pendingContentCount ?? 0}',
        onTap: () {},
      ),
      BuildSummaryCard(
        icon: Icons.schedule,
        title: 'Upcoming Content',
        value: '${d.upcomingContent ?? d.upcomingContentCount ?? 0}',
        onTap: () {},
      ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1200
          ? 6
          : constraints.maxWidth >= 800
              ? 3
              : 2;
      final cardHeight = constraints.maxWidth < 500 ? 128.0 : 142.0;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: cardHeight,
        ),
        itemBuilder: (_, index) => cards[index],
      );
    });
  }

  Widget _performanceSection(ThemeData theme, MediaHouseProvider provider) {
    final graph = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: theme.cardColor,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.dividerColor.withValues(alpha: .22)),
        ),
        padding: const EdgeInsets.all(12),
        child: const TopMoviesLineGraph(isRevenue: true),
      ),
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 900) {
        return Column(
          children: [
            SizedBox(
                height: 250, child: ContentUploadCard(provider.mediaHouse)),
            const SizedBox(height: 12),
            SizedBox(
                height: constraints.maxWidth < 500 ? 480 : 420, child: graph),
          ],
        );
      }
      return SizedBox(
        height: 430,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: ContentUploadCard(provider.mediaHouse)),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: graph),
          ],
        ),
      );
    });
  }

  void _showGraphDialog({
    required ThemeData theme,
    required String title,
    required String yAxisLabel,
    required int graphNumber,
    required List<String> metrics,
  }) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = math.min(size.width * 0.95, 1100.0);
    final dialogHeight = math.min(size.height * 0.9, 760.0);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: theme.cardColor,
          insetPadding: EdgeInsets.symmetric(
            horizontal: ResponsiveWidget.isMobile(context) ? 10 : 24,
            vertical: ResponsiveWidget.isMobile(context) ? 16 : 24,
          ),
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: CustomLineGraph(
              title: title,
              yAxisLabel: yAxisLabel,
              canPop: true,
              graphNumber: graphNumber,
              metrics: metrics,
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(ThemeData theme, IconData icon, String tooltip,
      BuildContext context, MediaHouseProvider provider) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.cardColor,
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: IconButton(
          highlightColor: theme.primaryColor,
          tooltip: tooltip,
          onPressed: () {
            (provider.mediaHouse.status ?? 'PENDING').toUpperCase() ==
                    "APPROVED"
                ? showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => SelectUploadTypeDialog(),
                  )
                : CustomToast.show(
                    context, "First you need to get approval from admin",
                    isSuccess: false);
          },
          icon: Icon(
            icon,
            color: theme.canvasColor,
          ),
        ),
      ),
    );
  }
}
