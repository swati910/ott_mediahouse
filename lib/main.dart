import 'package:flutter/material.dart';
import 'package:media_house/app/provider/content_provider.dart';
import 'package:media_house/app/provider/graphProvider.dart';
import 'package:media_house/app/provider/mediaHouseProvider.dart';
import 'package:media_house/app/provider/notification_provider.dart';
import 'package:media_house/app/provider/notification_settings_provider.dart';
import 'package:media_house/app/provider/series_provider.dart';
import 'package:media_house/app/provider/sign_up_provider.dart';
import 'package:media_house/app/provider/settelementProvider.dart';
import 'package:media_house/app/provider/shorts_provider.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/provider/ticketProvider.dart';
import 'package:media_house/app/provider/user_provider.dart';
import 'package:media_house/app/provider/videoProvider.dart';
import 'package:media_house/app/provider/wallet_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'app/core/navigation/app_navigator.dart';
import 'app/config/routes/routes.dart';
import 'app/core/storage/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await StorageService.initialize();

  final themeBool = StorageService.instance.preferences.isDarkMode;

  // Initialize Firebase

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(isDark: themeBool),
        ),
        ChangeNotifierProvider(
          create: (context) => UserProvider(),
        ),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
        ChangeNotifierProvider(create: (_) => MediaHouseProvider()),
        ChangeNotifierProvider(create: (_) => VideoProvider()),
        ChangeNotifierProvider(create: (_) => TicketProvider()),
        ChangeNotifierProvider(create: (_) => SettelementProvider()),
        ChangeNotifierProvider(create: (_) => GraphProvider()),
        ChangeNotifierProvider(create: (_) => ShortProvider()),
        ChangeNotifierProvider(create: (_) => SeriesProvider()),
        ChangeNotifierProvider(create: (_) => SignUpProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationSettingsProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      scaffoldMessengerKey: globalMessengerKey,
      title: 'Production House',
      theme: themeProvider.getTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      // Navigate based on login state
      initialRoute: "/",
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}
// latest code
