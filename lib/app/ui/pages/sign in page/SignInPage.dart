import 'package:flutter/material.dart';
import 'package:media_house/app/core/constant/image_constant.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/ui/pages/sign%20in%20page/otp_screen.dart';
import 'package:media_house/app/widget/show_toast.dart';
import 'package:media_house/app/core/utils/user_message.dart';
import 'package:media_house/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';

import '../../../provider/user_provider.dart';
import '../sign up page/SignUpPage.dart';
import 'forgot_password_pages.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var selectedThemeData =
        Provider.of<ThemeProvider>(context, listen: false).getTheme;

    return Scaffold(
      backgroundColor: selectedThemeData.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight -
                        40 -
                        MediaQuery.of(context).viewInsets.bottom)
                    .clamp(0.0, double.infinity),
              ),
              child: Center(
                child: SizedBox(
                  width: ResponsiveWidget.isMobile(context)
                      ? double.infinity
                      : 400,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height:
                            ResponsiveWidget.isMobile(context) ? 100 : 150,
                        child: Hero(
                          tag: "logo",
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Image.asset(
                              ImageConstant.logo,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      loginCard(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget loginCard() {
    var selectedThemeData =
        Provider.of<ThemeProvider>(context, listen: false).getTheme;

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
              InkWell(
                onTap: _navigateToSignIn,
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    color: selectedThemeData.primaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: selectedThemeData.canvasColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _handleLogin(context),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordPage(),
                            ),
                          ),
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedThemeData.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : () => _handleLogin(context),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: selectedThemeData.canvasColor,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: TextStyle(
                      color: selectedThemeData.canvasColor,
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: _navigateToSignIn,
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        color: selectedThemeData.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin(BuildContext context) async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty) {
      CustomToast.show(context, 'Please enter username or mobile number',
          isSuccess: false);
      return;
    }

    if (password.isEmpty) {
      CustomToast.show(context, 'Please enter password', isSuccess: false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    var result = await Provider.of<UserProvider>(context, listen: false)
        .loginWithCredentials(username, password, context);
    if (!context.mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final data = result['data'];
      final sentTo = data is Map<String, dynamic>
          ? (data['otpSentTo'] ?? data['username'] ?? username).toString()
          : username;
      CustomToast.show(
          context,
          UserMessage.resolve(
              apiMessage: result['message']?.toString(),
              fallbackMessage: 'OTP sent to $sentTo.'),
          isSuccess: true);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationPage(
            mobileNumber: username,
            password: password,
          ),
        ),
      );
    } else {
      CustomToast.show(
          context,
          UserMessage.resolve(
              apiMessage: result['message']?.toString(),
              fallbackMessage: 'Unable to sign in. Please try again.'),
          isSuccess: false);
    }
  }

  void _navigateToSignIn() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignUpPage()),
    );
  }
}
