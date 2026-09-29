Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$voices = $synth.GetInstalledVoices()
Write-Host "INSTALLED_SAPI_VOICES_COUNT: $($voices.Count)"
foreach ($v in $voices) {
    Write-Host "SAPI_VOICE: $($v.VoiceInfo.Name) | LANG: $($v.VoiceInfo.Culture.Name) | GENDER: $($v.VoiceInfo.Gender) | ENABLED: $($v.Enabled)"
}

# Also probe Windows.Media.SpeechSynthesis (OneCore voices)
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $asTaskOp = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq "AsTask" -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name.StartsWith("IAsyncOperation")
    } | Select-Object -First 1

    [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime] | Out-Null
    $allVoices = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices
    Write-Host "ONECORE_VOICES_COUNT: $($allVoices.Count)"
    foreach ($ov in $allVoices) {
        Write-Host "ONECORE_VOICE: $($ov.DisplayName) | ID: $($ov.Id) | LANG: $($ov.Language) | GENDER: $($ov.Gender)"
    }
} catch {
    Write-Host "ONECORE_PROBE_ERROR: $_"
}
