import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'providers/auth_provider.dart';
import 'providers/iptv_provider.dart';
import 'providers/config_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';
import 'screens/search_screen.dart';

import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';
import 'services/appwrite_service.dart';

void main() async {
  debugPrint('CODRO_DEBUG: Starting main()...');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('CODRO_DEBUG: WidgetsFlutterBinding initialized.');

  try {
    debugPrint('CODRO_DEBUG: Fetching remote config for ads...');
    final appwrite = AppwriteService();
    final config = await appwrite.getConfig();
    final adKey =
        config['appodeal_key']?.toString() ??
        "0b5c0c469e1c01f1161f7aa8b5b6d08a25513d94e8f7a425";

    debugPrint(
      'CODRO_DEBUG: Initializing Appodeal with key: ${adKey.substring(0, 5)}...',
    );
    Appodeal.setAppKey(adKey);
    Appodeal.initialize(
      adTypes: [
        AppodealAdType.Banner,
        AppodealAdType.Interstitial,
        AppodealAdType.RewardedVideo,
      ],
      testMode: true, // Enable for testing
    );
    debugPrint('CODRO_DEBUG: Appodeal initialized.');
  } catch (e) {
    debugPrint('CODRO_DEBUG: Appodeal initialization failed: $e');
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('CODRO_DEBUG: Global Flutter Error: ${details.exception}');
  };

  debugPrint('CODRO_DEBUG: Running App...');
  runApp(const CodroApp());
}

class CodroApp extends StatelessWidget {
  const CodroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => IptvProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
      ],
      child: MaterialApp(
        title: 'Codro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
        // Define routes as we build screens
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/search': (context) => const SearchScreen(),
        },
      ),
    );
  }
}
