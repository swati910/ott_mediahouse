import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_house/app/core/constant/image_constant.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/widget/show_toast.dart';
import 'package:media_house/data/services/forgot_password_service.dart';
import 'package:provider/provider.dart';

import 'SignInPage.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.service});

  final ForgotPasswordService? service;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  late final ForgotPasswordService _service;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ForgotPasswordService();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final mobile = _mobileController.text;
    final result = await _service.sendForgotPasswordOtp(mobile);
    if (!mounted) return;
    setState(() => _loading = false);
    CustomToast.show(
        context,
        result.message.isEmpty
            ? (result.success
                ? 'OTP sent successfully.'
                : 'Unable to send OTP.')
            : result.message,
        isSuccess: result.success);
    if (result.success) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ForgotPasswordOtpPage(
          mobileNumber: mobile,
          initialUsername: result.username,
          service: _service,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => _AuthShell(
        title: 'Forgot Password',
        subtitle: 'Enter your registered mobile number to receive an OTP.',
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _mobileController,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10)
              ],
              decoration: const InputDecoration(
                  labelText: 'Mobile Number', border: OutlineInputBorder()),
              validator: (value) => value?.length == 10
                  ? null
                  : 'Enter a valid 10-digit mobile number',
              onFieldSubmitted: (_) => _sendOtp(),
            ),
            const SizedBox(height: 20),
            _SubmitButton(
                label: 'Send OTP', loading: _loading, onPressed: _sendOtp),
          ]),
        ),
      );
}

class ForgotPasswordOtpPage extends StatefulWidget {
  const ForgotPasswordOtpPage({
    super.key,
    required this.mobileNumber,
    required this.service,
    this.initialUsername,
  });

  final String mobileNumber;
  final String? initialUsername;
  final ForgotPasswordService service;

  @override
  State<ForgotPasswordOtpPage> createState() => _ForgotPasswordOtpPageState();
}

class _ForgotPasswordOtpPageState extends State<ForgotPasswordOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  Timer? _timer;
  int _remaining = 60;
  bool _verifying = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  String get _maskedMobile => widget.mobileNumber.length == 10
      ? '******${widget.mobileNumber.substring(6)}'
      : widget.mobileNumber;

  void _startTimer() {
    _timer?.cancel();
    _remaining = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _remaining--);
      if (_remaining <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (_verifying || !_formKey.currentState!.validate()) return;
    setState(() => _verifying = true);
    final result = await widget.service.verifyForgotPasswordOtp(
      mobileNumber: widget.mobileNumber,
      otp: _otpController.text,
    );
    _otpController.clear();
    if (!mounted) return;
    setState(() => _verifying = false);
    CustomToast.show(
        context,
        result.message.isEmpty
            ? (result.success
                ? 'OTP verified successfully.'
                : 'Unable to verify OTP.')
            : result.message,
        isSuccess: result.success);
    if (result.success) {
      _timer?.cancel();
      final verification = _ForgotPasswordVerification(
        mobileNumber: widget.mobileNumber,
        username:
            result.username ?? widget.initialUsername ?? widget.mobileNumber,
      );
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _ResetPasswordPage(
            verification: verification, service: widget.service),
      ));
    }
  }

  Future<void> _resend() async {
    if (_remaining > 0 || _resending) return;
    setState(() => _resending = true);
    final result =
        await widget.service.sendForgotPasswordOtp(widget.mobileNumber);
    if (!mounted) return;
    setState(() => _resending = false);
    CustomToast.show(
        context,
        result.message.isEmpty
            ? (result.success
                ? 'OTP sent successfully.'
                : 'Unable to resend OTP.')
            : result.message,
        isSuccess: result.success);
    if (result.success) {
      _otpController.clear();
      setState(_startTimer);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.clear();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthShell(
        title: 'Verify OTP',
        subtitle: 'Enter the 6-digit OTP sent to $_maskedMobile.',
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _otpController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6)
              ],
              decoration: const InputDecoration(
                  labelText: '6-digit OTP',
                  border: OutlineInputBorder(),
                  counterText: ''),
              maxLength: 6,
              validator: (value) =>
                  value?.length == 6 ? null : 'Enter the complete 6-digit OTP',
              onFieldSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 20),
            _SubmitButton(
                label: 'Verify OTP', loading: _verifying, onPressed: _verify),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _remaining == 0 && !_resending ? _resend : null,
              child: _resending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_remaining > 0
                      ? 'Resend OTP in $_remaining s'
                      : 'Resend OTP'),
            ),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Edit mobile number')),
          ]),
        ),
      );
}

class _ForgotPasswordVerification {
  const _ForgotPasswordVerification(
      {required this.mobileNumber, required this.username});
  final String mobileNumber;
  final String username;
}

class _ResetPasswordPage extends StatefulWidget {
  const _ResetPasswordPage({required this.verification, required this.service});
  final _ForgotPasswordVerification verification;
  final ForgotPasswordService service;

  @override
  State<_ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<_ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _loading = false;

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value != value.trim()) {
      return 'Leading or trailing spaces are not allowed';
    }
    if (value.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Use 8+ characters with uppercase, lowercase, number and special character';
    }
    return null;
  }

  Future<void> _reset() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await widget.service.resetForgotPassword(
      mobileNumber: widget.verification.mobileNumber,
      username: widget.verification.username,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    CustomToast.show(
        context,
        result.message.isEmpty
            ? (result.success
                ? 'Password reset successfully.'
                : 'Unable to reset password.')
            : result.message,
        isSuccess: result.success);
    if (result.success) {
      _passwordController.clear();
      _confirmController.clear();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInPage()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _passwordController.clear();
    _confirmController.clear();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthShell(
        title: 'Reset Password',
        subtitle: 'Create a strong new password for your account.',
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _passwordController,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                      _hidePassword ? Icons.visibility_off : Icons.visibility),
                ),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmController,
              obscureText: _hideConfirm,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _hideConfirm ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                  icon: Icon(
                      _hideConfirm ? Icons.visibility_off : Icons.visibility),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirm password is required';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
              onFieldSubmitted: (_) => _reset(),
            ),
            const SizedBox(height: 20),
            _SubmitButton(
                label: 'Reset Password', loading: _loading, onPressed: _reset),
          ]),
        ),
      );
}

class _AuthShell extends StatelessWidget {
  const _AuthShell(
      {required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).getTheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight - 40),
                    child: Center(
                        child: SizedBox(
                      width: 420,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Image.asset(ImageConstant.logo,
                            height: 110, fit: BoxFit.contain),
                        const SizedBox(height: 28),
                        Card(
                            color: theme.cardColor,
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(title,
                                        style: TextStyle(
                                            color: theme.primaryColor,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text(subtitle, textAlign: TextAlign.center),
                                    const SizedBox(height: 24),
                                    child,
                                  ]),
                            )),
                      ]),
                    )),
                  ),
                )),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton(
      {required this.label, required this.loading, required this.onPressed});
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).getTheme;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label),
        ),
      ),
    );
  }
}
