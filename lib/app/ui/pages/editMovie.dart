import 'package:flutter/material.dart';
import 'package:media_house/app/ui/pages/uploadContent_page/component/upload_form_helpers.dart';
import 'package:media_house/app/ui/pages/uploadContent_page/component/upload_media_helpers.dart';
import 'package:media_house/app/ui/widget/multipart_upload_progress_widget.dart';
import 'package:media_house/app/widget/custom_textfield.dart';
import 'package:provider/provider.dart';
import '../../../../../device/utils/ResponsiveWidget.dart';
import '../../../domain/entities/content.dart';
import '../../provider/themeProvider.dart';
import '../../provider/videoProvider.dart';
import '../../widget/show_toast.dart';
import 'package:media_house/app/ui/pages/DisplayTrailer.dart';
import 'uploadContent_page/upload_video.dart';
import '../../core/content/content_type.dart';
import '../../core/upload/s3_multipart_upload_service.dart';
import '../../core/utils/image_validation_service.dart';

class EditVideoMovie extends StatefulWidget {
  final Content movie;
  const EditVideoMovie({super.key, required this.movie});

  @override
  State<EditVideoMovie> createState() => _EditVideoMovieState();
}

class _EditVideoMovieState extends State<EditVideoMovie> {
  final PageController _pageController = PageController();

  int _currentPage = 0;
  bool _isSubmitting = false;
  bool _isLoadingMovie = true;
  bool _hasError = false;
  String _errorMessage = '';

  int get _totalSteps => 3;
  int get _lastPageIndex => _totalSteps - 1;
  bool get _isMobile => ResponsiveWidget.isMobile(context);
  EdgeInsets get _pagePadding =>
      EdgeInsets.symmetric(horizontal: _isMobile ? 12 : 24, vertical: 16);

