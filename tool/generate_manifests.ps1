$releaseDir = Resolve-Path "build\windows\x64\runner\Release"
$files = Get-ChildItem -Path $releaseDir -Recurse -File

$manifestLines = @()
$manifestLines += "SHA256 CHECKSUMS OF RELEASE DISTRIBUTION ARTIFACTS:"
$manifestLines += "Target: build\windows\x64\runner\Release"
$manifestLines += "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$manifestLines += "===================================================================================================="
$manifestLines += ("{0,-64}  {1,10}  {2}" -f "SHA256 HASH", "SIZE (B)", "RELATIVE PATH")
$manifestLines += "----------------------------------------------------------------------------------------------------"

foreach ($file in $files) {
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
    $rel = $file.FullName.Substring($releaseDir.Path.Length + 1)
    $manifestLines += ("{0,-64}  {1,10}  {2}" -f $hash, $file.Length, $rel)
}

$manifestLines | Out-File -FilePath "bao_cao_phase_1r\RELEASE_MANIFEST_SHA256.txt" -Encoding utf8
Write-Host "Generated bao_cao_phase_1r\RELEASE_MANIFEST_SHA256.txt"

# Generate RELEASE_TREE.txt
$treeLines = @()
$treeLines += "RELEASE DIRECTORY STRUCTURE:"
$treeLines += "Root: $releaseDir"
$treeLines += "===================================================================================================="
$items = Get-ChildItem -Path $releaseDir -Recurse
foreach ($it in $items) {
    $rel = $it.FullName.Substring($releaseDir.Path.Length + 1)
    $type = if ($it.PSIsContainer) { "<DIR> " } else { ("{0,10} B" -f $it.Length) }
    $treeLines += ("{0,-15}  {1}" -f $type, $rel)
}
$treeLines | Out-File -FilePath "bao_cao_phase_1r\RELEASE_TREE.txt" -Encoding utf8
Write-Host "Generated bao_cao_phase_1r\RELEASE_TREE.txt"

# Generate PROJECT_TREE.txt
& dart run gen_tree.dart > "bao_cao_phase_1r\PROJECT_TREE.txt"
Write-Host "Generated bao_cao_phase_1r\PROJECT_TREE.txt"
