import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_house/app/core/constant/app_constant.dart';
import 'package:media_house/app/core/utils/agreement_download_helper.dart';
import 'package:media_house/app/core/utils/agreement_template.dart';
import 'package:media_house/app/core/utils/sharepreferences.dart';
import 'package:media_house/app/provider/videoProvider.dart';
import 'package:media_house/app/ui/pages/uploadContent_page/component/web_razorpay_gateway.dart';
import 'package:media_house/app/ui/pages/uploadContent_page/component/upload_form_helpers.dart';
import 'package:media_house/app/widget/custom_textfield.dart';
import 'package:media_house/app/widget/show_toast.dart';
import 'package:media_house/domain/entities/content.dart';
import 'package:media_house/domain/entities/mediaHouse.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PendingAgreementTab extends StatefulWidget {
  const PendingAgreementTab({
    super.key,
    required this.movie,
    required this.theme,
  });

  final Content movie;
  final ThemeData theme;

  @override
  State<PendingAgreementTab> createState() => _PendingAgreementTabState();
}

class _PendingAgreementTabState extends State<PendingAgreementTab> {
  static const String _defaultPlan = 'Basic';
  static const String _defaultValidity = '1 Year';

  Razorpay? _razorpay;
  MediaHouse? _mediaHouse;
  bool _isDownloading = false;
  bool _isSubmitting = false;
  bool _isWorkflowUpdating = false;
  bool get _supportsNativeRazorpay =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<VideoProvider>();
      provider.setValu(widget.movie);
      final localPrefs = LocalSharePreferences();
      final mediaHouse = await localPrefs.getMediaHouse();
      if (!mounted) return;
      setState(() {
        _mediaHouse = mediaHouse;
      });
    });
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  void _initRazorpay() {
    if (kIsWeb || !_supportsNativeRazorpay) return;
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _downloadAgreement(Content movie) async {
    setState(() {
      _isDownloading = true;
    });
    try {
      final pdfBytes =
          await buildAgreementPdf(movie: movie, mediaHouse: _mediaHouse);
      final safeTitle = (movie.title ?? 'content')
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      await saveAgreementFile(pdfBytes, '${safeTitle}_agreement.pdf');
      if (!mounted) return;
      CustomToast.show(context, 'Agreement template downloaded.',
          isSuccess: true);
    } catch (error) {
      CustomToast.show(
          context, 'Unable to download the agreement. Please try again.',
          isSuccess: false);
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _startRegistrationPayment(VideoProvider provider) async {
    if (!kIsWeb && !_supportsNativeRazorpay) {
      CustomToast.show(
        context,
        'Razorpay checkout is available on Android, iOS, and web.',
        isSuccess: false,
      );
      return;
    }

    if (!kIsWeb && _razorpay == null) {
      CustomToast.show(context, 'Payment gateway not initialized.',
          isSuccess: false);
      return;
    }

    if (AppConstant.razorpayKeyId.isEmpty) {
      CustomToast.show(
        context,
        'Razorpay key is missing. Configure --dart-define=RAZORPAY_KEY_ID=...',
        isSuccess: false,
      );
      return;
    }

    final enteredAmount =
        double.tryParse(provider.registrationAmountPaidController.text.trim());
    if (enteredAmount == null || enteredAmount <= 0) {
      CustomToast.show(
        context,
        'Please enter a valid onboarding amount before payment.',
        isSuccess: false,
      );
      return;
    }

    final amountInPaise = (enteredAmount * 100).round();
    final localSharePreferences = LocalSharePreferences();
    final user = await localSharePreferences.getUser();
    final userName = '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();

    if (kIsWeb) {
      await WebRazorpayGateway.openCheckout(
        keyId: AppConstant.razorpayKeyId,
        amountInPaise: amountInPaise,
        merchantName: AppConstant.razorpayMerchantName,
        description: 'Onboarding Charges',
        prefillContact: user?.mobileNumber ?? '',
        prefillEmail: user?.emailId ?? '',
        prefillName: userName,
        logoUrl: _razorpayLogoUrl,
        onSuccess: (paymentId) {
          unawaited(_applyPaymentSuccess(
            paymentId: paymentId,
            paymentMethod: 'Razorpay (Web)',
          ));
        },
        onError: (message) =>
            CustomToast.show(context, message, isSuccess: false),
        onExternalWallet: (wallet) => CustomToast.show(
            context, 'Payment switched to $wallet.',
            isWarning: true),
      );
      return;
    }

    try {
      _razorpay!.open({
        'key': AppConstant.razorpayKeyId,
        'amount': amountInPaise,
        'name': AppConstant.razorpayMerchantName,
        'description': 'Onboarding Charges',
        'image': AppConstant.razorpayLogoUrl,
        'prefill': {
          'contact': user?.mobileNumber ?? '',
          'email': user?.emailId ?? '',
          'name': userName,
        },
        'theme': {'color': '#1A73E8'},
      });
    } catch (error) {
      CustomToast.show(
          context, 'Unable to open the payment gateway. Please try again.',
          isSuccess: false);
    }
  }

  String get _razorpayLogoUrl {
    if (kIsWeb) {
      return Uri.base.resolve('assets/assets/images/logo.png').toString();
    }
    return AppConstant.razorpayLogoUrl;
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    final paymentId =
        (response.paymentId ?? response.orderId ?? '').toString().trim();
    unawaited(
      _applyPaymentSuccess(
        paymentId: paymentId,
        paymentMethod: 'Razorpay',
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    CustomToast.show(context, response.message ?? 'Payment failed.',
        isSuccess: false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    final wallet = response.walletName ?? 'external wallet';
    CustomToast.show(context, 'Payment switched to $wallet.', isWarning: true);
  }

  Future<void> _applyPaymentSuccess({
    required String paymentId,
    required String paymentMethod,
  }) async {
    if (!mounted) return;
    final normalizedPaymentId = paymentId.trim();
    if (normalizedPaymentId.isEmpty) {
      CustomToast.show(
        context,
        'Payment succeeded but payment ID was not received.',
        isSuccess: false,
      );
      return;
    }
    final provider = context.read<VideoProvider>();
    final amountText = provider.registrationAmountPaidController.text.trim();
    final amount = amountText.isNotEmpty
        ? (num.tryParse(amountText)?.toString() ?? amountText)
        : '499';
    provider.setRegistrationPaymentDetails(
      paymentId: normalizedPaymentId,
      paymentDate: _formatDate(DateTime.now()),
      amountPaid: amount,
      planType: provider.registrationPlanTypeController.text.trim().isEmpty
          ? _defaultPlan
          : provider.registrationPlanTypeController.text.trim(),
      validity: provider.registrationValidityController.text.trim().isEmpty
          ? _defaultValidity
          : provider.registrationValidityController.text.trim(),
      paymentMethod: paymentMethod,
      markPaid: true,
    );
    provider.registrationFeeDetailsController.text =
        provider.registrationFeeDetailsValue;

    final contentId = (provider.content ?? widget.movie).id;
    if (contentId == null) {
      CustomToast.show(
        context,
        'Payment succeeded, but content details are unavailable for updating.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isWorkflowUpdating = true);
    final result = await provider.updateContentAgreementWorkflow(
      contentId: contentId,
    );
    if (!mounted) return;
    setState(() => _isWorkflowUpdating = false);
    CustomToast.show(
      context,
      result['message']?.toString() ??
          (result['success'] == true
              ? 'Onboarding charges paid successfully.'
              : 'Payment succeeded, but the content could not be updated.'),
      isSuccess: result['success'] == true,
    );
    if (result['success'] == true) {
      try {
        await provider.getContentById(contentId);
      } catch (_) {
        // The update succeeded; keep the current workflow state.
      }
    }
  }

  Future<void> _submitForApproval(VideoProvider provider, Content movie) async {
    if (!provider.hasUploadedAgreement) {
      CustomToast.show(
        context,
        'Upload the signed agreement before sending for admin approval.',
        isSuccess: false,
      );
      return;
    }

    if (!provider.isRegistrationFeePaid) {
      CustomToast.show(
        context,
        'Complete onboarding fee payment before sending for admin approval.',
        isSuccess: false,
      );
      return;
    }

    if (movie.id == null || provider.content == null) {
      CustomToast.show(context, 'Content details are not available.',
          isSuccess: false);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final previousStatus = provider.content!.approvalStatus;
    provider.content!.approvalStatus = 'PENDING';
    provider.registrationFeeDetailsController.text =
        provider.registrationFeeDetailsValue;

    try {
      final updated = await provider.editContent(context, movie.id!);
      if (updated != null) {
        await provider.getContentById(movie.id!);
        if (!mounted) return;
        CustomToast.show(
          context,
          'Agreement submitted. Content moved to admin approval.',
          isSuccess: true,
        );
      } else {
        provider.content!.approvalStatus = previousStatus;
      }
    } catch (_) {
      provider.content!.approvalStatus = previousStatus;
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoProvider>(
      builder: (context, provider, _) {
        final theme = widget.theme;
        final movie = provider.content ?? widget.movie;
        final template =
            buildAgreementTemplate(movie: movie, mediaHouse: _mediaHouse);
        final normalizedStatus = (movie.approvalStatus ?? '').toUpperCase();
        final alreadySent = normalizedStatus == 'PENDING';

        return Column(
          children: [
            _surfaceCard(
              theme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload Files & Settings',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Complete both steps before sending this content for admin approval.',
                    style: TextStyle(
                      color: theme.canvasColor.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  UploadFormHelpers.buildSectionCard(
                    'Step 1. Signed Agreement Upload',
                    [
                      _workflowInfoRow(
                        theme,
                        icon: Icons.file_present_rounded,
                        title: 'Signed Agreement',
                        subtitle: provider.hasUploadedAgreement
                            ? 'Signed document uploaded successfully.'
                            : 'Upload the signed agreement hard copy before charges payment.',
                        trailingLabel: provider.hasUploadedAgreement
                            ? 'Uploaded'
                            : 'Pending',
                        trailingColor: provider.hasUploadedAgreement
                            ? const Color(0xFF0F9D58)
                            : const Color(0xFFD97706),
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
                          onPressed: _isDownloading
                              ? null
                              : () => _downloadAgreement(movie),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          icon: _isDownloading
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
                            _isDownloading
                                ? 'Preparing PDF...'
                                : 'Download Template',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: provider.isAgreementUploading ||
                                  _isWorkflowUpdating
                              ? null
                              : () async {
                                  final uploaded = await provider
                                      .pickAndUploadAgreementDocument();
                                  if (!mounted) return;
                                  if (!uploaded) {
                                    CustomToast.show(
                                      context,
                                      'Agreement upload cancelled.',
                                      isSuccess: false,
                                    );
                                    return;
                                  }

                                  final contentId =
                                      (provider.content ?? movie).id;
                                  if (contentId == null) {
                                    CustomToast.show(
                                      context,
                                      'Agreement uploaded, but content details are unavailable for updating.',
                                      isSuccess: false,
                                    );
                                    return;
                                  }

                                  setState(() => _isWorkflowUpdating = true);
                                  final result = await provider
                                      .updateContentAgreementWorkflow(
                                    contentId: contentId,
                                  );
                                  if (!mounted) return;
                                  setState(() => _isWorkflowUpdating = false);
                                  CustomToast.show(
                                    context,
                                    result['message']?.toString() ??
                                        'Unable to update the agreement details.',
                                    isSuccess: result['success'] == true,
                                  );
                                  if (result['success'] == true) {
                                    try {
                                      await provider.getContentById(contentId);
                                    } catch (_) {
                                      // The update succeeded; keep local state.
                                    }
                                  }
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
                                ClipboardData(
                                    text: provider.agreementDocumentUrl),
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
                    ],
                    theme,
                  ),
                  const SizedBox(height: 12),
                  UploadFormHelpers.buildSectionCard(
                    'Step 2. Onboarding Charges',
                    [
                      UploadFormHelpers.buildModernToggleRow(
                        'Onboarding Fee Paid',
                        provider.hasUploadedAgreement
                            ? 'Y = Paid, N = Not paid'
                            : 'Upload signed agreement first, then complete payment',
                        provider.isRegistrationFeePaid,
                        (value) {
                          if (_isWorkflowUpdating) return;
                          if (value) {
                            if (!provider.hasUploadedAgreement) {
                              CustomToast.show(
                                context,
                                'Upload the signed agreement before paying onboarding charges.',
                                isSuccess: false,
                              );
                              return;
                            }
                            _startRegistrationPayment(provider);
                            return;
                          }
                          provider.clearRegistrationPaymentDetails(
                              markUnpaid: true);
                        },
                        theme,
                      ),
                      const SizedBox(height: 16),
                      if (!provider.hasUploadedAgreement) ...[
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
                            'Upload the signed agreement in Step 1. After that, the onboarding amount field and payment button will be enabled here.',
                            style: TextStyle(
                              color: theme.canvasColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ] else if (!provider.isRegistrationFeePaid) ...[
                        CustomTextField(
                          controller: provider.registrationAmountPaidController,
                          hintText: 'Enter onboarding amount',
                          label: 'Onboarding Amount',
                          textInputType: TextInputType.number,
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _startRegistrationPayment(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Pay Onboarding Charges'),
                          ),
                        ),
                      ] else ...[
                        _readOnlyLine(
                          'Payment ID',
                          provider.registrationPaymentIdController.text,
                        ),
                        _readOnlyLine(
                          'Payment Date',
                          provider.registrationPaymentDateController.text,
                        ),
                        _readOnlyLine(
                          'Amount Paid',
                          provider.registrationAmountPaidController.text,
                        ),
                        _readOnlyLine(
                          'Plan Type',
                          provider.registrationPlanTypeController.text,
                        ),
                        _readOnlyLine(
                          'Validity',
                          provider.registrationValidityController.text,
                        ),
                        _readOnlyLine(
                          'Payment Method',
                          provider.registrationPaymentMethodController.text,
                        ),
                      ],
                    ],
                    theme,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: alreadySent || _isSubmitting
                    ? null
                    : () => _submitForApproval(provider, movie),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.approval_outlined),
                label: Text(
                  alreadySent
                      ? 'Waiting For Admin Approval'
                      : 'Send To Admin Approval',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _surfaceCard(ThemeData theme, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.24),
        ),
      ),
      child: child,
    );
  }

  Widget _statusPill(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _workflowInfoRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailingLabel,
    required Color trailingColor,
  }) {
    return Container(
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
            child: Icon(icon, color: theme.primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.canvasColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: trailingColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: trailingColor.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              trailingLabel,
              style: TextStyle(
                color: trailingColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? 'N/A' : value)),
        ],
      ),
    );
  }
}
