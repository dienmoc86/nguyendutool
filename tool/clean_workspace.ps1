$itemsToDelete = @(
    'NguyenDuTool_PHASE5R_SOURCE_20260927_175001.zip',
    'NguyenDuTool_PHASE5R_SOURCE_20260927_175001.zip.sha256',
    'NguyenDuTool_PHASE5R_SOURCE_20260927_180303.zip',
    'NguyenDuTool_PHASE5R_SOURCE_20260927_180303.zip.sha256',
    'NguyenDuTool_PHASE5R_REVIEW_20260927_175001.zip',
    'NguyenDuTool_PHASE5R_REVIEW_20260927_175001.zip.sha256',
    'NguyenDuTool_PHASE5R_REVIEW_20260927_180303.zip',
    'NguyenDuTool_PHASE5R_REVIEW_20260927_180303.zip.sha256',
    'PHASE_1R2_PACKAGE_MANIFEST.txt',
    'SELF_TEST_RESULT.json',
    'check_winrt.ps1',
    'inspect_astask.ps1',
    'inspect_render.ps1',
    'gen_tree.dart',
    'package_phase_1.ps1',
    'temp_status.mp3',
    'temp_status.wav',
    'test_img.jpg',
    'test_img_vid.mp4',
    'test_render_and_ocr.ps1',
    'test_rendered_01.png',
    'test_rot_03.png',
    'test_winrt_real.ps1',
    'test_workflow.log',
    'test_xfade.mp4',
    'tts_all.log',
    'nguyendu_tool.db',
    'tools\VietOCR-6.21.0.zip',
    'tool\test_onecore.wav',
    'tool\stress_test_20k_report.json'
)

$deletedCount = 0
$totalBytes = 0

foreach ($item in $itemsToDelete) {
    if (Test-Path $item) {
        $size = (Get-Item $item).Length
        $totalBytes += $size
        Remove-Item -Force $item -ErrorAction SilentlyContinue
        Write-Host "Deleted file: $item ($([math]::Round($size / 1KB, 2)) KB)"
        $deletedCount++
    }
}

$dirsToDelete = @('bao_cao_phase_5', 'bao_cao_phase_5r', 'scratch', 'temp', 'exports', 'projects', 'release\1.5.0')
foreach ($dir in $dirsToDelete) {
    if (Test-Path $dir) {
        $files = Get-ChildItem -Recurse -File $dir -ErrorAction SilentlyContinue
        $dirSize = ($files | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $dirSize) { $dirSize = 0 }
        $totalBytes += $dirSize
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        Write-Host "Deleted directory: $dir ($([math]::Round($dirSize / 1MB, 2)) MB)"
        $deletedCount++
    }
}

$oneOffToolScripts = @(
    'tool\generate_phase_5r_reports.dart',
    'tool\generate_report_outputs.ps1',
    'tool\create_review_packages.ps1',
    'tool\package_phase_1r.ps1',
    'tool\package_phase_1r2.ps1',
    'tool\package_phase_2.ps1',
    'tool\package_phase_3.ps1',
    'tool\package_phase_4.ps1',
    'tool\run_20k_text_tts_stress_test.dart',
    'tool\run_25page_raster_stress_test.dart',
    'tool\run_phase_1r_validations.dart',
    'tool\run_phase_1r2_validations.dart',
    'tool\run_phase_1r2_full_suite.dart',
    'tool\run_real_ffmpeg_video_tests.dart',
    'tool\run_real_ocr_validation.dart',
    'tool\run_real_ocr_validation.ps1',
    'tool\audit_raster_fixtures.ps1',
    'tool\generate_real_raster_fixtures.ps1',
    'tool\generate_benchmark_and_edge_fixtures.ps1',
    'tool\generate_cv_fixtures.dart',
    'tool\make_three_minute.dart',
    'tool\test_onecore.ps1',
    'tool\test_synth.ps1',
    'tool\test_transcode_real.ps1',
    'tool\test_mp3_transcoder.ps1',
    'tool\test_rotation_angles.ps1',
    'tool\test_rotation_ocr.ps1',
    'tool\inspect_logs.ps1',
    'tool\check_logs.ps1',
    'tool\check_releases.ps1',
    'tool\check_tesseract.ps1',
    'tool\check_vietocr.ps1',
    'tool\download_vietocr.ps1',
    'tool\fetch_releases_info.ps1',
    'tool\generate_project_tree.dart'
)

foreach ($s in $oneOffToolScripts) {
    if (Test-Path $s) {
        $size = (Get-Item $s).Length
        $totalBytes += $size
        Remove-Item -Force $s -ErrorAction SilentlyContinue
        Write-Host "Deleted one-off script: $s"
        $deletedCount++
    }
}

Write-Host "`nTotal cleaned: $([math]::Round($totalBytes / 1MB, 2)) MB in $deletedCount items."
