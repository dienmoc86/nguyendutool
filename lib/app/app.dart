import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root Widget for NguyenDu Tool.
class NguyenDuApp extends ConsumerWidget {
  const NguyenDuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final router = ref.watch(appRouterProvider);

    ThemeMode themeMode;
    switch (settings.themeMode) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      default:
        themeMode = ThemeMode.system;
    }

    return MaterialApp.router(
      title: 'NguyenDu Tool - Trợ lý Giáo viên & Nhà trường',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

/// Backward compatibility alias
typedef ISchoolToolsApp = NguyenDuApp;
