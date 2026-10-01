// ignore_for_file: avoid_print, prefer_const_declarations
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

void main() {
  final baoCaoDir = Directory('bao_cao');
  if (!baoCaoDir.existsSync()) baoCaoDir.createSync(recursive: true);

  // 1. Package Review ZIP
  final reviewZipPath = 'bao_cao/NguyenDuTool_PHASE6BR_REVIEW_20260930_142000.zip';
  final reviewZipFile = File(reviewZipPath);
  if (reviewZipFile.existsSync()) reviewZipFile.deleteSync();

  final reviewEncoder = ZipFileEncoder();
  reviewEncoder.create(reviewZipPath);
  reviewEncoder.addDirectory(Directory('bao_cao/phase_6br_20260930_142000'));
  reviewEncoder.close();

  final reviewBytes = reviewZipFile.readAsBytesSync();
  final reviewHash = sha256.convert(reviewBytes).toString();

  // 2. Package Source ZIP
  final sourceZipPath = 'bao_cao/NguyenDuTool_PHASE6BR_SOURCE_20260930_142000.zip';
  final sourceZipFile = File(sourceZipPath);
  if (sourceZipFile.existsSync()) sourceZipFile.deleteSync();

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

  print('SOURCE_ZIP: ${File(sourceZipPath).absolute.path}');
  print('SOURCE_SHA256: $sourceHash');
  print('REVIEW_ZIP: ${File(reviewZipPath).absolute.path}');
  print('REVIEW_SHA256: $reviewHash');
}
