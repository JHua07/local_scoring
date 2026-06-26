import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/home/home_page.dart';
import 'features/library/library_page.dart';
import 'features/ranking/ranking_page.dart';
import 'features/review_form/review_form_page.dart';
import 'features/settings/settings_page.dart';
import 'providers/review_provider.dart';
import 'providers/theme_provider.dart';
import 'core/theme/app_design_tokens.dart';

class PrivateReviewApp extends ConsumerStatefulWidget {
  const PrivateReviewApp({super.key});

  @override
  ConsumerState<PrivateReviewApp> createState() => _PrivateReviewAppState();
}

class _PrivateReviewAppState extends ConsumerState<PrivateReviewApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(templateListProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    // 计算出真正生效的亮度——跟随系统时取系统亮度
    final platformBrightness = MediaQuery.of(context).platformBrightness;
    final effectiveBrightness = themeMode == ThemeMode.dark
        ? Brightness.dark
        : themeMode == ThemeMode.light
            ? Brightness.light
            : platformBrightness;

    final themeData = _buildCupertinoTheme(effectiveBrightness);

    return CupertinoApp(
      title: '私人评分',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      home: CupertinoTheme(
        data: themeData,
        child: const MainShell(),
      ),
    );
  }

  CupertinoThemeData _buildCupertinoTheme(Brightness brightness) {
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: AppTokens.primary,
      scaffoldBackgroundColor: AppTokens.bg(brightness),
      barBackgroundColor: AppTokens.bg(brightness).withValues(alpha: 0.85),
      textTheme: CupertinoTextThemeData(
        navLargeTitleTextStyle: TextStyle(
          inherit: false,
          fontSize: AppTokens.fontSizeHero,
          fontWeight: FontWeight.w800,
          color: AppTokens.txt(brightness),
          letterSpacing: -0.5,
        ),
        navTitleTextStyle: TextStyle(
          inherit: false,
          fontSize: AppTokens.fontSizeCardTitle,
          fontWeight: FontWeight.w600,
          color: AppTokens.txt(brightness),
        ),
      ),
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);

    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: AppTokens.primary,
        inactiveColor: AppTokens.textSecondary,
        backgroundColor: brightness == Brightness.dark
            ? AppTokens.darkCardBackground
            : AppTokens.cardBackground,
        border: Border(
          top: BorderSide(
            color: AppTokens.sep(brightness).withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.today),
            activeIcon: Icon(CupertinoIcons.today_fill),
            label: '今天',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.archivebox),
            activeIcon: Icon(CupertinoIcons.archivebox_fill),
            label: '评分库',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar),
            activeIcon: Icon(CupertinoIcons.chart_bar_fill),
            label: '排行',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.gear),
            activeIcon: Icon(CupertinoIcons.gear_solid),
            label: '设置',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return const HomePage();
          case 1:
            return const LibraryPage();
          case 2:
            return const RankingPage();
          case 3:
            return const SettingsPage();
          default:
            return const HomePage();
        }
      },
    );
  }
}



