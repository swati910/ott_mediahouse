import 'package:flutter/material.dart';
import 'package:media_house/app/ui/pages/Splash%20screen/SplashScreen.dart';
import 'package:media_house/app/ui/pages/analytics_page/analyticsPage.dart';
import 'package:media_house/app/ui/pages/document_page/documentpage.dart';
import 'package:media_house/app/ui/pages/help%20support%20page/helpDesk.dart';
import 'package:media_house/app/ui/pages/allContent_page/allContent.dart';
import 'package:media_house/app/ui/pages/profile%20page/component/EditProfilePage.dart';
import 'package:media_house/app/ui/pages/released_content_page/released_content.dart';
import 'package:media_house/app/ui/pages/settlemet_page/SettlementPage.dart';
import 'package:media_house/app/ui/pages/wallet_page/wallet_page.dart';
import 'package:media_house/app/ui/pages/sign%20in%20page/SignInPage.dart';
import 'package:media_house/app/ui/pages/sign%20in%20page/forgot_password_pages.dart';

import '../../ui/NavigationPage.dart';
import '../../ui/pages/profile page/ProfilePage.dart';
import 'app_routes.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return buildRoute(SignInPage(), settings: settings);

      case AppRoutes.entry:
        bool isLoggedIn = settings.arguments as bool;
        return buildRoute(SplashScreen(), settings: settings);

      case AppRoutes.home:
        return buildRoute(NavigationPage(), settings: settings);

      case AppRoutes.forgotPassword:
        return buildRoute(const ForgotPasswordPage(), settings: settings);

      case AppRoutes.profile:
        return buildRoute(ProfilePage(), settings: settings);

      case AppRoutes.editProfile:
        return buildRoute(EditProfilePage(), settings: settings);

      case AppRoutes.document:
        return buildRoute(DocumentsPage(), settings: settings);

      case AppRoutes.analytics:
        return buildRoute(AnalyticsPage(), settings: settings);

      case AppRoutes.settlement:
        return buildRoute(SettlementPage(), settings: settings);

      case AppRoutes.wallet:
        return buildRoute(WalletPage(), settings: settings);

      case AppRoutes.helpSupport:
        return buildRoute(HelpDeskPage(), settings: settings);

      case AppRoutes.releaseContent:
        return buildRoute(ReleasedContentPage(), settings: settings);

      case AppRoutes.pendingContent:
        return buildRoute(AllContentPage(), settings: settings);

      default:
        return buildRoute(SplashScreen(), settings: settings);
    }
  }

  static MaterialPageRoute buildRoute(Widget child,
      {required RouteSettings settings}) {
    return MaterialPageRoute(
        settings: settings, builder: (BuildContext context) => child);
  }

  static Route _createRoute(Widget root) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => root,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = const Offset(0.0, 1.0);
        var end = Offset.zero;
        const curve = Curves.ease;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text(
            'Exit App',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 450.0,
                  width: 450.0,
                  //child: Lottie.asset('assets/lottie/error.json'),
                ),
                Text(
                  'Seems the route you\'ve navigated to doesn\'t exist!!',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
