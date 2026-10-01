/// Authoritative product information and single source of truth for NguyenDu Tool.
///
/// All UI screens, diagnostics, about dialogues, and automated consistency tests
/// reference this class rather than hardcoding version strings independently.
class ProductInfo {
  ProductInfo._();

  static const String productName = 'NguyenDu Tool';
  static const String productDescription =
      'Bàn làm việc số & Trợ lý chuyên môn toàn diện cho Giáo viên và Nhà trường';
  static const String version = '1.7.3';
  static const int build = 15;
  static const String versionString = '$version+$build';

  static const int schemaVersion = 9;
  static const String releaseChannel = 'stable';
  static const String currentPhase =
      'Phase 7R.3 - Complete Parent-Child Data Integrity Hardening';

  static const String publisher = 'iBest Group';
  static const String publisherWebsite = 'https://ibestgroup.vn';
  static const String supportHotline = '0917.764.111';
  static const String authorName = 'Mr. Điện (Nguyễn Khắc Điện)';
  static const String repositoryUrl = 'https://github.com/dienmoc86/nguyendutool';
  static const String architecture = 'windows-x64';
  static const String minimumWindowsVersion = 'Windows 10 (19041+) / Windows 11 (x64)';
  static const String ffmpegVersion = '8.0.1';

  static const String copyright = 'Copyright © 2026 iBest Group. Tất cả quyền được bảo lưu.';

  /// Returns full display title including version
  static String get fullDisplayTitle => '$productName v$version (Build $build)';

  /// Returns user-friendly summary of the product
  static Map<String, dynamic> toMap() => {
        'productName': productName,
        'version': version,
        'build': build,
        'versionString': versionString,
        'schemaVersion': schemaVersion,
        'releaseChannel': releaseChannel,
        'currentPhase': currentPhase,
        'publisher': publisher,
        'website': publisherWebsite,
        'author': authorName,
        'hotline': supportHotline,
        'repository': repositoryUrl,
        'architecture': architecture,
      };
}
