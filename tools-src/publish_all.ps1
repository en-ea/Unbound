# Export the Web build, copy it into web/, commit everything and push the current branch (the test link).
# Usage (from C:\SoonGame): powershell -File tools-src\publish_all.ps1 "What changed"
param([string]$message = "Publish web build")
Set-Location (Split-Path $PSScriptRoot -Parent)
$p = Start-Process -FilePath "tools\Godot_v4.7.2-stable_win64_console.exe" -ArgumentList "--headless","--path","game","--export-release","Web","../build/web/index.html" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\exp.txt" -RedirectStandardError "$env:TEMP\exp_err.txt"
$p.WaitForExit(300000) | Out-Null
Get-Content "$env:TEMP\exp.txt" -Tail 1
Copy-Item tools-src\app.webmanifest, tools-src\offline.sw.js build\web\
& "C:\Program Files\Git\bin\bash.exe" tools-src/publish_web.sh
git add -A
git commit -q -m "$message`n`nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push -q origin HEAD
git log --oneline -1
