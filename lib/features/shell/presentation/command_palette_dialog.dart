import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/commands/app_command.dart';
import '../../../core/commands/command_registry.dart';

/// Modal dialog providing instant command search and utility launching (Ctrl+K).
class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({super.key});

  /// Helper to display the dialog
  static Future<void> show(BuildContext context) async {
    CommandRegistry.instance.initializeDefaults();
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => const CommandPaletteDialog(),
    );
  }

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<AppCommand> _filteredCommands = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _filteredCommands = CommandRegistry.instance.allCommands;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _filteredCommands = CommandRegistry.instance.search(query);
      _selectedIndex = 0;
    });
  }

  void _executeSelected() {
    if (_filteredCommands.isNotEmpty && _selectedIndex >= 0 && _selectedIndex < _filteredCommands.length) {
      final cmd = _filteredCommands[_selectedIndex];
      Navigator.of(context).pop();
      cmd.execute(context);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_filteredCommands.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _filteredCommands.length;
        });
        _scrollToSelected();
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_filteredCommands.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1 + _filteredCommands.length) % _filteredCommands.length;
        });
        _scrollToSelected();
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _executeSelected();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _scrollToSelected() {
    if (_scrollController.hasClients && _selectedIndex >= 0) {
      const itemHeight = 64.0;
      final targetOffset = _selectedIndex * itemHeight;
      if (targetOffset < _scrollController.offset) {
        _scrollController.jumpTo(targetOffset);
      } else if (targetOffset + itemHeight > _scrollController.offset + 320) {
        _scrollController.jumpTo(targetOffset + itemHeight - 320);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 620,
          constraints: const BoxConstraints(maxHeight: 520),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2430) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF333D4F) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.45 : 0.15),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tìm tác vụ, công cụ, giáo án... (nhập từ khóa)',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white38 : AppColors.lightTextMuted,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () {
                            _searchController.clear();
                          },
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          'ESC',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? const Color(0xFF333D4F) : const Color(0xFFE2E8F0),
                ),

                // Results list
                Flexible(
                  child: _filteredCommands.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: isDark ? Colors.white38 : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Không tìm thấy kết quả phù hợp',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Thử tìm với từ khóa khác như "pdf", "scan", "giáo án", "video", "tts"...',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white38 : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          itemCount: _filteredCommands.length,
                          itemBuilder: (context, index) {
                            final cmd = _filteredCommands[index];
                            final isSelected = index == _selectedIndex;

                            return InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                cmd.execute(context);
                              },
                              onHover: (hovering) {
                                if (hovering && _selectedIndex != index) {
                                  setState(() {
                                    _selectedIndex = index;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark
                                          ? AppColors.primary.withOpacity(0.2)
                                          : AppColors.primary.withOpacity(0.08))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary.withOpacity(0.4)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isDark ? Colors.white10 : Colors.grey.shade100),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        cmd.icon,
                                        size: 20,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark ? Colors.white70 : AppColors.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cmd.title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                          if (cmd.subtitle != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              cmd.subtitle!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.white54 : AppColors.lightTextMuted,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        cmd.category,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Footer with Shortcuts info
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? const Color(0xFF333D4F) : const Color(0xFFE2E8F0),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildKeyHint('↑', 'lên', isDark),
                      const SizedBox(width: 6),
                      _buildKeyHint('↓', 'xuống', isDark),
                      const SizedBox(width: 14),
                      _buildKeyHint('↵', 'chọn', isDark),
                      const Spacer(),
                      Text(
                        'Phím tắt: Ctrl+K',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : AppColors.lightTextMuted,
                        ),
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

  Widget _buildKeyHint(String keyLabel, String action, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            keyLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          action,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }
}
