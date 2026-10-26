import 'package:flutter/material.dart';
import 'package:media_house/app/core/constant/image_constant.dart';
import 'package:media_house/app/ui/pages/secure_content_page.dart';
import 'package:media_house/data/models/response/signed_playback.dart';
import 'package:media_house/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';

import '../../../../../data/models/response/short_detail_response.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/utils/sharepreferences.dart';
import '../../../../provider/shorts_provider.dart';
import 'create_short_parts_page.dart';
import 'edit_short_master_page.dart';
import 'edit_short_part.dart';

class ShortMasterPage extends StatefulWidget {
  final int shortId;

  const ShortMasterPage({super.key, required this.shortId});

  @override
  State<ShortMasterPage> createState() => _ShortMasterPageState();
}

class _ShortMasterPageState extends State<ShortMasterPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetail(widget.shortId);
    });
  }

  Future<void> _fetchDetail(int shortId) async {
    final user = await LocalSharePreferences().getUser();
    final userId = user?.id;
    if (!mounted || userId == null || userId <= 0) return;
    await context.read<ShortProvider>().fetchShortDetail(
          shortId: shortId,
          userId: userId,
        );
  }

  void _editShort(BuildContext context, ShortDetailModel shortModel) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: EditShortMasterDialog(
          shortId: widget.shortId,
          shortDetailModel: shortModel,
        ),
      ),
    );
    if (result == true && mounted) {
      await _fetchDetail(widget.shortId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShortProvider>();
    final theme = Theme.of(context);

    if (provider.isDetailLoading) {
      return Scaffold(
        body: Center(
            child: CircularProgressIndicator(
          color: theme.primaryColor,
        )),
      );
    }

    if (provider.detailError != null) {
      return Scaffold(
        body: Center(child: Text(provider.detailError!)),
      );
    }

    final short = provider.shortDetail!;
    final createdPartCount = short.data!.parts?.length ?? 0;
    final languages = (short.data!.languageList ?? [])
        .map((lang) => lang.language?.trim() ?? '')
        .where((lang) => lang.isNotEmpty)
        .join(', ');

    final crossAxisCount = ResponsiveWidget.isDesktop(context)
        ? 5
        : ResponsiveWidget.isTablet(context)
            ? 4
            : 2;

    final tileHeight = ResponsiveWidget.isDesktop(context)
        ? 220.0
        : ResponsiveWidget.isTablet(context)
            ? 200.0
            : 180.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        title: Text(
          short.data!.title ?? "",
          style: TextStyle(color: theme.canvasColor),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Edit Short",
            icon: Icon(Icons.edit, color: theme.primaryColor),
            onPressed: () {
              _editShort(context, short.data!);
            },
          ),
          IconButton(
            tooltip: "Delete Short",
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(context, short.data!.id!),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------------------
            // MASTER DETAILS
            // -----------------------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    short.data!.poster ?? "",
                    height: 180,
                    width: 130,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: Image.asset(ImageConstant.coin),
                          ),
                          Text(
                            " ${short.data!.coinsPerPart ?? 0} / part",
                            style: TextStyle(
                              color: theme.canvasColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        short.data!.title ?? "",
                        style: TextStyle(
                          color: theme.canvasColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Creator: ${short.data!.creatorName}",
                        style: TextStyle(
                            color: theme.canvasColor.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Category: ${short.data!.category}",
                        style: TextStyle(
                            color: theme.canvasColor.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Rental Duration: ${short.data!.rentlDuration?.trim().isNotEmpty == true ? short.data!.rentlDuration : 'N/A'}",
                        style: TextStyle(
                            color: theme.canvasColor.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Languages: ${languages.isNotEmpty ? languages : 'N/A'}",
                        style: TextStyle(
                            color: theme.canvasColor.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 10),
                      if (short.data!.isTrending!)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "TRENDING",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        short.data!.description ?? "",
                        style: TextStyle(
                            color: theme.canvasColor.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // -----------------------------------------------------------------
            // STATS
            // -----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.canvasColor.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoTile(
                      "Total Parts", short.data!.totalParts.toString(), theme),
                  _buildInfoTile(
                      "Views", short.data!.viewCount.toString(), theme),
                  _buildInfoTile(
                      "Likes", short.data!.likeCount.toString(), theme),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // -----------------------------------------------------------------
            // SHORT PARTS
            // -----------------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Short Videos",
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    createdPartCount >= short.data!.totalParts!
                        ? "All Parts Added"
                        : "Add Parts",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: createdPartCount >= short.data!.totalParts!
                        ? Colors.grey
                        : theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 4,
                  ),
                  onPressed: createdPartCount >= short.data!.totalParts!
                      ? null
                      : () async {
                          final result = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.all(24),
                              child: Center(
                                child: CreateShortPartsDialog(
                                  shortId: short.data!.id ?? 0,
                                  totalParts: short.data!.totalParts ?? 0,
                                  existingPartCount:
                                      short.data!.parts?.length ?? 0,
                                  masterTitle: short.data!.title ?? '',
                                  masterDescription:
                                      short.data!.description ?? '',
                                  defaultCoins: short.data!.coinsPerPart ?? 0,
                                ),
                              ),
                            ),
                          );

                          if (result == true && mounted) {
                            await _fetchDetail(short.data!.id ?? 0);
                          }
                        },
                ),
              ],
            ),

            const SizedBox(height: 14),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: short.data!.parts!.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: tileHeight,
              ),
              itemBuilder: (_, index) {
                final part = short.data!.parts?[index];
                return _buildPartTile(theme,
                    partNumber: part!.partNumber.toString(),
                    thumbnailUrl: part.thumbnail ?? "",
                    isFreePreview: part.isFreePreview!,
                    hasVideo: part.videoUrl!.isNotEmpty,
                    videoUrl: part.videoUrl ?? '',
                    views: part.views ?? 0,
                    likes: part.likes ?? 0,
                    partId: part.partId,
                    part: part);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // WIDGETS
  // ==========================================================================

  Widget _buildInfoTile(String title, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: theme.canvasColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: theme.canvasColor.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPartTile(
    ThemeData theme, {
    required String partNumber,
    required String thumbnailUrl,
    required bool isFreePreview,
    required bool hasVideo,
    required String videoUrl,
    int views = 0,
    int likes = 0,
    String? partId,
    required ShortPartModel part,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          /// THUMBNAIL
          Image.network(
            thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: theme.cardColor.withOpacity(0.2),
              child: Center(
                child: Text(
                  "Part $partNumber",
                  style: TextStyle(color: theme.canvasColor),
                ),
              ),
            ),
          ),

          /// ▶ PLAY ICON
          if (hasVideo)
            InkWell(
              onTap: () {
                _playVideo(context, videoUrl);
              },
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ),

          /// 🟢 FREE / PART TAG
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isFreePreview
                    ? Colors.green
                    : Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isFreePreview ? "FREE" : "Part $partNumber",
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),

          /// ✏️ 🗑 EDIT / DELETE ACTIONS
          Positioned(
            top: 6,
            right: 6,
            child: Row(
              children: [
                /// EDIT
                _actionIcon(
                  icon: Icons.edit,
                  color: Colors.orange,
                  onTap: () {
                    _editPart(context, part);
                  },
                ),
                const SizedBox(width: 6),

                /// DELETE
                _actionIcon(
                  icon: Icons.delete,
                  color: Colors.red,
                  onTap: () {
                    _confirmDeletePart(context, partId!);
                  },
                ),
              ],
            ),
          ),

          /// 👁❤️ STATS OVERLAY
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                /// 👁 VIEWS
                _statChip(
                  icon: Icons.remove_red_eye,
                  value: views,
                ),

                /// ❤️ LIKES
                _statChip(
                  icon: Icons.favorite,
                  value: likes,
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  void _confirmDeletePart(BuildContext context, String partId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Part"),
        content: const Text("Are you sure you want to delete this part?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);

              final provider = context.read<ShortProvider>();

              final success = await provider.deleteShortPart(
                partId: partId,
              );

              if (!mounted) return;

              if (success) {
                // 🔄 refresh short details
                await _fetchDetail(widget.shortId);

                globalMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text("Part deleted successfully")),
                );
              } else {
                globalMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text("Failed to delete part")),
                );
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _editPart(BuildContext context, ShortPartModel part) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: EditShortPartDialog(
          shortId: widget.shortId,
          part: part,
        ),
      ),
    );

    if (result == true && mounted) {
      await _fetchDetail(widget.shortId);
    }
  }

  Widget _statChip({
    required IconData icon,
    required int value,
    Color color = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DELETE
  // ==========================================================================

  void _confirmDelete(BuildContext context, int shortId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Short"),
        content: const Text("Are you sure you want to delete this short?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);

              final provider = context.read<ShortProvider>();
              final success =
                  await provider.deleteShortMaster(shortId: shortId);

              if (!mounted) return;

              if (success) {
                Navigator.pop(context, true);
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _playVideo(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: SecureContentPage(
            contentId: widget.shortId.toString(),
            contentUrl: videoUrl,
            contentType: secureContentType('SHORT_FILM'),
          ),
        ),
      ),
    );
  }
}
