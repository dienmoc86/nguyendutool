import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/ai/gemini_service.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/fonts/vietnamese_font_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/base_provider.dart';
import '../../../core/providers/tts_provider.dart';
import '../../../core/security/credential_service.dart';
import '../../../core/update/update_notifier.dart';
import '../../../core/product/product_info.dart';
import '../../shell/presentation/update_dialog.dart';
import '../../shell/presentation/support_author_dialog.dart';
import 'system_diagnostics_screen.dart';

/// Settings screen divided into General, Storage, AI Providers, Advanced, Diagnostics, and About.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedTabIndex = 0;

  final TextEditingController _legacyTextController = TextEditingController();
  final TextEditingController _convertedTextController = TextEditingController();
  Map<String, bool>? _installedFonts;
  bool _isLoadingFonts = false;

  final List<String> _tabs = [
    'Chung (General)',
    'Gói ngôn ngữ & Font chữ (Fonts & Language)',
    'Lưu trữ (Storage)',
    'Nhà cung cấp AI (Providers)',
    'Nâng cao (Advanced)',
    'Chẩn đoán hệ thống (Diagnostics)',
    'Thông tin (About)',
  ];

  bool _hasWindowsViVoice = false;
  bool _isCheckingVoice = false;

  @override
  void initState() {
    super.initState();
    _loadSystemFonts();
    _checkWindowsViVoice();
  }

  @override
  void dispose() {
    _legacyTextController.dispose();
    _convertedTextController.dispose();
    super.dispose();
  }

  Future<void> _checkWindowsViVoice() async {
    if (!Platform.isWindows) return;
    setState(() => _isCheckingVoice = true);
    try {
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r"Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Speech\Voices\Tokens\*', 'HKLM:\SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens\*' -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*vi-VN*' -or $_.Name -like '*Vietnamese*' -or $_.Name -like '*An*' }"
      ]);
      if (mounted) {
        setState(() {
          _hasWindowsViVoice = res.stdout.toString().trim().isNotEmpty;
          _isCheckingVoice = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingVoice = false);
    }
  }

  Future<void> _loadSystemFonts() async {
    setState(() => _isLoadingFonts = true);
    final fonts = await VietnameseFontService.checkInstalledEducationalFonts();
    if (mounted) {
      setState(() {
        _installedFonts = fonts;
        _isLoadingFonts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsNotifierProvider);
    final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
    final workspace = ref.watch(workspaceManagerProvider);
    final providerRegistry = ref.watch(providerRegistryProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Settings Inner Nav Menu
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                right: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedTabIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    selected: isSelected,
                    selectedTileColor: AppColors.primary.withOpacity(0.12),
                    title: Text(
                      _tabs[index],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primaryLight
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                    onTap: () => setState(() => _selectedTabIndex = index),
                  ),
                );
              },
            ),
          ),

          // Settings Content Body
          Expanded(
            child: _selectedTabIndex == 5
                ? const SystemDiagnosticsScreen()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Builder(
                        builder: (context) {
                          switch (_selectedTabIndex) {
                            case 0:
                              return _buildGeneralTab(context, settings, settingsNotifier);
                            case 1:
                              return _buildFontsAndLanguageTab(context);
                            case 2:
                              return _buildStorageTab(context, workspace);
                            case 3:
                              return _buildProvidersTab(context, providerRegistry);
                            case 4:
                              return _buildAdvancedTab(context, settings, settingsNotifier, workspace);
                            case 6:
                            default:
                              return _buildAboutTab(context);
                          }
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // 1. General Tab
  Widget _buildGeneralTab(BuildContext context, dynamic settings, dynamic notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Cấu hình chung (General)', 'Thiết lập ngôn ngữ, giao diện và khởi động cùng hệ điều hành.'),
        const SizedBox(height: 20),

        _buildCard(
          child: Column(
            children: [
              ListTile(
                title: const Text('Ngôn ngữ giao diện (Language)'),
                subtitle: const Text('Lựa chọn ngôn ngữ hiển thị cho các màn hình và menu'),
                trailing: DropdownButton<String>(
                  value: settings.language,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt (Mặc định)')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.updateLanguage(val);
                  },
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Giao diện (Theme Mode)'),
                subtitle: const Text('Chế độ tối (Dark Mode) hoặc sáng (Light Mode)'),
                trailing: DropdownButton<String>(
                  value: settings.themeMode,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'dark', child: Text('Tối (Slate Dark)')),
                    DropdownMenuItem(value: 'light', child: Text('Sáng (Clean Light)')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.updateTheme(val);
                  },
                ),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Tự động khởi động cùng Windows'),
                subtitle: const Text('Chạy ẩn thanh taskbar để sẵn sàng thao tác khi khởi động máy tính'),
                value: settings.autoStartWithWindows,
                onChanged: (val) => notifier.updateAutoStart(val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 1.5. Fonts & Language Tab
  Widget _buildFontsAndLanguageTab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Gói ngôn ngữ Tiếng Việt & Font chữ Giáo dục',
          'Kiểm tra font chữ quy chuẩn Bộ GD&ĐT (Times New Roman, font Tiểu học HP001) và công cụ sửa lỗi font chữ cổ (.VNTime / TCVN3 / VNI).',
        ),
        const SizedBox(height: 20),

        // Section 1: Font Check
        _buildCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.font_download_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Font chữ phục vụ Giáo án & Giảng dạy',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _loadSystemFonts,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Quét lại font'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (Platform.isWindows) {
                              Process.run('explorer.exe', ['C:\\Windows\\Fonts']);
                            }
                          },
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: const Text('Mở thư mục Fonts'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Hệ thống tự động phát hiện các font chữ quy chuẩn theo Nghị định 30/2020/NĐ-CP và font chữ viết tay ô ly Tiểu học (HP001):',
                  style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                ),
                const SizedBox(height: 16),
                if (_isLoadingFonts)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                else if (_installedFonts != null)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _installedFonts!.entries.map((entry) {
                      final isInstalled = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isInstalled
                              ? AppColors.success.withOpacity(0.08)
                              : AppColors.warning.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isInstalled
                                ? AppColors.success.withOpacity(0.3)
                                : AppColors.warning.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isInstalled ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                              color: isInstalled ? AppColors.success : AppColors.warning,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entry.key,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isInstalled ? 'Khả dụng' : 'Chưa có',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isInstalled ? AppColors.success : AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Section 2: Legacy font encoding fixer (.VNTime / TCVN3 / VNI -> Unicode UTF-8)
        _buildSectionHeader(
          'Công cụ sửa lỗi Font chữ cũ (.VNTime / TCVN3 / VNI)',
          'Khắc phục tình trạng văn bản giáo án, đề thi cũ bị biến dạng ô vuông hoặc ký tự lạ khi mở trên máy tính hiện đại.',
        ),
        const SizedBox(height: 16),

        _buildCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Dán văn bản bị lỗi font vào đây:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _legacyTextController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Dán đoạn văn bản bị lỗi font (ví dụ: bµi häc, gi¸o ¸n, trn...) vào đây...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final input = _legacyTextController.text;
                        if (input.isEmpty) return;
                        final converted = VietnameseFontService.autoFixVietnameseEncoding(input);
                        setState(() {
                          _convertedTextController.text = converted;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã giải mã sang Tiếng Việt chuẩn Unicode UTF-8!'),
                            backgroundColor: AppColors.success,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.spellcheck_rounded, size: 18),
                      label: const Text('Chuyển mã sang Unicode UTF-8 chuẩn'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {
                        _legacyTextController.clear();
                        _convertedTextController.clear();
                        setState(() {});
                      },
                      child: const Text('Xóa nội dung'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '2. Kết quả sau khi chuyển đổi chuẩn Unicode:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _convertedTextController,
                  maxLines: 4,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Kết quả hiển thị tại đây...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                    fillColor: isDark ? const Color(0xFF161F30) : const Color(0xFFFBFBFB),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (_convertedTextController.text.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: _convertedTextController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã sao chép kết quả vào Clipboard!')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Sao chép kết quả chuẩn'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Section 3: Quản lý Gói giọng đọc & Ngôn ngữ (Voice & Language Packs)
        _buildSectionHeader(
          'Quản lý Gói giọng đọc & Ngôn ngữ (Voice & Language Packs)',
          'Cung cấp các gói giọng đọc tự nhiên chuẩn tiếng Việt không phụ thuộc vào ngôn ngữ hiển thị của Windows.',
        ),
        const SizedBox(height: 16),

        _buildCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gói 1: AI Tiếng Việt Tự nhiên
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.withOpacity(0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.tealAccent, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Gói giọng AI Tiếng Việt (Hoài My & Nam Minh)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Sẵn sàng (Tích hợp)',
                                    style: TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Được tích hợp sẵn trong Nguyen Du Tool. Hoạt động trơn tru 100% trên mọi máy tính, kể cả máy cài Windows tiếng Anh (en-US). Phát âm chuẩn giáo dục, đọc tự nhiên, diễn cảm, hỗ trợ đọc số và công thức.',
                              style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Gói 2: Windows Offline SAPI
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _hasWindowsViVoice
                        ? AppColors.success.withOpacity(0.08)
                        : Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _hasWindowsViVoice
                          ? AppColors.success.withOpacity(0.35)
                          : Colors.amber.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _hasWindowsViVoice ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        color: _hasWindowsViVoice ? AppColors.success : Colors.amber,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Gói giọng đọc Ngoại tuyến Windows (Microsoft An - Tiếng Việt)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (_hasWindowsViVoice ? AppColors.success : Colors.amber).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _hasWindowsViVoice ? 'Đã cài đặt' : 'Chưa có trên Windows',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _hasWindowsViVoice ? AppColors.success : Colors.amber,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Sử dụng động cơ SAPI / OneCore tích hợp của Windows cho các nhu cầu đọc hoàn toàn Offline không có kết nối mạng.',
                              style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    if (Platform.isWindows) {
                                      Process.run('cmd.exe', ['/c', 'start', 'ms-settings:speech']);
                                    }
                                  },
                                  icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                                  label: const Text('Mở Cài đặt Windows để tải Gói Tiếng Việt (1-Click)'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _isCheckingVoice ? null : _checkWindowsViVoice,
                                  icon: _isCheckingVoice
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Kiểm tra lại'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 2. Storage Tab
  Widget _buildStorageTab(BuildContext context, WorkspaceManager workspace) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Thư mục làm việc & Lưu trữ (Storage)', 'Quản trị đường dẫn workspace, thư mục xuất và tệp tạm.'),
        const SizedBox(height: 20),

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: const Text('Đường dẫn Workspace hiện tại'),
                subtitle: SelectableText(
                  workspace.rootPath,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryLight),
                ),
                trailing: ElevatedButton.icon(
                  onPressed: () => WorkspaceManager.openFolder(workspace.rootPath),
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text('Mở Workspace'),
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Thư mục xuất kết quả (Exports)'),
                subtitle: Text(workspace.exportsDir.path),
                trailing: OutlinedButton.icon(
                  onPressed: () => WorkspaceManager.openFolder(workspace.exportsDir.path),
                  icon: const Icon(Icons.output_rounded, size: 16),
                  label: const Text('Mở Exports'),
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Dọn dẹp tệp tạm thời (Temp & Cache)'),
                subtitle: const Text('Giải phóng dung lượng đĩa cứng bằng cách xóa các tệp xử lý tạm.'),
                trailing: OutlinedButton.icon(
                  onPressed: () async {
                    final count = await workspace.clearTempFiles();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã dọn dẹp $count tệp tạm thời thành công!')),
                      );
                    }
                  },
                  icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                  label: const Text('Dọn dẹp Temp'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 3. AI Providers Tab (Requirement 8)
  Widget _buildProvidersTab(BuildContext context, dynamic providerRegistry) {
    final providers = providerRegistry.listProviders();
    final credService = CredentialService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Nhà cung cấp dịch vụ AI & Engine (Providers)',
          'Quản lý các kết nối OCR, giọng đọc TTS và mô hình trí tuệ nhân tạo. Toàn bộ khóa bảo mật được mã hóa bằng Windows DPAPI.',
        ),
        const SizedBox(height: 20),

        _buildGeminiSettingsHeroCard(context, credService),
        const SizedBox(height: 24),

        _buildCard(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: providers.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final BaseProvider p = providers[index];
              final isUnimplemented = p.implementationStatus == ProviderImplementationStatus.notImplemented;
              final isConfigured = p.capabilityState == ProviderCapabilityState.available;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              _buildProviderBadge(
                                p.isLocal ? 'Offline Cục bộ' : 'Cloud API',
                                p.isLocal ? AppColors.success : AppColors.info,
                              ),
                              _buildProviderBadge(
                                p.implementationStatus.label,
                                isUnimplemented ? AppColors.warning : AppColors.primary,
                              ),
                              _buildProviderBadge(
                                p.capabilityState.label,
                                p.capabilityState == ProviderCapabilityState.available
                                    ? AppColors.success
                                    : (p.capabilityState == ProviderCapabilityState.notConfigured
                                        ? AppColors.warning
                                        : AppColors.error),
                              ),
                            ],
                          ),
                        ),
                        // Working toggle only for implemented providers
                        if (!isUnimplemented)
                          Switch(
                            value: p.isEnabled,
                            onChanged: (val) {
                              setState(() {
                                if (val) {
                                  try {
                                    providerRegistry.enableProvider(p.id);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Không thể bật: $e')),
                                    );
                                  }
                                } else {
                                  providerRegistry.disableProvider(p.id);
                                }
                              });
                            },
                          )
                        else
                          const Tooltip(
                            message: 'Chưa được tích hợp trong phiên bản này',
                            child: Switch(
                              value: false,
                              onChanged: null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isUnimplemented
                          ? '${p.description} (Chưa được cấu hình / Chưa hỗ trợ)'
                          : p.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isUnimplemented
                            ? AppColors.warning.withOpacity(0.9)
                            : (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                      ),
                    ),
                    // Action controls for configurable cloud providers
                    if (!p.isLocal && !isUnimplemented) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            icon: const Icon(Icons.vpn_key_rounded, size: 14),
                            label: Text(isConfigured ? 'Cập nhật khóa' : 'Cấu hình khóa (DPAPI)'),
                            onPressed: () => _showConfigureDialog(context, p, credService),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            icon: const Icon(Icons.network_check_rounded, size: 14),
                            label: const Text('Kiểm tra kết nối'),
                            onPressed: () => _testProviderConnection(context, p),
                          ),
                          if (isConfigured) ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 14),
                              label: const Text('Xóa khóa'),
                              onPressed: () => _removeProviderCredentials(context, p, credService),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProviderBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Future<void> _showConfigureDialog(BuildContext context, BaseProvider provider, CredentialService creds) async {
    final isGoogle = provider.id == 'google_tts';
    final keyController = TextEditingController();
    final regionController = TextEditingController(text: 'southeastasia');

    if (isGoogle) {
      final existing = await creds.getGoogleTtsApiKey();
      if (existing != null) keyController.text = existing;
    } else {
      final existingKey = await creds.getAzureSpeechKey();
      final existingRegion = await creds.getAzureSpeechRegion();
      if (existingKey != null) keyController.text = existingKey;
      if (existingRegion != null) regionController.text = existingRegion;
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cấu hình ${provider.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Khóa API sẽ được mã hóa an toàn bằng Windows DPAPI (CurrentUser) '
              'và không lưu trữ plaintext trên đĩa hoặc trong cơ sở dữ liệu SQLite.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: isGoogle ? 'Google Cloud API Key' : 'Azure Subscription Key',
                hintText: isGoogle ? 'AIzaSy...' : 'Nhập khóa 32 ký tự...',
                border: const OutlineInputBorder(),
              ),
            ),
            if (!isGoogle) ...[
              const SizedBox(height: 12),
              TextField(
                controller: regionController,
                decoration: const InputDecoration(
                  labelText: 'Azure Region',
                  hintText: 'southeastasia, eastasia, ...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final key = keyController.text.trim();
              if (isGoogle) {
                await creds.setGoogleTtsApiKey(key);
                if (provider is GoogleTtsProvider) await provider.reloadCredentials();
              } else {
                await creds.setAzureSpeechCredentials(key: key, region: regionController.text.trim());
                if (provider is AzureTtsProvider) await provider.reloadCredentials();
              }
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã mã hóa và lưu khóa vào Windows DPAPI thành công!')),
                );
              }
            },
            child: const Text('Lưu bảo mật'),
          ),
        ],
      ),
    );
  }

  Future<void> _testProviderConnection(BuildContext context, BaseProvider provider) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đang kiểm tra kết nối tới ${provider.name}...')),
    );
    final ok = await provider.checkHealth();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? AppColors.success : AppColors.error,
        content: Text(ok
            ? 'Kết nối thành công tới ${provider.name}!'
            : 'Kiểm tra kết nối thất bại. Vui lòng kiểm tra khóa API và mạng internet.'),
      ),
    );
    setState(() {});
  }

  Future<void> _removeProviderCredentials(BuildContext context, BaseProvider provider, CredentialService creds) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa khóa bí mật?'),
        content: Text('Khóa truy cập của ${provider.name} sẽ bị xóa khỏi kho lưu trữ DPAPI.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa khóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (provider.id == 'google_tts') {
        await creds.removeGoogleTtsApiKey();
        if (provider is GoogleTtsProvider) await provider.reloadCredentials();
      } else if (provider.id == 'azure_tts') {
        await creds.removeAzureSpeechCredentials();
        if (provider is AzureTtsProvider) await provider.reloadCredentials();
      }
      provider.isEnabled = false;
      setState(() {});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa khóa khỏi kho bảo mật DPAPI.')),
        );
      }
    }
  }

  Widget _buildGeminiSettingsHeroCard(BuildContext context, CredentialService credService) {
    return FutureBuilder<String?>(
      future: credService.getGeminiApiKey(),
      builder: (context, snapshot) {
        final key = snapshot.data;
        final hasKey = key != null && key.trim().isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: hasKey
                  ? [
                      AppColors.primary.withOpacity(0.15),
                      const Color(0xFF10B981).withOpacity(0.08),
                    ]
                  : [
                      const Color(0xFFF59E0B).withOpacity(0.12),
                      AppColors.darkSurfaceElevated.withOpacity(0.4),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasKey
                  ? AppColors.primary.withOpacity(0.4)
                  : const Color(0xFFF59E0B).withOpacity(0.4),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: hasKey
                            ? [const Color(0xFF6366F1), const Color(0xFF3B82F6)]
                            : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (hasKey ? const Color(0xFF6366F1) : const Color(0xFFF59E0B)).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            const Text(
                              'Google Gemini AI Hub',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: hasKey ? AppColors.success.withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: hasKey ? AppColors.success : const Color(0xFFF59E0B),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasKey ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                    size: 13,
                                    color: hasKey ? AppColors.success : const Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasKey ? 'Đang hoạt động' : 'Chưa gắn API Key',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: hasKey ? AppColors.success : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasKey
                              ? 'Trợ lý AI đa phương thức: Bóc băng Audio/Video thành văn bản, tóm tắt bài giảng sư phạm và dịch thuật chuyên sâu.'
                              : 'Gắn API Key miễn phí từ Google để mở khóa tính năng Bóc băng bài giảng Audio/Video, tóm tắt sư phạm và nhận dạng giọng nói.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade400, height: 1.4),
                        ),
                        if (hasKey) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.darkBackground.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.vpn_key_rounded, size: 14, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Mã khóa: ${key.length > 8 ? "${key.substring(0, 7)}...${key.substring(key.length - 4)}" : "******"} (Mã hóa Windows DPAPI an toàn)',
                                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Colors.white10),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Text(
                    'Miễn phí tại Google AI Studio • Tương thích multimodal âm thanh & video',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hasKey) ...[
                        OutlinedButton.icon(
                          onPressed: () => _testGeminiConnection(context, key),
                          icon: const Icon(Icons.network_check_rounded, size: 16),
                          label: const Text('Kiểm tra kết nối'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _removeGeminiKey(context, credService),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                          label: const Text('Xóa khóa', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                      FilledButton.icon(
                        onPressed: () => _showGeminiDialog(context, credService, existingKey: key),
                        icon: Icon(hasKey ? Icons.edit_rounded : Icons.key_rounded, size: 16),
                        label: Text(hasKey ? 'Đổi API Key' : 'Gán Google Gemini API'),
                        style: FilledButton.styleFrom(
                          backgroundColor: hasKey ? AppColors.primary : const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showGeminiDialog(BuildContext context, CredentialService creds, {String? existingKey}) async {
    final keyController = TextEditingController(text: existingKey ?? '');
    bool isTesting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Cấu hình Google Gemini API'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Khóa API sẽ được mã hóa an toàn bằng Windows DPAPI (CurrentUser) '
                  'trực tiếp trên máy tính của thầy cô, không lưu plaintext và không gửi ra ngoài.',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: keyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Google Gemini API Key',
                    hintText: 'AIzaSy...',
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_rounded),
                      tooltip: 'Dán từ clipboard',
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          keyController.text = data!.text!.trim();
                          setDialogState(() {});
                        }
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '💡 Thầy cô có thể lấy khóa API hoàn toàn miễn phí tại Google AI Studio (aistudio.google.com).',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                ),
                if (isTesting) ...[
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Đang kiểm tra kết nối với máy chủ Google...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isTesting ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: isTesting
                  ? null
                  : () async {
                      final inputKey = keyController.text.trim();
                      if (inputKey.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập API Key.')),
                        );
                        return;
                      }

                      setDialogState(() => isTesting = true);
                      final isValid = await GeminiService.validateKey(inputKey);
                      setDialogState(() => isTesting = false);

                      if (isValid) {
                        await creds.setGeminiApiKey(inputKey);
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() {});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.success,
                              content: Text('Đã kết nối và lưu Google Gemini API Key an toàn vào Windows DPAPI!'),
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.error,
                              content: Text('API Key không hợp lệ hoặc không có kết nối mạng. Vui lòng kiểm tra lại.'),
                            ),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Kiểm tra & Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testGeminiConnection(BuildContext context, String key) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang kiểm tra kết nối Google Gemini API...')),
    );
    final ok = await GeminiService.validateKey(key);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? AppColors.success : AppColors.error,
        content: Text(ok
            ? 'Kết nối thành công! Google Gemini AI đã sẵn sàng hoạt động.'
            : 'Kiểm tra thất bại. Vui lòng kiểm tra lại khóa API hoặc kết nối Internet.'),
      ),
    );
  }

  Future<void> _removeGeminiKey(BuildContext context, CredentialService creds) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa Google Gemini API Key?'),
        content: const Text(
          'Khóa Google Gemini API sẽ bị xóa khỏi kho bảo mật DPAPI của máy tính. '
          'Các tính năng Bóc băng bài giảng Audio/Video sẽ không thể hoạt động cho đến khi thầy cô gán lại khóa mới.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa khóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await creds.removeGeminiApiKey();
      setState(() {});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa Google Gemini API Key khỏi kho bảo mật.')),
        );
      }
    }
  }

  // 4. Advanced Tab
  Widget _buildAdvancedTab(BuildContext context, dynamic settings, dynamic notifier, WorkspaceManager workspace) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Nâng cao & Bảo trì (Advanced)', 'Nhật ký lỗi hệ thống, chế độ phát triển và quản trị cấu hình.'),
        const SizedBox(height: 20),

        _buildCard(
          child: Column(
            children: [
              ListTile(
                title: const Text('Thư mục nhật ký (Application Logs)'),
                subtitle: Text(workspace.logsDir.path),
                trailing: OutlinedButton.icon(
                  onPressed: () => WorkspaceManager.openFolder(workspace.logsDir.path),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('Mở Logs'),
                ),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Chế độ nhà phát triển (Developer Mode)'),
                subtitle: const Text('Hiển thị thông tin kiểm thử chi tiết và giao diện SQLite debug'),
                value: settings.developerMode,
                onChanged: (val) => notifier.updateDeveloperMode(val),
              ),
              const Divider(),
              ListTile(
                title: const Text('Đặt lại cấu hình cài đặt (Reset Settings)'),
                subtitle: const Text('Khôi phục giao diện, ngôn ngữ về mặc định. Giữ nguyên toàn bộ tệp tài liệu và cơ sở dữ liệu.'),
                trailing: OutlinedButton.icon(
                  onPressed: () async {
                    await notifier.resetToDefaults();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã khôi phục cài đặt ứng dụng về mặc định.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.settings_backup_restore_rounded, size: 16),
                  label: const Text('Đặt lại cấu hình'),
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Khôi phục cài đặt gốc (Factory Reset)'),
                subtitle: const Text('Đưa phần mềm về trạng thái ban đầu sau khi cài đặt. Yêu cầu xác nhận.'),
                trailing: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: () => _confirmFactoryReset(context, notifier),
                  icon: const Icon(Icons.warning_amber_rounded, size: 16),
                  label: const Text('Khôi phục gốc'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmFactoryReset(BuildContext context, dynamic notifier) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Xác nhận khôi phục cài đặt gốc'),
          ],
        ),
        content: const Text(
          'Hành động này sẽ xóa toàn bộ tùy chọn cá nhân và đưa các thiết lập về mặc định.\n\n'
          'CHÚ Ý: Tất cả tài liệu của bạn (PDF, Word, Excel, âm thanh, video) trong thư mục cá nhân Documents/NguyenDu Tool ĐƯỢC BẢO TOÀN NGUYÊN VẸN, không bị xóa.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy bỏ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await notifier.resetToDefaults();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã hoàn tất khôi phục cài đặt gốc!')),
                );
              }
            },
            child: const Text('Xác nhận khôi phục'),
          ),
        ],
      ),
    );
  }

  // 5. About Tab
  Widget _buildAboutTab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Thông tin phần mềm (About)', 'Tổng quan phiên bản, giấy phép và kiến trúc nền tảng.'),
        const SizedBox(height: 20),

        _buildCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/images/ibest_logo.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('NguyenDu Tool', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              SizedBox(width: 8),
                              Text('by iBest Group', style: TextStyle(fontSize: 13, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text('Nền tảng trợ lý giáo viên & số hóa trường học — iBest Group (ibestgroup.vn)', style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                _buildInfoRow('Phiên bản (Version)', '${ProductInfo.version} (Build ${ProductInfo.build}) • ${ProductInfo.currentPhase}'),
                _buildInfoRow('Kiến trúc (Architecture)', 'Modular Clean Architecture (Flutter Desktop Windows x64)'),
                _buildInfoRow('Cơ sở dữ liệu (Database)', 'SQLite FFI Cục bộ (Local-First Schema v${ProductInfo.schemaVersion})'),
                _buildInfoRow('Động cơ Video (Engine)', 'FFmpeg ${ProductInfo.ffmpegVersion} Tích hợp (bin/ffmpeg.exe)'),
                _buildInfoRow('Bảo mật dữ liệu nhạy cảm', 'Windows DPAPI (CurrentUser Scope)'),
                _buildInfoRow('Trạng thái (Phase Status)', ProductInfo.currentPhase),
                _buildInfoRow('Nhà phát triển (Publisher)', '${ProductInfo.publisher} (${ProductInfo.publisherWebsite})'),
                _buildInfoRow('Kênh cập nhật (GitHub)', ProductInfo.repositoryUrl),
                const SizedBox(height: 16),

                // Author & Free Software Philosophy Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E283D), const Color(0xFF172033)]
                          : [const Color(0xFFF0F4FF), const Color(0xFFE8EEFA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite_rounded, color: Color(0xFFE91E63), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Phần mềm Giáo dục Miễn phí 100% — Nhận viết tool & nâng cấp theo yêu cầu',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => SupportAuthorDialog.show(context),
                            icon: const Icon(Icons.contact_support_rounded, size: 15, color: Colors.white),
                            label: const Text('Vui lòng liên hệ'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9800),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Phần mềm được phát triển phi lợi nhuận dành tặng quý Thầy/Cô và các Nhà trường. Đội ngũ sẵn sàng tư vấn, nâng cấp chức năng hoặc lập trình phần mềm/công cụ riêng biệt theo yêu cầu của Thầy/Cô.',
                        style: TextStyle(fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (Platform.isWindows) {
                                Process.run('cmd.exe', ['/c', 'start', 'https://zalo.me/0917764111']);
                              }
                            },
                            child: const Row(
                              children: [
                                Icon(Icons.phone_android_rounded, size: 14, color: Colors.blueAccent),
                                SizedBox(width: 4),
                                Text(
                                  'Hotline / Zalo: 0917.764.111',
                                  style: TextStyle(fontSize: 12.5, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          InkWell(
                            onTap: () {
                              if (Platform.isWindows) {
                                Process.run('cmd.exe', ['/c', 'start', 'https://ibestgroup.vn']);
                              }
                            },
                            child: const Row(
                              children: [
                                Icon(Icons.public_rounded, size: 14, color: Colors.tealAccent),
                                SizedBox(width: 4),
                                Text(
                                  'Website: ibestgroup.vn',
                                  style: TextStyle(fontSize: 12.5, color: Colors.tealAccent, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Auto-Update Section Card
                Consumer(
                  builder: (context, ref, _) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final updateState = ref.watch(updateNotifierProvider);
                    final notifier = ref.read(updateNotifierProvider.notifier);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: updateState.isAvailable
                              ? AppColors.primary
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                updateState.isAvailable
                                    ? Icons.system_update_rounded
                                    : Icons.cloud_sync_outlined,
                                color: updateState.isAvailable ? AppColors.primaryLight : null,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Cập nhật phần mềm (Auto-Update)',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              if (updateState.status == UpdateStatus.checking)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else if (updateState.status == UpdateStatus.upToDate)
                                const Row(
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 16),
                                    SizedBox(width: 6),
                                    Text('Bản mới nhất', style: TextStyle(fontSize: 12, color: AppColors.success)),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            updateState.isAvailable
                                ? 'Phát hiện bản cập nhật mới v${updateState.manifest!.version}! Bạn có thể cập nhật ngay bây giờ.'
                                : 'Ứng dụng tự động kết nối máy chủ GitHub để thông báo khi có tính năng mới.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: updateState.status == UpdateStatus.checking || updateState.isDownloading
                                    ? null
                                    : () {
                                        if (updateState.isAvailable) {
                                          UpdateDialog.show(context);
                                        } else {
                                          notifier.checkForUpdates(silent: false);
                                        }
                                      },
                                icon: Icon(
                                  updateState.isAvailable ? Icons.upgrade_rounded : Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  updateState.isAvailable
                                      ? 'Cập nhật lên v${updateState.manifest!.version}'
                                      : (updateState.status == UpdateStatus.checking
                                          ? 'Đang kiểm tra...'
                                          : 'Kiểm tra cập nhật ngay'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _selectedTabIndex = 5),
                      icon: const Icon(Icons.health_and_safety_rounded, size: 16),
                      label: const Text('Mở Chẩn đoán Hệ thống'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.firstRun),
                      icon: const Icon(Icons.help_outline_rounded, size: 16),
                      label: const Text('Xem hướng dẫn ban đầu (Wizard)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.darkTextSecondary)),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: child,
    );
  }
}
