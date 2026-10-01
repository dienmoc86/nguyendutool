import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../core/shortcuts/app_shortcuts.dart';
import '../../../core/update/update_notifier.dart';
import 'command_palette_dialog.dart';
import 'sidebar.dart';
import 'topbar.dart';
import 'update_dialog.dart';

/// Desktop Shell wrapping the main content area with Sidebar and TopBar.
class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Non-blocking background check for updates 3 seconds after startup
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          ref.read(updateNotifierProvider.notifier).checkForUpdates(silent: true);
        }
      });
    });
  }

  String _getTitleForRoute(String location) {
    if (location.startsWith(AppRoutes.pdfConverter)) {
      return 'Chuyển đổi File PDF sang Word / Excel';
    } else if (location.startsWith(AppRoutes.textToSpeech)) {
      return 'Chuyển Văn bản thành Giọng nói AI (Text to Speech)';
    } else if (location.startsWith(AppRoutes.speechToText)) {
      return 'Chuyển File Ghi âm & Video thành Văn bản (Google Gemini AI)';
    } else if (location.startsWith(AppRoutes.settings)) {
      return 'Cài đặt hệ thống & Cấu hình Google Gemini API';
    } else if (location.startsWith(AppRoutes.lessonPlanner)) {
      return 'Trợ lý Soạn Giáo án AI chuẩn Công văn 5512/BGDĐT-GDTrH';
    } else if (location.startsWith(AppRoutes.assessmentStudio)) {
      return 'Xưởng Đề kiểm tra & Đánh giá (Assessment Studio)';
    } else if (location.startsWith(AppRoutes.scanner)) {
      return 'Quét Đề thi, Sổ sách & Số hóa học liệu';
    } else if (location.startsWith(AppRoutes.videoStudio)) {
      return 'Xưởng dựng Video Bài giảng E-Learning';
    } else if (location.startsWith(AppRoutes.fileLibrary)) {
      return 'Kho Học liệu số & Tài liệu lưu trữ';
    }
    return 'Bàn làm việc Giáo viên - Tổng quan';
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final screenWidth = MediaQuery.of(context).size.width;

    // Listen for updates and show dialog automatically
    ref.listen<UpdateState>(updateNotifierProvider, (previous, next) {
      if (next.isAvailable && !next.userDismissed && (previous == null || !previous.isAvailable)) {
        UpdateDialog.show(context);
      }
    });

    // Responsive auto-collapse on small desktop windows
    final shouldCollapse = _isSidebarCollapsed || screenWidth < 1080;

    return Shortcuts(
      shortcuts: AppShortcuts.defaultShortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          OpenCommandPaletteIntent: CallbackAction<OpenCommandPaletteIntent>(
            onInvoke: (intent) => CommandPaletteDialog.show(context),
          ),
          GoToDashboardIntent: CallbackAction<GoToDashboardIntent>(
            onInvoke: (intent) => context.go(AppRoutes.dashboard),
          ),
          GoToSettingsIntent: CallbackAction<GoToSettingsIntent>(
            onInvoke: (intent) => context.go(AppRoutes.settings),
          ),
          GoToLibraryIntent: CallbackAction<GoToLibraryIntent>(
            onInvoke: (intent) => context.go(AppRoutes.fileLibrary),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                AppSidebar(
                  isCollapsed: shouldCollapse,
                  currentRoute: location,
                ),
                Expanded(
                  child: Column(
                    children: [
                      TopBar(
                        activeTitle: _getTitleForRoute(location),
                        isSidebarCollapsed: _isSidebarCollapsed,
                        onToggleSidebar: () {
                          setState(() {
                            _isSidebarCollapsed = !_isSidebarCollapsed;
                          });
                        },
                      ),
                      Expanded(
                        child: widget.child,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
