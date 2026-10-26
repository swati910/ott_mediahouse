import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/ui/pages/shorts/components/add_short_master.dart';
import 'package:media_house/app/ui/pages/uploadContent_page/upload_video.dart';
import 'package:media_house/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';

class SelectUploadTypeDialog extends StatelessWidget {
  const SelectUploadTypeDialog({super.key});

  static const _uploadTypes = [
    _UploadOption(
      title: 'Upload Movie',
      description: 'Feature films and full-length movies',
      icon: Icons.movie_creation_rounded,
    ),
    _UploadOption(
      title: 'Upload Short Film',
      description: 'Short-form films and stories',
      icon: Icons.video_camera_back_rounded,
    ),
    _UploadOption(
      title: 'Upload Series',
      description: 'Episodic shows with seasons',
      icon: Icons.live_tv_rounded,
    ),
    _UploadOption(
      title: 'Upload Mini Series',
      description: 'Compact, multi-part stories',
      icon: Icons.smart_display_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).getTheme;
    final screenSize = MediaQuery.sizeOf(context);
    final compact = screenSize.width < 640;
    final dialogWidth = math.min(640.0, screenSize.width - 32);
    final maxDialogHeight = screenSize.height * 0.84;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: maxDialogHeight,
        ),
        child: Material(
          color: theme.cardColor,
          elevation: 18,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: theme.canvasColor.withValues(alpha: 0.08),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogHeader(theme: theme),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _uploadTypes.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: compact ? 1 : 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      mainAxisExtent: compact ? 108 : 148,
                    ),
                    itemBuilder: (context, index) {
                      final option = _uploadTypes[index];
                      return _UploadTypeCard(
                        option: option,
                        theme: theme,
                        onTap: () => _openUploadFlow(context, theme, option),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openUploadFlow(
    BuildContext context,
    ThemeData theme,
    _UploadOption option,
  ) {
    Navigator.pop(context);
    if (option.title == 'Upload Mini Series') {
      AddShortMaster.show(context);
      return;
    }

    final uploadType = switch (option.title) {
      'Upload Movie' => UploadContentType.movie,
      'Upload Short Film' => UploadContentType.shortFilm,
      _ => UploadContentType.series,
    };
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: theme.cardColor,
        child: SizedBox(
          width: ResponsiveWidget.isMobile(dialogContext)
              ? MediaQuery.sizeOf(dialogContext).width * 0.8
              : MediaQuery.sizeOf(dialogContext).width * 0.5,
          child: UploadVideoWidget(uploadType: uploadType),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.cloud_upload_outlined,
              color: theme.primaryColor,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Upload Type',
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose the type of content you want to publish.',
                  style: TextStyle(
                    color: theme.canvasColor.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: theme.canvasColor.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadOption {
  const _UploadOption({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class _UploadTypeCard extends StatefulWidget {
  const _UploadTypeCard({
    required this.option,
    required this.theme,
    required this.onTap,
  });

  final _UploadOption option;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  State<_UploadTypeCard> createState() => _UploadTypeCardState();
}

class _UploadTypeCardState extends State<_UploadTypeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.primaryColor;
    final foreground = widget.theme.canvasColor;

    return Semantics(
      button: true,
      label: widget.option.title,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _hovered ? 1.015 : 1,
          duration: const Duration(milliseconds: 160),
          child: Material(
            color: Color.alphaBlend(
              primary.withValues(alpha: _hovered ? 0.10 : 0.035),
              widget.theme.cardColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: _hovered ? primary : foreground.withValues(alpha: 0.10),
                width: _hovered ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              focusColor: primary.withValues(alpha: 0.12),
              hoverColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(widget.option.icon, color: primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.option.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.option.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground.withValues(alpha: 0.58),
                              fontSize: 11,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: _hovered ? 0.16 : 0),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
