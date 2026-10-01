// ignore_for_file: avoid_print, prefer_const_declarations
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

void main() {
  final timestamp = '20260930_160000';
  final baoCaoDir = Directory('bao_cao');
  if (!baoCaoDir.existsSync()) baoCaoDir.createSync(recursive: true);

  // 1. Package Review ZIP
  final reviewZipPath = 'bao_cao/NguyenDuTool_PHASE7_REVIEW_$timestamp.zip';
  final reviewZipFile = File(reviewZipPath);
  if (reviewZipFile.existsSync()) reviewZipFile.deleteSync();

  print('Creating Review ZIP: $reviewZipPath...');
  final reviewEncoder = ZipFileEncoder();
  reviewEncoder.create(reviewZipPath);
  reviewEncoder.addDirectory(Directory('bao_cao/phase_7_$timestamp'));
  reviewEncoder.close();

  final reviewBytes = reviewZipFile.readAsBytesSync();
  final reviewHash = sha256.convert(reviewBytes).toString();

  // 2. Package Source ZIP
  final sourceZipPath = 'bao_cao/NguyenDuTool_PHASE7_SOURCE_$timestamp.zip';
  final sourceZipFile = File(sourceZipPath);
  if (sourceZipFile.existsSync()) sourceZipFile.deleteSync();

  print('Creating Source ZIP: $sourceZipPath...');
  final sourceEncoder = ZipFileEncoder();
  sourceEncoder.create(sourceZipPath);

  sourceEncoder.addDirectory(Directory('lib'));
  sourceEncoder.addDirectory(Directory('test'));

  // Windows folder excluding ephemeral
  for (final entity in Directory('windows').listSync(recursive: true)) {
    if (entity is File) {
      final normPath = entity.path.replaceAll('\\\\', '/');
      if (!normPath.contains('windows/flutter/ephemeral')) {
        sourceEncoder.addFile(entity);
      }
    }
  }

  if (Directory('docs').existsSync()) {
    sourceEncoder.addDirectory(Directory('docs'));
  }
  if (Directory('tool').existsSync()) {
    sourceEncoder.addDirectory(Directory('tool'));
  }

  for (final f in ['README.md', 'VERSION.json', 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml']) {
    final file = File(f);
    if (file.existsSync()) {
      sourceEncoder.addFile(file);
    }
  }

  sourceEncoder.close();

  final sourceBytes = sourceZipFile.readAsBytesSync();
  final sourceHash = sha256.convert(sourceBytes).toString();

  print('');
  print('================ PACKAGING COMPLETE ================');
  print('SOURCE_ZIP: ${File(sourceZipPath).absolute.path}');
  print('SOURCE_SIZE: ${sourceBytes.length} bytes');
  print('SOURCE_SHA256: $sourceHash');
  print('');
  print('REVIEW_ZIP: ${File(reviewZipPath).absolute.path}');
  print('REVIEW_SIZE: ${reviewBytes.length} bytes');
  print('REVIEW_SHA256: $reviewHash');
  print('====================================================');
}
