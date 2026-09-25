import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'routes.dart';
import 'screens/activities_screens.dart';
import 'screens/admin_screen.dart';
import 'screens/ai_screens.dart';
import 'screens/auth_screens.dart';
import 'screens/home_shell.dart';
import 'screens/report_screens.dart';
import 'screens/schedule_screens.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const TimeWiseApp());
}

/// TimeWise AI – A Decision Support System for Daily Time Allocation Using AI
/// ต้นแบบระบบ (System Prototype) สำหรับรายงานวิชา 254374 การวิเคราะห์และออกแบบระบบ
class TimeWiseApp extends StatelessWidget {
  const TimeWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TimeWise AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('th', 'TH'),
      supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: Routes.login,
      routes: {
        Routes.login: (_) => const LoginScreen(),
        Routes.register: (_) => const RegisterScreen(),
        Routes.setup: (_) => const SetupScreen(),
        Routes.home: (_) => const HomeShell(),
        Routes.activityForm: (_) => const ActivityFormScreen(),
        Routes.askAi: (_) => const AskAiScreen(),
        Routes.aiLoading: (_) => const AiLoadingScreen(),
        Routes.options: (_) => const OptionsScreen(),
        Routes.recommendation: (_) => const RecommendationScreen(),
        Routes.adjust: (_) => const AdjustPlanScreen(),
        Routes.notifications: (_) => const NotificationsScreen(),
        Routes.track: (_) => const TrackScreen(),
        Routes.history: (_) => const HistoryScreen(),
        Routes.profile: (_) => const ProfileScreen(),
        Routes.admin: (_) => const AdminScreen(),
      },
    );
  }
}