  void _nextPage() {
    if (_currentPage < _lastPageIndex) {
      setState(() {
        _currentPage++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool get _isMovie => ContentTypeValue.isMovieLike(widget.movie.type);
  bool get _isApproved =>
      (widget.movie.approvalStatus ?? '').toLowerCase() == "approved";

  @override
  void initState() {
    super.initState();
    getMediaHouse();
  }

  void getMediaHouse() async {
    setState(() {
      _isLoadingMovie = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      final provider = Provider.of<VideoProvider>(context, listen: false);
      provider.disposeData();
      provider.setValu(widget.movie);
      await provider.fetchGroupedLanguages();
      final content = await provider.getContentById(widget.movie.id!);
      if (!mounted) return;
      if (content != null) {
        provider.setValu(content);
      } else {
        _hasError = true;
        _errorMessage = 'Unable to fetch complete movie details from backend.';
      }
      await provider.fetchCastByContentId(widget.movie.id!);
    } catch (e) {
      if (mounted) {
        _hasError = true;
        _errorMessage = 'Failed to load movie details: $e';
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMovie = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeProvider themeProvider =
        Provider.of<ThemeProvider>(context, listen: false);
    var selectedThemeData = themeProvider.getTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: _isMobile
                ? MediaQuery.of(context).size.width - 8
                : MediaQuery.of(context).size.width - 70,
            maxHeight: MediaQuery.of(context).size.height - 40,
          ),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: selectedThemeData.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Consumer<VideoProvider>(builder: (context, provider, child) {
            if (_isLoadingMovie) {
              return Column(
                children: [
                  _buildHeader(selectedThemeData),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                              color: selectedThemeData.primaryColor),
                          const SizedBox(height: 16),
                          Text(
                            "Loading movie details...",
                            style: TextStyle(
                              color: selectedThemeData.canvasColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            if (_hasError) {
              return Column(
                children: [
                  _buildHeader(selectedThemeData),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            style: TextStyle(
                              color: selectedThemeData.canvasColor,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: getMediaHouse,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedThemeData.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _buildHeader(selectedThemeData),
                _buildProgressIndicator(selectedThemeData),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _isMovie
                        ? _moviePages(selectedThemeData, provider)
                        : _seriesPages(selectedThemeData, provider),
                  ),
                ),
                _buildFooter(selectedThemeData, provider),
              ],
            );
          }),
        ),
      ),
    );
  }

  List<Widget> _moviePages(ThemeData theme, VideoProvider provider) {
    return <Widget>[
      _moviePageOne(theme, provider),
      _moviePageTwo(theme, provider),
      _moviePageThree(theme, provider),
    ];
  }

  List<Widget> _seriesPages(ThemeData theme, VideoProvider provider) {
    return <Widget>[
      _seriesPageOne(theme, provider),
      _moviePageTwo(theme, provider),
      _seriesPageThree(theme, provider),
    ];
  }

  Widget _moviePageOne(ThemeData theme, VideoProvider provider) {
    return SingleChildScrollView(
      padding: _pagePadding,
      child: Column(
        children: [
          UploadFormHelpers.buildSectionCard(
            "Language & Basic Details",
            [
              UploadFormHelpers.buildModernMultiSelectDropdownField(
                'Languages',
                provider.languageOptions,
                context,
                theme,
                groupedItems: provider.groupedLanguageOptions,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: provider.titleController,
                hintText: "Enter movie title",
                label: "Title",
                showRequiredAsterisk: true,
                textInputType: TextInputType.text,
              ),
              CustomTextField(
                controller: provider.descriptionController,
                hintText: "Enter description",
                label: "Description",
                textInputType: TextInputType.text,
              ),
              UploadFormHelpers.buildModernDateField(
                context,
                provider,
                theme,
                (pickedDate) => provider.setDate(pickedDate),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: provider.runTimeController,
                hintText: "Enter runtime in minutes",
                label: "Runtime (min)",
                textInputType: TextInputType.number,
              ),
            ],
            theme,
          ),
          const SizedBox(height: 8),
          UploadFormHelpers.buildSectionCard(
            "Cast And Crew",
            [
              _castImageSection(theme, provider),
              const SizedBox(height: 8),
              _crewListSection(theme, provider),
            ],
            theme,
          ),
        ],
      ),
    );
  }

  Widget _moviePageTwo(ThemeData theme, VideoProvider provider) {
    return SingleChildScrollView(
      padding: _pagePadding,
      child: Column(
        children: [
          UploadFormHelpers.buildSectionCard(
            "Pricing & Media House",
            [
              CustomTextField(
                controller: provider.priceController,
                hintText: "Enter price in INR",
                label: "Price (INR)",
                showRequiredAsterisk: true,
                textInputType: TextInputType.number,
              ),
              UploadFormHelpers.buildModernDropdownField(
                'Rental Duration',
                rentalDurations,
                context,
                provider,
                theme,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: provider.numberOfAttemptController,
                hintText: "No Of Attempts",
                label: "No Of Attempts",
                textInputType: TextInputType.number,
              ),
            ],
            theme,
          ),
          const SizedBox(height: 8),
          UploadFormHelpers.buildSectionCard(
            "Content Formats & Configuration",
            [
              UploadFormHelpers.buildModernDropdownField(
                'Age Rating',
                ageRatings,
                context,
                provider,
                theme,
              ),
              const SizedBox(height: 16),
              UploadFormHelpers.buildModernMultiSelectDropdownField(
                'Genres',
                genres,
                context,
                theme,
              ),
              const SizedBox(height: 16),
              UploadFormHelpers.buildModernMultiSelectDropdownField(
                'Audio Formats',
                audioFormats,
                context,
                theme,
              ),
            ],
            theme,
          ),
        ],
      ),
    );
  }

  Widget _moviePageThree(ThemeData theme, VideoProvider provider) {
    final selectedLanguages = provider.audioLanguages;
    return SingleChildScrollView(
      padding: _pagePadding,
      child: Column(
        children: [
          UploadFormHelpers.buildSectionCard(
            "Common Upload Files",
            [
              UploadMediaHelpers.buildEnhancedUploadSection(
                  "Censor Certificate", theme, context),
            ],
            theme,
          ),
          const SizedBox(height: 12),
          if (selectedLanguages.isEmpty)
            UploadFormHelpers.buildSectionCard(
              "Language Variants",
              [
                Text(
                  "Select at least one language in step 1 to create upload sections.",
                  style: TextStyle(color: theme.canvasColor),
                ),
              ],
              theme,
            )
          else
            ...selectedLanguages.map(
              (language) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _movieLanguageVariantSection(
                  theme,
                  provider,
                  language,
                ),
              ),
            ),
          const SizedBox(height: 8),
          _audioSubtitleAndSettings(theme, provider),
        ],
      ),
    );
  }

  Widget _movieLanguageVariantSection(
    ThemeData theme,
    VideoProvider provider,
    String language,
  ) {
    return UploadFormHelpers.buildSectionCard(
      "$language Uploads",
      [
        _variantUploadTile(theme, provider, language, 'poster1', 'Poster 1'),
        const SizedBox(height: 12),
        _variantUploadTile(theme, provider, language, 'poster2', 'Poster 2'),
        const SizedBox(height: 12),
        _variantUploadTile(theme, provider, language, 'poster3', 'Poster 3'),
        const SizedBox(height: 12),
        _variantUploadTile(
          theme,
          provider,
          language,
          'teaser',
          'Teaser File',
          isVideo: true,
        ),
        const SizedBox(height: 12),
        _variantUploadTile(
          theme,
          provider,
          language,
          'trailer',
          'Trailer File',
          isVideo: true,
        ),
        if (_isMovie) ...[
          const SizedBox(height: 12),
          _variantUploadTile(
            theme,
            provider,
            language,
            'movie',
            'Movie File',
            isVideo: true,
          ),
          const SizedBox(height: 12),
          UploadMediaHelpers.buildAudioUploadSection(
            "$language Audio",
            theme,
            context,
          ),
          const SizedBox(height: 12),
          _variantUploadTile(
            theme,
            provider,
            language,
            'subtitle',
            'Subtitle File',
          ),
        ],
      ],
      theme,
    );
  }

  Widget _variantUploadTile(
    ThemeData theme,
    VideoProvider provider,
    String language,
    String field,
    String label, {
    bool isVideo = false,
  }) {
    final controller = provider.movieVariantController(language, field);
    final imageUrl = controller.text.trim();
    final uploaded = imageUrl.isNotEmpty;
    final isUploading = provider.isMovieVariantUploading(language, field);
    final progress = provider.movieVariantUploadProgress(language, field);
    final isPosterImage = field.startsWith('poster');
    final double containerHeight =
        (uploaded && isPosterImage) ? 120.0 : 80.0;

    final borderColor = uploaded
        ? Colors.green.withValues(alpha: 0.3)
        : theme.primaryColor.withValues(alpha: 0.3);
    final containerColor = uploaded
        ? Colors.green.withValues(alpha: 0.1)
        : theme.primaryColor.withValues(alpha: 0.1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.canvasColor,
          ),
        ),
        if (isPosterImage) ...[
          const SizedBox(height: 4),
          Text(
            ImageValidationService.guidelineFor(ImageValidationType.poster),
            style: TextStyle(
              fontSize: 12,
              color: theme.canvasColor.withValues(alpha: 0.65),
            ),
          ),
        ],
        const SizedBox(height: 8),
        InkWell(
          onTap: isUploading
              ? null
              : (uploaded
                  ? null
                  : () => provider.pickMovieVariantFile(
                        context,
                        language,
                        field,
                        isVideo: isVideo,
                      )),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: containerHeight,
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Stack(
              children: [
                if (isUploading)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.green.withValues(alpha: 0.35),
                        ),
                        minHeight: containerHeight,
                      ),
                    ),
                  ),

                if (uploaded && isPosterImage)
                  UploadMediaHelpers.buildImagePreview(
                      imageUrl, label, theme, context)
                else
                  Center(
                    child: isUploading
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 26,
                                width: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  value: progress.clamp(0.0, 1.0),
                                  color: theme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Uploading... ${(progress * 100).toInt()}%",
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                uploaded
                                    ? Icons.check_circle_outline
                                    : Icons.cloud_upload_outlined,
                                color: uploaded
                                    ? Colors.green
                                    : theme.primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  uploaded ? "$label Uploaded" : "Upload $label",
                                  style: TextStyle(
                                    color: uploaded
                                        ? Colors.green
                                        : theme.primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if (uploaded) ...[
                                const SizedBox(width: 8),
                                if (imageUrl.isNotEmpty) ...[
                                  InkWell(
                                    onTap: () {
                                      if (isVideo) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TrailerPage(
                                                trailerUrl: imageUrl),
                                          ),
                                        );
                                      } else {
                                        UploadMediaHelpers.showImagePreview(
                                          context,
                                          imageUrl,
                                          label,
                                          theme,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isVideo
                                                ? Icons.play_arrow
                                                : Icons.visibility,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isVideo ? "Play" : "View",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                InkWell(
                                  onTap: () => provider.pickMovieVariantFile(
                                    context,
                                    language,
                                    field,
                                    isVideo: isVideo,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "Replace",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    provider.clearMovieVariant(language, field);
                                    CustomToast.show(
                                      context,
                                      "$label removed",
                                      isSuccess: true,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "Delete",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
              ],
            ),
          ),
        ),
        if (field == 'teaser' &&
            provider.activeTeaserProgressInfo != null &&
            provider.activeTeaserProgressInfo!.state !=
                MultipartUploadState.idle) ...[
          const SizedBox(height: 12),
          MultipartUploadProgressWidget(
            info: provider.activeTeaserProgressInfo!,
            onPause: () => provider.pauseTeaserMultipartUpload(),
            onResume: () => provider.resumeTeaserMultipartUpload(),
            onRetry: () => provider.retryTeaserMultipartUpload(),
            onAbort: () => provider.abortTeaserMultipartUpload(),
          ),
        ],
        if (field == 'trailer' &&
            provider.activeTrailerProgressInfo != null &&
            provider.activeTrailerProgressInfo!.state !=
                MultipartUploadState.idle) ...[
          const SizedBox(height: 12),
          MultipartUploadProgressWidget(
            info: provider.activeTrailerProgressInfo!,
            onPause: () => provider.pauseTrailerMultipartUpload(),
            onResume: () => provider.resumeTrailerMultipartUpload(),
            onRetry: () => provider.retryTrailerMultipartUpload(),
            onAbort: () => provider.abortTrailerMultipartUpload(),
          ),
        ],
        if ((field == 'movie' || field == 'video') &&
            provider.activePrimaryProgressInfo != null &&
            provider.activePrimaryProgressInfo!.state !=
                MultipartUploadState.idle) ...[
          const SizedBox(height: 12),
          MultipartUploadProgressWidget(
            info: provider.activePrimaryProgressInfo!,
            onPause: () => provider.pausePrimaryMultipartUpload(),
            onResume: () => provider.resumePrimaryMultipartUpload(),
            onRetry: () => provider.retryPrimaryMultipartUpload(),
            onAbort: () => provider.abortPrimaryMultipartUpload(),
          ),
        ],
      ],
    );
  }

  Widget _seriesPageOne(ThemeData theme, VideoProvider provider) {
    return _moviePageOne(theme, provider);
  }

  Widget _seriesPageThree(ThemeData theme, VideoProvider provider) {
    return _moviePageThree(theme, provider);
  }

  Widget _castImageSection(ThemeData theme, VideoProvider provider) {
    return UploadFormHelpers.buildSectionCard(
      "Cast",
      [
        CustomTextField(
          controller: provider.castNameController,
          hintText: "Enter cast name",
          label: "Cast Name",
          textInputType: TextInputType.text,
          showRequiredAsterisk: true,
        ),
        UploadMediaHelpers.buildEnhancedUploadSection(
          "Cast Image",
          theme,
          context,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  provider.addCurrentCastToQueue(context);
                },
                icon: const Icon(Icons.add),
                label: const Text("Add Cast"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(
                      color: theme.primaryColor.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: provider.clearCastDraft,
                icon: const Icon(Icons.clear),
                label: const Text("Clear Draft"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        if (provider.pendingCasts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            "Added Casts (${provider.pendingCasts.length})",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.canvasColor,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(provider.pendingCasts.length, (index) {
            final cast = provider.pendingCasts[index];
            final imageUrl = (cast["image"] ?? "").trim();
            final roleText = (cast["role"] ?? "").trim();
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: theme.cardColor.withValues(alpha: 0.5),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        imageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              theme.primaryColor.withValues(alpha: 0.15),
                          child: Icon(Icons.person,
                              color: theme.primaryColor, size: 22),
                        ),
                      ),
                    )
                  else
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          theme.primaryColor.withValues(alpha: 0.15),
                      child: Icon(Icons.person,
                          color: theme.primaryColor, size: 22),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cast["name"] ?? "",
                          style: TextStyle(
                            color: theme.canvasColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => provider.removePendingCastAt(index),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: "Remove cast",
                  ),
                ],
              ),
            );
          }),
        ],
      ],
      theme,
    );
  }

  Widget _crewListSection(ThemeData theme, VideoProvider provider) {
    return UploadFormHelpers.buildSectionCard(
      "Crew",
      [
        CustomTextField(
          controller: provider.crewNameController,
          hintText: "Enter crew name",
          label: "Crew Name",
          textInputType: TextInputType.text,
          showRequiredAsterisk: true,
        ),
        CustomTextField(
          controller: provider.crewRoleController,
          hintText: "Enter crew role (Director/Writer/Producer)",
          label: "Crew Role",
          textInputType: TextInputType.text,
          showRequiredAsterisk: true,
        ),
        UploadMediaHelpers.buildEnhancedUploadSection(
          "Crew Image",
          theme,
          context,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  provider.addCurrentCrewToQueue(context);
                },
                icon: const Icon(Icons.add),
                label: const Text("Add Crew"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(
                      color: theme.primaryColor.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: provider.clearCrewDraft,
                icon: const Icon(Icons.clear),
                label: const Text("Clear Draft"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        if (provider.pendingCrews.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            "Added Crews (${provider.pendingCrews.length})",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.canvasColor,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(provider.pendingCrews.length, (index) {
            final crew = provider.pendingCrews[index];
            final imageUrl = (crew["image"] ?? "").trim();
            final roleText = (crew["role"] ?? "").trim();
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: theme.cardColor.withValues(alpha: 0.5),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        imageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              theme.primaryColor.withValues(alpha: 0.15),
                          child: Icon(Icons.person,
                              color: theme.primaryColor, size: 22),
                        ),
                      ),
                    )
                  else
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          theme.primaryColor.withValues(alpha: 0.15),
                      child: Icon(Icons.person,
                          color: theme.primaryColor, size: 22),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          crew["name"] ?? "",
                          style: TextStyle(
                            color: theme.canvasColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (roleText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            roleText,
                            style: TextStyle(
                              color: theme.canvasColor.withValues(alpha: 0.65),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => provider.removePendingCrewAt(index),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: "Remove crew",
                  ),
                ],
              ),
            );
          }),
        ],
      ],
      theme,
    );
  }

  Widget _audioSubtitleAndSettings(ThemeData theme, VideoProvider provider) {
    return Column(
      children: [
        UploadFormHelpers.buildSectionCard(
          "Content Settings",
          [
            UploadFormHelpers.buildModernToggleRow(
              'Downloadable Content',
              'Allow users to download this content',
              provider.isDownloadable,
              provider.toggleDownloadable,
              theme,
            ),
            const SizedBox(height: 16),
            UploadFormHelpers.buildModernToggleRow(
              'Featured Content',
              'Automatically controlled by release date logic',
              provider.isFeatured,
              (value) {
                CustomToast.show(
                  context,
                  provider.isFeatured
                      ? "Featured content is enabled for upcoming releases."
                      : "Featured content is disabled for already released content.",
                  isWarning: true,
                );
              },
              theme,
            ),
          ],
          theme,
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData themeData) {
    final List<String> stepTitles = _isMovie
        ? const [
            "Language, Details & Cast",
            "Release, Price & Rental",
            "Upload Files & Settings"
          ]
        : const [
            "Language, Details & Cast",
            "Release, Price & Rental",
            "Upload & Episodes"
          ];

    final currentTitle = (_currentPage >= 0 && _currentPage < stepTitles.length)
        ? stepTitles[_currentPage]
        : (stepTitles.isNotEmpty ? stepTitles.last : '');

    return Stack(
      children: [
        Container(
          padding: EdgeInsets.all(_isMobile ? 14 : 24),
          width: double.infinity,
          decoration: BoxDecoration(
            color: themeData.canvasColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(
                ContentTypeValue.isShortFilm(widget.movie.type)
                    ? "Edit Short Film"
                    : (_isMovie ? "Edit Movie" : "Edit Series"),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeData.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                currentTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _isMobile ? 16 : 20,
                  fontWeight: FontWeight.w600,
                  color: themeData.canvasColor,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: themeData.primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Step ${_currentPage + 1}/$_totalSteps",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        Positioned(
          top: 5,
          left: 5,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor:
                  themeData.scaffoldBackgroundColor.withValues(alpha: 0.35),
              foregroundColor: themeData.canvasColor,
            ),
            icon: const Icon(Icons.close, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(ThemeData themeData) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: _isMobile ? 14 : 24, vertical: _isMobile ? 12 : 16),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentPage;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive
                          ? themeData.primaryColor
                          : themeData.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < _lastPageIndex) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFooter(ThemeData themeData, VideoProvider provider) {
    return Container(
      padding: EdgeInsets.all(_isMobile ? 14 : 24),
      decoration: BoxDecoration(
        color: themeData.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: themeData.primaryColor),
                  foregroundColor: themeData.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Previous"),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () => _handleButtonPress(provider, themeData),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeData.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting && _currentPage == _lastPageIndex
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text("Saving changes..."),
                      ],
                    )
                  : Text(
                      _currentPage == _lastPageIndex ? "Save Changes" : "Next"),
            ),
          ),
        ],
      ),
    );
  }

  void _handleButtonPress(VideoProvider provider, ThemeData themeData) {
    if (_currentPage == 0) {
      if (!_validatePageOne(provider)) return;
      _nextPage();
      return;
    }

    if (_currentPage == 1) {
      if (!_validatePageTwo(provider)) return;
      _syncFeaturedFlag(provider);
      _nextPage();
      return;
    }

    if (!_validatePageThree(provider)) return;
    _handleAdd(provider, themeData, widget.movie.id!);
  }

  bool _validatePageOne(VideoProvider provider) {
    if (provider.titleController.text.trim().isEmpty) {
      CustomToast.show(context, "Please enter movie title", isSuccess: false);
      return false;
    }
    return true;
  }

  bool _validatePageTwo(VideoProvider provider) {
    final priceText = provider.priceController.text.trim();
    if (priceText.isEmpty || (double.tryParse(priceText) ?? -1) < 0) {
      CustomToast.show(context, "Please enter a valid price", isSuccess: false);
      return false;
    }
    return true;
  }

  bool _validatePageThree(VideoProvider provider) {
    if (_isMovie) {
      final movieUrl = provider.movieUrlController.text.trim();
      if (movieUrl.isEmpty) {
        CustomToast.show(context, "Please upload movie file", isSuccess: false);
        return false;
      }
    }
    return true;
  }

  void _syncFeaturedFlag(VideoProvider provider) {
    try {
      final releaseDate = provider.releaseDateController.text.trim();
      if (releaseDate.isNotEmpty) {
        final targetDate = DateTime.parse(releaseDate);
        provider.toggleFeatured(targetDate.isAfter(DateTime.now()));
      }
    } catch (_) {}
  }

  Future<void> _handleAdd(
      VideoProvider provider, ThemeData selectedThemeData, int movieId) async {
    setState(() => _isSubmitting = true);
    try {
      Content? content = await provider.editContent(context, movieId);
      if (!mounted) return;
      if (content != null) {
        final contentId = content.id ?? movieId;
        if (provider.hasAnyCastToSave) {
          final castSaved = await provider.saveAllCastsForContent(context,
              contentId: contentId);
          if (!mounted) return;
          if (!castSaved) return;
        }
        if (provider.hasAnyCrewToSave) {
          final crewSaved = await provider.saveAllCrewsForContent(context,
              contentId: contentId);
          if (!mounted) return;
          if (!crewSaved) return;
        }
        CustomToast.show(
          context,
          "${ContentTypeValue.displayLabel(widget.movie.type)} updated successfully.",
          isSuccess: true,
        );
        Navigator.of(context).pop(true);
      } else {
        CustomToast.show(
          context,
          "Failed to update movie.",
          isSuccess: false,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          "Error saving changes: $e",
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
