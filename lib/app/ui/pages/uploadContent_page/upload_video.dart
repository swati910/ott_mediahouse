import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_house/app/core/constant/app_constant.dart';
import 'package:media_house/app/core/utils/agreement_download_helper.dart';
import 'package:media_house/app/core/utils/agreement_template.dart';
import 'package:media_house/app/core/utils/image_validation_service.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/core/utils/sharepreferences.dart';
import 'package:media_house/app/ui/pages/uploadContent_page/component/upload_form_helpers.dart';
import 'package:media_house/app/ui/pages/uploadContent_page/component/upload_media_helpers.dart';
import 'package:media_house/app/ui/pages/uploadContent_page/component/web_razorpay_gateway.dart';
import 'package:media_house/app/widget/custom_textfield.dart';
import 'package:media_house/app/widget/show_toast.dart';
import 'package:media_house/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../provider/videoProvider.dart';
import '../../../core/upload/s3_multipart_upload_service.dart';
import '../../widget/multipart_upload_progress_widget.dart';
import '../../../../domain/entities/content.dart';
import '../../../core/content/content_type.dart';

enum UploadContentType { movie, shortFilm, series }

extension UploadContentTypeContract on UploadContentType {
  bool get isMovieLike => this != UploadContentType.series;

  String get apiValue => switch (this) {
        UploadContentType.movie => ContentTypeValue.movie,
        UploadContentType.shortFilm => ContentTypeValue.shortFilm,
        UploadContentType.series => ContentTypeValue.series,
      };

  String get displayLabel => switch (this) {
        UploadContentType.movie => 'Movie',
        UploadContentType.shortFilm => 'Short Film',
        UploadContentType.series => 'Series',
      };
}

class UploadVideoWidget extends StatefulWidget {
  final UploadContentType uploadType;

  const UploadVideoWidget({
    super.key,
    this.uploadType = UploadContentType.movie,
  });

  @override
  State<UploadVideoWidget> createState() => _UploadVideoWidgetState();
}
class _UploadVideoWidgetState extends State<UploadVideoWidget> {
  final PageController _pageController = PageController();
  static const String _razorpayKeyId = AppConstant.razorpayKeyId;
  static const String _defaultRegistrationPlan = 'Basic';
  static const String _defaultRegistrationValidity = '1 Year';

  Razorpay? _razorpay;
  int _currentPage = 0;
  bool _isDownloadingAgreement = false;
  bool _isSubmitting = false;

