import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../core/update/update_notifier.dart';
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
      return 'Chuyển đổi Giáo án & Bài giảng (Word / Excel / PowerPoint)';
    } else if (location.startsWith(AppRoutes.scanner)) {
      return 'Quét Đề thi, Sổ sách & Số hóa học liệu';
    } else if (location.startsWith(AppRoutes.textToSpeech)) {
      return 'Đọc văn bản & Lồng tiếng bài giảng (AI Voice)';
    } else if (location.startsWith(AppRoutes.videoStudio)) {
      return 'Xưởng dựng Video Bài giảng E-Learning';
    } else if (location.startsWith(AppRoutes.fileLibrary)) {
      return 'Kho Học liệu số & Tài liệu lưu trữ';
    } else if (location.startsWith(AppRoutes.settings)) {
      return 'Cài đặt hệ thống';
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

    return Scaffold(
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
    );
  }
}
