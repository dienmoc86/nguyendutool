import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/product/product_info.dart';

void main() {
  group('ProductInfo & Version Consistency Tests (Phase 7)', () {
    test('ProductInfo properties are well-formed and non-empty', () {
      expect(ProductInfo.productName, equals('NguyenDu Tool'));
      expect(ProductInfo.version, equals('1.7.3'));
      expect(ProductInfo.build, equals(15));
      expect(ProductInfo.versionString, equals('1.7.3+15'));
      expect(ProductInfo.schemaVersion, equals(9));
      expect(ProductInfo.releaseChannel, equals('stable'));
      expect(ProductInfo.currentPhase, contains('Phase 7R'));
      expect(ProductInfo.publisher, equals('iBest Group'));
    });

    test('pubspec.yaml matches ProductInfo version', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue, reason: 'pubspec.yaml must exist');
      final content = pubspecFile.readAsStringSync();
      final versionMatch = RegExp(r'^version:\s*([^\s]+)', multiLine: true).firstMatch(content);
      expect(versionMatch, isNotNull, reason: 'version field must exist in pubspec.yaml');
      final pubspecVersion = versionMatch!.group(1)!.trim();
      expect(pubspecVersion, equals(ProductInfo.versionString),
          reason: 'pubspec.yaml version ($pubspecVersion) must equal ProductInfo ($ProductInfo.versionString)');
    });

    test('VERSION.json matches ProductInfo metadata', () {
      final versionJsonFile = File('VERSION.json');
      expect(versionJsonFile.existsSync(), isTrue, reason: 'VERSION.json must exist');
      final data = jsonDecode(versionJsonFile.readAsStringSync()) as Map<String, dynamic>;

      expect(data['version'], equals(ProductInfo.version),
          reason: 'VERSION.json version must equal ProductInfo.version');
      expect(data['build'], equals(ProductInfo.build),
          reason: 'VERSION.json build must equal ProductInfo.build');
      expect(data['databaseSchema'], equals(ProductInfo.schemaVersion),
          reason: 'VERSION.json databaseSchema must equal ProductInfo.schemaVersion');
    });

    test('Windows Runner.rc declares matching version strings', () {
      final rcFile = File('windows/runner/Runner.rc');
      expect(rcFile.existsSync(), isTrue, reason: 'Runner.rc must exist');
      final rcContent = rcFile.readAsStringSync();

      expect(rcContent.contains('VERSION_AS_NUMBER 1,7,3,15'), isTrue,
          reason: 'Runner.rc must define VERSION_AS_NUMBER 1,7,3,15');
      expect(rcContent.contains('"1.7.3+15"'), isTrue,
          reason: 'Runner.rc must define VERSION_AS_STRING "1.7.3+15"');
      expect(rcContent.contains('"FileVersion", "1.7.3.15"'), isTrue,
          reason: 'Runner.rc must define FileVersion 1.7.3.15');
      expect(rcContent.contains('"ProductVersion", "1.7.3"'), isTrue,
          reason: 'Runner.rc must define ProductVersion 1.7.3');
    });

    test('Inno Setup setup.iss matches ProductInfo version', () {
      final issFile = File('installer/setup.iss');
      expect(issFile.existsSync(), isTrue, reason: 'setup.iss must exist');
      final issContent = issFile.readAsStringSync();

      expect(issContent.contains('#define MyAppVersion "1.7.3"'), isTrue,
          reason: 'setup.iss must define MyAppVersion 1.7.3');
      expect(issContent.contains('VersionInfoVersion=1.7.3.15'), isTrue,
          reason: 'setup.iss must define VersionInfoVersion 1.7.3.15');
      expect(issContent.contains('VersionInfoProductVersion=1.7.3'), isTrue,
          reason: 'setup.iss must define VersionInfoProductVersion 1.7.3');
    });
  });
}
