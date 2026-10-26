import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_house/app/core/constant/image_constant.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/ui/NavigationPage.dart';
import 'package:media_house/app/widget/show_toast.dart';
import 'package:media_house/app/core/utils/user_message.dart';
import 'package:media_house/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';

import '../../../provider/user_provider.dart';

class OtpVerificationPage extends StatefulWidget {
  final String mobileNumber;
  final String password;

  const OtpVerificationPage({
    super.key,
    required this.mobileNumber,
    required this.password,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final TextEditingController otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  Timer? _timer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var selectedThemeData =
        Provider.of<ThemeProvider>(context, listen: false).getTheme;

    return Scaffold(
      backgroundColor: selectedThemeData.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: ResponsiveWidget.isMobile(context) ? 90 : 150,
                  child: Hero(
                    tag: "logo",
                    child: ClipRRect(
                      borderRadius: BorderRadiusGeometry.circular(25),
                      child: Image.asset(
                        ImageConstant.logo,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 120),
            Center(
              child: SizedBox(
                width:
                    ResponsiveWidget.isMobile(context) ? double.infinity : 400,
                child: otpCard(selectedThemeData),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget otpCard(ThemeData selectedThemeData) {
    return Padding(
      padding: ResponsiveWidget.isMobile(context)
          ? EdgeInsets.zero
          : const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        color: selectedThemeData.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Verify OTP',
                style: TextStyle(
                  color: selectedThemeData.primaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Enter the OTP sent to ${widget.mobileNumber}",
                style: TextStyle(
                    color: selectedThemeData.primaryColor, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: otpController,
                decoration: const InputDecoration(
                  labelText: 'OTP',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedThemeData.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : () => _verifyOtp(context),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : Text(
                        'Verify',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: selectedThemeData.canvasColor,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: (_secondsRemaining == 0 && !_isResending)
                    ? () => _resendOtp(context)
                    : null,
                child: _isResending
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: selectedThemeData.primaryColor,
                        ),
                      )
                    : Text(
                        _secondsRemaining == 0
                            ? 'Resend OTP'
                            : 'Resend OTP in $_secondsRemaining s',
                        style: TextStyle(
                          color: selectedThemeData.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verifyOtp(BuildContext context) async {
    final otp = otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      CustomToast.show(context, 'Please enter a valid 6-digit OTP.',
          isSuccess: false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    var result = await Provider.of<UserProvider>(context, listen: false)
        .verifyOtp(widget.mobileNumber, otp, context);

    if (!context.mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      CustomToast.show(
          context,
          UserMessage.resolve(
              apiMessage: result['message']?.toString(),
              fallbackMessage: 'Signed in successfully.'),
          isSuccess: true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => NavigationPage()),
      );
    } else {
      CustomToast.show(
          context,
          UserMessage.resolve(
              apiMessage: result['message']?.toString(),
              fallbackMessage: 'Unable to verify the OTP. Please try again.'),
          isSuccess: false);
    }
  }

  Future<void> _resendOtp(BuildContext context) async {
    setState(() {
      _isResending = true;
    });

    final result = await Provider.of<UserProvider>(context, listen: false)
        .loginWithCredentials(widget.mobileNumber, widget.password, context);

    if (!context.mounted) return;
    setState(() {
      _isResending = false;
    });

    if (result['success'] == true) {
      CustomToast.show(
          context,
          UserMessage.resolve(
              apiMessage: result['message']?.toString(),
              fallbackMessage: 'OTP sent again.'),
          isSuccess: true);
      _startCountdown();
    } else {
      CustomToast.show(
          context,
          UserMessage.resolve(
              apiMessage: result['message']?.toString(),
              fallbackMessage: 'Unable to resend the OTP. Please try again.'),
          isSuccess: false);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _secondsRemaining = 0;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }
}
