import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';
import '../utils/app_theme.dart';

import 'package:url_launcher/url_launcher.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    debugPrint('CODRO_DEBUG: Starting _loadAndNavigate');
    _loadAndNavigate();
  }

  Future<void> _loadAndNavigate() async {
    debugPrint('CODRO_DEBUG: _loadAndNavigate starting');
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final config = Provider.of<ConfigProvider>(context, listen: false);
    debugPrint('CODRO_DEBUG: Providers obtained');

    await Future.wait([
      config.init(),
      auth.tryAutoLogin(),
      Future.delayed(const Duration(milliseconds: 2500)),
    ]);

    if (mounted) {
      if (config.isMaintenanceMode) {
        _showMaintenanceDialog();
        return;
      }
      if (config.forceUpdate) {
        _showUpdateDialog();
        return;
      }
      if (auth.loginError == 'expired') {
        _showExpiryDialog();
        return;
      }
    }

    debugPrint(
      'CODRO_DEBUG: Navigation check - authenticated: ${auth.isAuthenticated}',
    );
    if (mounted) {
      if (auth.isAuthenticated) {
        debugPrint('CODRO_DEBUG: Navigating to /home');
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        debugPrint('CODRO_DEBUG: Navigating to /login');
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  void _showMaintenanceDialog() {
    final config = Provider.of<ConfigProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.engineering, color: Colors.orange),
              SizedBox(width: 10),
              Text('الصيانة', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            config.announcement.isNotEmpty
                ? config.announcement
                : 'توجد صيانة حالياً، يرجى المحاولة لاحقاً',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await config.refreshFlags();
                if (!config.isMaintenanceMode && mounted) {
                  Navigator.pop(context);
                  _loadAndNavigate();
                }
              },
              child: const Text('تحديث الحالة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpiryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.timer_off_outlined, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('انتهى الاشتراك', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            'يرجى التواصل مع الدعم الفني لشراء باقة جديدة أو لتجديد الباقة',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                auth.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateDialog() {
    final config = Provider.of<ConfigProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text('تحديث جديد', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            'يتوفر إصدار جديد من التطبيق، يرجى التحديث للمتابعة.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (config.updateUrl.isNotEmpty) {
                  final uri = Uri.parse(config.updateUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              child: const Text('تحديث الآن'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 280,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 60),
            const SpinKitThreeBounce(color: AppTheme.primaryColor, size: 25.0),
          ],
        ),
      ),
    );
  }
}
