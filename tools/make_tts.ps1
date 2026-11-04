# Generates spoken guide cues (pt-BR) used by make_demo_song.py.
# Requires Windows with the "Microsoft Maria Desktop" voice.
param([string]$OutDir = "$PSScriptRoot\tts")

Add-Type -AssemblyName System.Speech
New-Item -ItemType Directory -Force $OutDir | Out-Null

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SelectVoice('Microsoft Maria Desktop')
$synth.Rate = 2
$format = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(
    44100,
    [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,
    [System.Speech.AudioFormat.AudioChannel]::Mono)

$phrases = [ordered]@{
    um = 'um'; dois = 'dois'; tres = 'três'; quatro = 'quatro'
    intro = 'intro'; verso = 'verso'; refrao = 'refrão'; ponte = 'ponte'; final = 'final'
}

foreach ($key in $phrases.Keys) {
    $synth.SetOutputToWaveFile((Join-Path $OutDir "$key.wav"), $format)
    $synth.Speak($phrases[$key])
}
$synth.SetOutputToNull()
$synth.Dispose()