  bool get _isMovieLike => widget.uploadType.isMovieLike;
  bool get _requiresCensorCertificate =>
      widget.uploadType == UploadContentType.movie;
  String get _uploadContentType => widget.uploadType.apiValue;
  String get _registrationFeeContentType => switch (widget.uploadType) {
        UploadContentType.movie => "MOVIES",
        UploadContentType.shortFilm => ContentTypeValue.shortFilm,
        UploadContentType.series => ContentTypeValue.series,
      };
  int get _totalSteps => 4;
  int get _lastPageIndex => _totalSteps - 1;
  bool get _isMobile => ResponsiveWidget.isMobile(context);
  bool get _supportsNativeRazorpay =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  EdgeInsets get _pagePadding =>
      EdgeInsets.symmetric(horizontal: _isMobile ? 12 : 24, vertical: 16);

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<VideoProvider>();
      provider.prepareUploadForm(_uploadContentType);
      provider.fetchActiveRegistrationFeeRule(
        contentType: _registrationFeeContentType,
      );
      provider.fetchGroupedLanguages();
    });
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _pageController.dispose();
    super.dispose();
  }

  void _initRazorpay() {
    if (kIsWeb || !_supportsNativeRazorpay) return;
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _startRegistrationPayment(VideoProvider provider) async {
    if (!kIsWeb && !_supportsNativeRazorpay) {
      CustomToast.show(
        context,
        "Razorpay checkout is available on Android, iOS, and web.",
        isSuccess: false,
      );
      return;
    }

    if (!kIsWeb && _razorpay == null) {
      CustomToast.show(context, "Payment gateway not initialized.",
          isSuccess: false);
      return;
    }

    if (_razorpayKeyId.isEmpty) {
      CustomToast.show(
        context,
        "Razorpay key is missing. Configure --dart-define=RAZORPAY_KEY_ID=...",
        isSuccess: false,
      );
      return;
    }

    if (provider.isRegistrationFeeLoading) {
      CustomToast.show(
        context,
        "Registration fee is still loading. Please wait.",
        isWarning: true,
      );
      return;
    }

    if (provider.activeRegistrationFee == null) {
      CustomToast.show(
        context,
        provider.registrationFeeError ?? "Registration fee is not available.",
        isSuccess: false,
      );
      return;
    }

    final enteredAmount = provider.activeRegistrationFee ??
        double.tryParse(provider.registrationAmountPaidController.text.trim());
    if (enteredAmount == null || enteredAmount <= 0) {
      CustomToast.show(
        context,
        "Please fetch a valid registration fee before payment.",
        isSuccess: false,
      );
      return;
    }
    final amount = enteredAmount;
    final amountInPaise = (amount * 100).round();

    final localSharePreferences = LocalSharePreferences();
    final user = await localSharePreferences.getUser();
    final userName = "${user?.firstName ?? ''} ${user?.lastName ?? ''}".trim();

    final options = {
      'key': _razorpayKeyId,
      'amount': amountInPaise,
      'name': AppConstant.razorpayMerchantName,
      'description': 'Registration Fee',
      'image': _razorpayLogoUrl,
      'prefill': {
        'contact': user?.mobileNumber ?? '',
        'email': user?.emailId ?? '',
        'name': userName,
      },
      'theme': {'color': '#1A73E8'},
    };

    if (kIsWeb) {
      await WebRazorpayGateway.openCheckout(
        keyId: _razorpayKeyId,
        amountInPaise: amountInPaise,
        merchantName: AppConstant.razorpayMerchantName,
        description: 'Registration Fee',
        prefillContact: user?.mobileNumber ?? '',
        prefillEmail: user?.emailId ?? '',
        prefillName: userName,
        logoUrl: _razorpayLogoUrl,
        onSuccess: (paymentId) => _applyPaymentSuccess(
          paymentId: paymentId,
          paymentMethod: 'Razorpay (Web)',
        ),
        onError: (message) =>
            CustomToast.show(context, message, isSuccess: false),
        onExternalWallet: (wallet) => CustomToast.show(
            context, "Payment switched to $wallet.",
            isWarning: true),
      );
      return;
    }

    try {
      _razorpay!.open(options);
    } catch (error) {
      CustomToast.show(context, 'Unable to open the payment gateway. Please try again.',
          isSuccess: false);
    }
  }

  String get _razorpayLogoUrl => AppConstant.razorpayLogoUrl;

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    final paymentId =
        (response.paymentId ?? response.orderId ?? '').toString().trim();

    _applyPaymentSuccess(paymentId: paymentId, paymentMethod: 'Razorpay');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    final errorMessage = response.message ?? "Payment failed.";
    CustomToast.show(context, errorMessage, isSuccess: false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    final wallet = response.walletName ?? "external wallet";
    CustomToast.show(context, "Payment switched to $wallet.", isWarning: true);
  }

  Content _buildAgreementDraft(VideoProvider provider, String mediaHouseName) {
    return Content(
      title: provider.titleController.text.trim(),
      description: provider.descriptionController.text.trim(),
      runtime: int.tryParse(provider.runTimeController.text.trim()) ?? 0,
      releaseDate: provider.releaseDateController.text.trim(),
      price: double.tryParse(provider.priceController.text.trim()) ?? 0.0,
      languageList: provider.selectedLanguages,
      castList: provider.castList,
      genreList: provider.selectedGeners,
      directorList: provider.directorList,
      ageRating: provider.ageRatingController.text.trim(),
      type: _uploadContentType,
      sensorCertificate: provider.censorCertificateController.text.trim(),
      mediaHouseName: mediaHouseName,
    );
  }

  Future<void> _downloadAgreementTemplate(VideoProvider provider) async {
    setState(() {
      _isDownloadingAgreement = true;
    });

    try {
      final localPrefs = LocalSharePreferences();
      final mediaHouse = await localPrefs.getMediaHouse();
      final movie = _buildAgreementDraft(
        provider,
        mediaHouse?.mediaHouseName ?? 'Content',
      );
      final pdfBytes =
          await buildAgreementPdf(movie: movie, mediaHouse: mediaHouse);
      final safeTitle =
          (movie.title?.trim().isNotEmpty == true ? movie.title! : 'content')
              .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
              .replaceAll(RegExp(r'_+'), '_');
      await saveAgreementFile(pdfBytes, '${safeTitle}_agreement.pdf');
      if (!mounted) return;
      CustomToast.show(context, 'Agreement template downloaded.',
          isSuccess: true);
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(context, 'Unable to download the agreement. Please try again.',
          isSuccess: false);
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingAgreement = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return "$year-$month-$day";
  }

  void _applyPaymentSuccess({
    required String paymentId,
    required String paymentMethod,
  }) {
    if (!mounted) return;
    final normalizedPaymentId = paymentId.trim();
    if (normalizedPaymentId.isEmpty) {
      CustomToast.show(
        context,
        "Payment succeeded but payment ID was not received.",
        isSuccess: false,
      );
      return;
    }

    final provider = context.read<VideoProvider>();
    final feeVal = provider.activeRegistrationFee ??
        double.tryParse(
          provider.registrationAmountPaidController.text.trim(),
        ) ??
        0;
    final amount = (feeVal == feeVal.roundToDouble())
        ? feeVal.toInt().toString()
        : feeVal.toString();

    provider.setRegistrationPaymentDetails(
      paymentId: normalizedPaymentId,
      paymentDate: _formatDate(DateTime.now()),
      amountPaid: amount,
      planType: provider.registrationPlanTypeController.text.trim().isEmpty
          ? _defaultRegistrationPlan
          : provider.registrationPlanTypeController.text.trim(),
      validity: provider.registrationValidityController.text.trim().isEmpty
          ? _defaultRegistrationValidity
          : provider.registrationValidityController.text.trim(),
      paymentMethod: paymentMethod,
      markPaid: true,
    );

    CustomToast.show(context, "Registration fee payment successful.",
        isSuccess: true);
  }

  void _nextPage() {
    if (_currentPage < _lastPageIndex) {
      setState(() => _currentPage++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedThemeData =
        Provider.of<ThemeProvider>(context, listen: false).getTheme;

    return WillPopScope(
      onWillPop: () async => !_isSubmitting,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: ResponsiveWidget.isMobile(context)
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
            child: Consumer<VideoProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
                    _buildHeader(selectedThemeData),
                    _buildProgressIndicator(selectedThemeData),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: _isMovieLike
                            ? _moviePages(selectedThemeData, provider)
                            : _seriesPages(selectedThemeData, provider),
                      ),
                    ),
                    _buildFooter(selectedThemeData, provider),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _moviePages(ThemeData theme, VideoProvider provider) {
    return [
      _moviePageOne(theme, provider),
      _commonPricingPage(theme, provider, 1),
      _moviePageThree(theme, provider),
      _moviePageFour(theme, provider),
    ];
  }

  List<Widget> _seriesPages(ThemeData theme, VideoProvider provider) {
    return [
      _seriesPageOne(theme, provider),
      _commonPricingPage(theme, provider, 1),
      _moviePageThree(theme, provider),
      _moviePageFour(theme, provider),
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
                textInputType: TextInputType.text,
              ),
              CustomTextField(
                controller: provider.descriptionController,
                hintText: "Enter description",
                label: "Description",
                textInputType: TextInputType.text,
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
          const SizedBox(height: 8),
          UploadFormHelpers.buildSectionCard(
            "Classification",
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
            ],
            theme,
          ),
        ],
      ),
    );
  }

  Widget _seriesPageOne(ThemeData theme, VideoProvider provider) {
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
                hintText: "Enter series title",
                label: "Title",
                textInputType: TextInputType.text,
              ),
              CustomTextField(
                controller: provider.descriptionController,
                hintText: "Enter description",
                label: "Description",
                textInputType: TextInputType.text,
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
          const SizedBox(height: 8),
          UploadFormHelpers.buildSectionCard(
            "Classification",
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
            ],
            theme,
          ),
        ],
      ),
    );
  }

  Widget _commonPricingPage(
      ThemeData theme, VideoProvider provider, int isMovie) {
    return SingleChildScrollView(
      padding: _pagePadding,
      child: Column(
        children: [
          UploadFormHelpers.buildSectionCard(
            "Release & Pricing",
            [
              UploadFormHelpers.buildModernDateField(
                context,
                provider,
                theme,
                (pickedDate) => provider.setDate(pickedDate),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: provider.priceController,
                hintText: "Enter price",
                label: "Price",
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
              isMovie == 1 &&
                      provider.rentalDurationController.text.trim() !=
                          "One Time"
                  ? CustomTextField(
                      controller: provider.numberOfAttemptController,
                      hintText: "No Of Attempts",
                      label: "No Of Attempts",
                      textInputType: TextInputType.number,
                    )
                  : SizedBox.shrink()
            ],
            theme,
          ),
        ],
      ),
    );
  }

  Widget _moviePageThree(ThemeData theme, VideoProvider provider) {
    final selectedLanguages = provider.selectedLanguages
        .map((item) => (item.language ?? '').trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final isUploadingTeaser = provider.isTeaserUploading ||
        (provider.activeTeaserProgressInfo != null &&
            provider.activeTeaserProgressInfo!.state != MultipartUploadState.idle &&
            provider.activeTeaserProgressInfo!.state != MultipartUploadState.completed);

    final isUploadingTrailer = provider.isTrailerUploading ||
        (provider.activeTrailerProgressInfo != null &&
            provider.activeTrailerProgressInfo!.state != MultipartUploadState.idle &&
            provider.activeTrailerProgressInfo!.state != MultipartUploadState.completed);

    final isUploadingMovie = provider.isMovieUploading ||
        (provider.activePrimaryProgressInfo != null &&
            provider.activePrimaryProgressInfo!.state != MultipartUploadState.idle &&
            provider.activePrimaryProgressInfo!.state != MultipartUploadState.completed);

    return SingleChildScrollView(
      padding: _pagePadding,
      child: Column(
        children: [
          if (_requiresCensorCertificate) ...[
            UploadFormHelpers.buildSectionCard(
              "Common Upload Files",
              [
                UploadMediaHelpers.buildEnhancedUploadSection(
                    "Censor Certificate", theme, context),
              ],
              theme,
            ),
            const SizedBox(height: 12),
          ],
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
        if (_isMovieLike) ...[
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
              : () => provider.pickMovieVariantFile(
                    context,
                    language,
                    field,
                    isVideo: isVideo,
                  ),
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
                                    onTap: () =>
                                        UploadMediaHelpers.showImagePreview(
                                      context,
                                      imageUrl,
                                      label,
                                      theme,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        "View",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
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
                                  onTap: () => controller.clear(),
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
        if (field == 'teaser' && provider.activeTeaserProgressInfo != null &&
            provider.activeTeaserProgressInfo!.state != MultipartUploadState.idle) ...[
          const SizedBox(height: 12),
          MultipartUploadProgressWidget(
            info: provider.activeTeaserProgressInfo!,
            onPause: () => provider.pauseTeaserMultipartUpload(),
            onResume: () => provider.resumeTeaserMultipartUpload(),
            onRetry: () => provider.retryTeaserMultipartUpload(),
            onAbort: () => provider.abortTeaserMultipartUpload(),
          ),
        ],
        if (field == 'trailer' && provider.activeTrailerProgressInfo != null &&
            provider.activeTrailerProgressInfo!.state != MultipartUploadState.idle) ...[
          const SizedBox(height: 12),
          MultipartUploadProgressWidget(
            info: provider.activeTrailerProgressInfo!,
            onPause: () => provider.pauseTrailerMultipartUpload(),
            onResume: () => provider.resumeTrailerMultipartUpload(),
            onRetry: () => provider.retryTrailerMultipartUpload(),
            onAbort: () => provider.abortTrailerMultipartUpload(),
          ),
        ],
        if ((field == 'movie' || field == 'video') && provider.activePrimaryProgressInfo != null &&
            provider.activePrimaryProgressInfo!.state != MultipartUploadState.idle) ...[
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

  Widget _moviePageFour(ThemeData theme, VideoProvider provider) {
    return SingleChildScrollView(
      padding: _pagePadding,
      child: _audioSubtitleAndSettings(
        theme,
        provider,
        showAudio: false,
      ),
    );
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
                  side: BorderSide(color: theme.primaryColor.withOpacity(0.4)),
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
                  side: BorderSide(color: Colors.red.withOpacity(0.4)),
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

  Widget _audioSubtitleAndSettings(
    ThemeData theme,
    VideoProvider provider, {
    bool showAudio = true,
    bool showSettings = true,
  }) {
    return Column(
      children: [
        if (showAudio)
          UploadFormHelpers.buildSectionCard(
            "Audio & Subtitles",
            [
              UploadFormHelpers.buildModernMultiSelectDropdownField(
                'Audio Formats',
                audioFormats,
                context,
                theme,
              ),
              const SizedBox(height: 16),
              UploadFormHelpers.buildModernMultiSelectDropdownField(
                'Audio Languages',
                provider.languageOptions,
                context,
                theme,
                groupedItems: provider.groupedLanguageOptions,
              ),
              const SizedBox(height: 20),
              UploadMediaHelpers.buildDynamicLanguageAudioSection(
                  context, theme),
            ],
            theme,
          ),
        if (showAudio && showSettings) const SizedBox(height: 8),
        if (showSettings)
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
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.file_present_rounded,
                        color: theme.primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Signed Agreement Upload',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.canvasColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            provider.hasUploadedAgreement
                                ? 'Signed document uploaded successfully.'
                                : 'Download the template, sign the hard copy, and upload it before registration charges.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.canvasColor.withValues(alpha: 0.65),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (provider.hasUploadedAgreement
                                ? const Color(0xFF0F9D58)
                                : const Color(0xFFD97706))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: (provider.hasUploadedAgreement
                                  ? const Color(0xFF0F9D58)
                                  : const Color(0xFFD97706))
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        provider.hasUploadedAgreement ? 'Uploaded' : 'Pending',
                        style: TextStyle(
                          color: provider.hasUploadedAgreement
                              ? const Color(0xFF0F9D58)
                              : const Color(0xFFD97706),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  provider.agreementFileName ??
                      (provider.hasUploadedAgreement
                          ? 'Agreement uploaded'
                          : 'No signed agreement uploaded yet'),
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (provider.isAgreementUploading) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: provider.agreementUploadProgress == 0
                      ? null
                      : provider.agreementUploadProgress,
                  color: theme.primaryColor,
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _isDownloadingAgreement
                      ? null
                      : () => _downloadAgreementTemplate(provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: _isDownloadingAgreement
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    _isDownloadingAgreement
                        ? 'Preparing PDF...'
                        : 'Download Template',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: provider.isAgreementUploading
                      ? null
                      : () async {
                          final uploaded =
                              await provider.pickAndUploadAgreementDocument();
                          if (!mounted) return;
                          CustomToast.show(
                            context,
                            uploaded
                                ? 'Signed agreement uploaded successfully.'
                                : 'Agreement upload cancelled.',
                            isSuccess: uploaded,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                    provider.hasUploadedAgreement
                        ? 'Replace Signed Agreement'
                        : 'Upload Signed Agreement',
                  ),
                ),
              ),
              if (provider.hasUploadedAgreement) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: provider.agreementDocumentUrl),
                      );
                      if (!mounted) return;
                      CustomToast.show(
                        context,
                        'Agreement URL copied.',
                        isSuccess: true,
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Uploaded URL'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              UploadFormHelpers.buildModernToggleRow(
                'Registration Fee Paid',
                'Y = Paid (upload allowed), N = Not paid (upload blocked)',
                provider.isRegistrationFeePaid,
                (value) {
                  if (value) {
                    _startRegistrationPayment(provider);
                    return;
                  }
                  provider.clearRegistrationPaymentDetails(markUnpaid: true);
                },
                theme,
              ),
              const SizedBox(height: 16),
              _buildRegistrationFeeCard(provider, theme),
              if (!provider.isRegistrationFeePaid) const SizedBox(height: 12),
              if (!provider.isRegistrationFeePaid)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: provider.isRegistrationFeeLoading ||
                            provider.activeRegistrationFee == null
                        ? null
                        : () => _startRegistrationPayment(provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text("Pay Registration Fee"),
                  ),
                ),
              if (!provider.isRegistrationFeePaid) const SizedBox(height: 16),
              if (provider.isRegistrationFeePaid) ...[
                CustomTextField(
                  controller: provider.registrationPaymentIdController,
                  hintText: "Enter transaction/payment id",
                  label: "Payment ID / Transaction ID",
                  textInputType: TextInputType.text,
                ),
                CustomTextField(
                  controller: provider.registrationPaymentDateController,
                  hintText: "Enter payment date (e.g. 2026-02-10)",
                  label: "Payment Date",
                  textInputType: TextInputType.datetime,
                ),
                CustomTextField(
                  controller: provider.registrationAmountPaidController,
                  hintText: "Enter amount paid",
                  label: "Amount Paid",
                  textInputType: TextInputType.number,
                  readOnly: true,
                ),
                CustomTextField(
                  controller: provider.registrationPlanTypeController,
                  hintText: "Enter plan (Basic/Premium)",
                  label: "Plan Type",
                  textInputType: TextInputType.text,
                ),
                CustomTextField(
                  controller: provider.registrationValidityController,
                  hintText: "Enter validity (e.g. 1 year / 2027-02-10)",
                  label: "Validity",
                  textInputType: TextInputType.text,
                ),
                CustomTextField(
                  controller: provider.registrationPaymentMethodController,
                  hintText: "Enter payment method (UPI/Card/Net Banking)",
                  label: "Payment Method",
                  textInputType: TextInputType.text,
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    "Set Registration Fee Paid = Y to complete payment details and enable upload.",
                    style: TextStyle(
                      color: theme.canvasColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
            theme,
          ),
      ],
    );
  }

  Widget _buildRegistrationFeeCard(VideoProvider provider, ThemeData theme) {
    final contentType = _registrationFeeContentType;
    final feeText = provider.activeRegistrationFeeText;
    final error = provider.registrationFeeError;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: provider.isRegistrationFeeLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.primaryColor,
                    ),
                  )
                : Icon(
                    Icons.payments_outlined,
                    color: theme.primaryColor,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.isRegistrationFeeLoading
                      ? "Fetching registration fee..."
                      : error ?? "Registration Fee",
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  feeText.isEmpty ? "--" : "INR $feeText",
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${provider.activeRegistrationFeeContentType ?? contentType} - ${provider.activeRegistrationFeeAudienceScope ?? 'INDIA'}",
                  style: TextStyle(
                    color: theme.canvasColor.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                if (error != null && !provider.isRegistrationFeeLoading) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => provider.fetchActiveRegistrationFeeRule(
                      contentType: contentType,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text("Retry"),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData themeData) {
    final List<String> stepTitles = _isMovieLike
        ? const [
            "Language, Details & Cast",
            "Release, Price & Rental",
            "Upload Files & Audio",
            "Content Settings",
          ]
        : const [
            "Language, Details & Cast",
            "Release, Price & Rental",
            "Upload Files",
            "Content Settings",
          ];

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
                "Upload ${widget.uploadType.displayLabel}",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeData.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                stepTitles[_currentPage],
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
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
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
                onPressed: _isSubmitting ? null : _previousPage,
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
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_currentPage == _lastPageIndex ? "Submit" : "Next"),
            ),
          ),
        ],
      ),
    );
  }

  void _handleButtonPress(VideoProvider provider, ThemeData themeData) {
    if (_isSubmitting) return;

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

    if (_currentPage == 2) {
      if (!_validatePageThree(provider)) return;
      if (_currentPage < _lastPageIndex) {
        _nextPage();
        return;
      }
    }

    if (!_validatePageFour(provider)) return;
    _handleAdd(provider, themeData);
  }

  bool _validatePageOne(VideoProvider provider) {
    return true;
  }

  bool _validatePageTwo(VideoProvider provider) {
    return true;
  }

  bool _validatePageThree(VideoProvider provider) {
    return true;
  }

  bool _validatePageFour(VideoProvider provider) {
    if (provider.selectedLanguages.isEmpty) {
      CustomToast.show(context, "Please select at least one language",
          isSuccess: false);
      return false;
    }
    if (provider.titleController.text.trim().isEmpty) {
      CustomToast.show(context, "Please enter title", isSuccess: false);
      return false;
    }
    if (provider.descriptionController.text.trim().isEmpty) {
      CustomToast.show(context, "Please enter description", isSuccess: false);
      return false;
    }

    final releaseDate = provider.releaseDateController.text.trim();
    final priceText = provider.priceController.text.trim();
    final rentalDuration = provider.rentalDurationController.text.trim();
    final price = double.tryParse(priceText);

    if (releaseDate.isEmpty) {
      CustomToast.show(context, "Please select release date", isSuccess: false);
      return false;
    }
    if (price == null || price <= 0) {
      CustomToast.show(context, "Please enter valid price", isSuccess: false);
      return false;
    }
    if (rentalDuration.isEmpty) {
      CustomToast.show(context, "Please select rental duration",
          isSuccess: false);
      return false;
    }

    if (_requiresCensorCertificate &&
        provider.censorCertificateController.text.trim().isEmpty) {
      CustomToast.show(context, "Please upload censor certificate",
          isSuccess: false);
      return false;
    }
    final contentLabel = widget.uploadType == UploadContentType.shortFilm
        ? 'short film'
        : _isMovieLike
            ? 'movie'
            : 'series';
    for (final language in provider.selectedLanguages) {
      final name = (language.language ?? '').trim();
      final variant = provider.movieVariantControllers[name];
      final missingFiles = <String>[];
      if (variant == null) {
        missingFiles.addAll(
          _isMovieLike
              ? [
                  'poster 1',
                  'poster 2',
                  'poster 3',
                  'teaser',
                  'trailer',
                  contentLabel,
                ]
              : [
                  'poster 1',
                  'teaser',
                  'trailer',
                ],
        );
      } else {
        if (variant['poster1']!.text.trim().isEmpty) {
          missingFiles.add('poster 1');
        }
        if (variant['poster2']!.text.trim().isEmpty) {
          missingFiles.add('poster 2');
        }
        if (variant['poster3']!.text.trim().isEmpty) {
          missingFiles.add('poster 3');
        }
        if (variant['teaser']!.text.trim().isEmpty) {
          missingFiles.add('teaser');
        }
        if (variant['trailer']!.text.trim().isEmpty) {
          missingFiles.add('trailer');
        }
        if (_isMovieLike && variant['movie']!.text.trim().isEmpty) {
          missingFiles.add(contentLabel);
        }
      }
      if (missingFiles.isNotEmpty) {
        CustomToast.show(
          context,
          "Please upload ${missingFiles.join(', ')} for $name",
          isSuccess: false,
        );
        return false;
      }
    }

    if (provider.hasIncompleteCastDraft) {
      CustomToast.show(
        context,
        "Please complete cast draft or clear it before submit.",
        isSuccess: false,
      );
      return false;
    }
    return true;
  }

  void _syncFeaturedFlag(VideoProvider provider) {
    try {
      final releaseDate = provider.releaseDateController.text.trim();
      final targetDate = DateTime.parse(releaseDate);
      provider.toggleFeatured(targetDate.isAfter(DateTime.now()));
    } catch (_) {
      CustomToast.show(
          context, "Invalid release date format. Please correct it.",
          isSuccess: false);
    }
  }

  Future<void> _handleAdd(
      VideoProvider provider, ThemeData selectedThemeData) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      if (_isMovieLike) {
        final results = await provider.uploadMovieVariants(context);
        if (!mounted) return;
        await _showMovieVariantResultDialog(results, contentType: "movie");
        if (!mounted) return;
        if (results.isNotEmpty && results.values.every((value) => value)) {
          provider.disposeData();
          Navigator.of(context).pop();
        }
        return;
      }

      final results = await provider.uploadSeriesVariants(context);
      if (!mounted) return;
      await _showMovieVariantResultDialog(results, contentType: "series");
      if (!mounted) return;
      if (results.isNotEmpty && results.values.every((value) => value)) {
        provider.disposeData();
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showMovieVariantResultDialog(
    Map<String, bool> results, {
    String contentType = "movie",
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: const Text("Upload Result"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: results.entries.map((entry) {
              final success = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  success
                      ? "${entry.key} $contentType added successfully"
                      : "${entry.key} $contentType failed to add",
                  style: TextStyle(
                    color: success ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }
}

const List<String> ageRatings = [
  'U (Universal)',
  'U/A (Parental Guidance for Children Below 12)',
  'A (Adults Only)',
  'S (Restricted to a Special Class of Persons)',
];

const List<String> rentalDurations = [
  "One Time",
  "One Day",
  "Two Days",
  "Three Days",
  "Seven Days",
  "Two Week",
  "One Month"
];

const List<String> genres = [
  'Action',
  'Drama',
  'Comedy',
  'Thriller',
  'Horror',
  'Romance',
  'Sci-Fi',
  'Fantasy',
  'Mystery',
  'Documentary',
  'Animation',
  'Adventure',
  'Musical',
  'Historical',
  'Crime',
];

const List<String> audioFormats = [
  'Stereo',
  'Dolby',
  'Mono',
  'Surround Sound',
  'Dolby Atmos',
  'Dolby Digital (AC-3)',
];
