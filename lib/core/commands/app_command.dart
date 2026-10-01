import 'package:flutter/widgets.dart';

/// Represents a runnable command in the global Command Palette / Launcher.
class AppCommand {
  final String id;
  final String title;
  final String? subtitle;
  final List<String> keywords;
  final IconData icon;
  final String category;
  final Future<void> Function(BuildContext context) execute;

  const AppCommand({
    required this.id,
    required this.title,
    this.subtitle,
    this.keywords = const [],
    required this.icon,
    required this.category,
    required this.execute,
  });

  /// Check if the query matches the command title, subtitle, or keywords
  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    final normalizedQuery = _normalize(query);
    if (_normalize(title).contains(normalizedQuery)) return true;
    if (subtitle != null && _normalize(subtitle!).contains(normalizedQuery)) return true;
    if (_normalize(category).contains(normalizedQuery)) return true;
    for (final kw in keywords) {
      if (_normalize(kw).contains(normalizedQuery)) return true;
    }
    return false;
  }

  static String _normalize(String input) {
    return input.toLowerCase().trim();
  }
}
