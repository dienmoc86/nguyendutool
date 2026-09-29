import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/models/video_template.dart';
import '../../application/video_studio_providers.dart';

/// Left panel for managing project scenes, templates, and imported media assets.
class VideoLeftPanel extends ConsumerStatefulWidget {
  const VideoLeftPanel({super.key});

  @override
  ConsumerState<VideoLeftPanel> createState() => _VideoLeftPanelState();
}

class _VideoLeftPanelState extends ConsumerState<VideoLeftPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoStudioNotifierProvider);
    final notifier = ref.read(videoStudioNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: Column(
        children: [
          // Tab Header: Phân cảnh / Mẫu dự án
          TabBar(
            controller: _tabController,
            labelColor: AppColors.moduleVideo,
            unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
            indicatorColor: AppColors.moduleVideo,
            tabs: const [
              Tab(icon: Icon(Icons.view_carousel_rounded, size: 18), text: 'Phân cảnh'),
              Tab(icon: Icon(Icons.dashboard_customize_rounded, size: 18), text: 'Mẫu thiết kế'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Scenes List
                Column(
                  children: [
                    // Add scene button
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => notifier.addScene(),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Thêm phân cảnh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.moduleVideo.withOpacity(0.12),
                            foregroundColor: AppColors.moduleVideo,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),

                    // Scenes Reorderable List
                    Expanded(
                      child: state.currentProject.scenes.isEmpty
                          ? const Center(child: Text('Chưa có cảnh nào.'))
                          : ReorderableListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              itemCount: state.currentProject.scenes.length,
                              onReorder: (oldIndex, newIndex) {
                                notifier.reorderScenes(oldIndex, newIndex);
                              },
                              itemBuilder: (context, index) {
                                final scene = state.currentProject.scenes[index];
                                final isSelected = index == state.selectedSceneIndex;

                                return Container(
                                  key: ValueKey(scene.id),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.moduleVideo.withOpacity(0.15)
                                        : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.moduleVideo
                                          : (isDark ? Colors.white12 : Colors.black12),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    onTap: () => notifier.selectScene(index),
                                    leading: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: isSelected ? AppColors.moduleVideo : Colors.grey.shade400,
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(
                                      scene.title?.isNotEmpty == true ? scene.title! : 'Cảnh ${index + 1}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${scene.durationSeconds.toStringAsFixed(1)}s • ${scene.transition.type.displayName.split(' ').first}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white54 : Colors.black45,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (scene.hasVoiceover)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Icon(Icons.mic_rounded, size: 14, color: Colors.green),
                                          ),
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.more_vert_rounded, size: 16),
                                          onSelected: (action) {
                                            if (action == 'duplicate') {
                                              notifier.duplicateScene(index);
                                            } else if (action == 'delete') {
                                              notifier.deleteScene(index);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'duplicate',
                                              child: Text('Nhân bản cảnh'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Xóa cảnh', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),

                // Tab 2: Project Templates
                ListView(
                  padding: const EdgeInsets.all(12),
                  children: VideoTemplate.builtInTemplates.map((template) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.video_collection_outlined, color: AppColors.moduleVideo, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    template.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              template.type.description,
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  notifier.newProject(
                                    templateType: template.type,
                                    name: template.name,
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text('Áp dụng mẫu này', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
