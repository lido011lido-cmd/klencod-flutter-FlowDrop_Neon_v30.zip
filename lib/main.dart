import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_scope.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'services/download_manager.dart';
import 'services/history_store.dart';
import 'services/rasp_guard.dart';
import 'services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RaspGuard.start(); // لا ننتظره هنا؛ Guard ينتظر نتيجة الفحوص عند أول اتصال
  final settings = AppSettings();
  await settings.load();
  await HistoryStore.instance.load();
  DownloadManager.instance.settings = settings;
  runApp(AppScope(settings: settings, child: const FlowDropApp()));
}

class FlowDropApp extends StatelessWidget {
  const FlowDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return MaterialApp(
      title: 'FlowDrop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: ThemeMode.dark, // التصميم النيون داكن فقط
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: dark ? const Color(0xFF030B2E) : AppColors.cardLight,
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          ),
          child: Directionality(
            textDirection: s.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}