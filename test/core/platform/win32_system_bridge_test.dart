// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/platform/win32_system_bridge.dart';

void main() {
  group('Win32SystemBridge Tests', () {
    test('Acquire and release single instance named mutex', () {
      if (!Platform.isWindows) return;

      const testMutexName = r'Local\NguyenDuTool_TestMutex_UnitTest';

      // Primary instance acquires
      final firstAcquired = Win32SystemBridge.acquireSingleInstanceMutex(mutexName: testMutexName);
      expect(firstAcquired, isTrue);

      // Second instance attempts to acquire same mutex -> must return false!
      final secondAcquired = Win32SystemBridge.acquireSingleInstanceMutex(mutexName: testMutexName);
      expect(secondAcquired, isFalse, reason: 'Duplicate instance must be rejected!');

      // Release
      Win32SystemBridge.releaseSingleInstanceMutex();
    });

    test('Query disk free space via GetDiskFreeSpaceExW', () {
      if (!Platform.isWindows) return;

      final currentDrive = Directory.current.path;
      final space = Win32SystemBridge.getDiskFreeSpace(currentDrive);

      expect(space, isNotNull);
      expect(space!.freeBytes, greaterThan(0));
      expect(space.totalBytes, greaterThan(0));
      expect(space.freeGb, greaterThan(0.0));
      expect(space.totalGb, greaterThan(0.0));
      print('Disk Free Space on $currentDrive: ${space.freeGb.toStringAsFixed(2)} GB free of ${space.totalGb.toStringAsFixed(2)} GB total');
    });
  });
}
