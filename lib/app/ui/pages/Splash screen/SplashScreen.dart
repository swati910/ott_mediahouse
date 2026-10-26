import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_house/app/core/constant/image_constant.dart';
import 'package:media_house/app/ui/pages/sign%20in%20page/SignInPage.dart';
import '../../../../device/utils/ResponsiveWidget.dart';
import '../../../core/auth/auth_service.dart';
import '../../NavigationPage.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initializeSplash();
  }

  Future<void> _initializeSplash() async {
    await getData();
    if (!mounted) return;
    Timer(const Duration(seconds: 2), _navigateToNextScreen);
  }

  Future<void> getData() async {
    final loggedIn = await AuthService.isAuthenticated();
    if (!mounted) return;
    setState(() {
      isLoggedIn = loggedIn;
    });
  }

  void _navigateToNextScreen() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => isLoggedIn ? NavigationPage() : SignInPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryColor,
      body: SafeArea(
          child: Stack(fit: StackFit.expand, children: [
        ResponsiveWidget.isMobile(context)
            ? Hero(
                tag: 'logo',
                child: Image.asset(
                  ImageConstant.fullScreenLogo,
                  fit: BoxFit.cover,
                ),
              )
            : Hero(
                tag: 'logo',
                child: Image.asset(
                  ImageConstant.webFullScreenLogo,
                  fit: BoxFit.cover,
                ),
              ),
        /* Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Text(
              'Watch First Day First Show',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: textSize,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                shadows: const [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.black54,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ), */
      ])),
    );
  }
}
