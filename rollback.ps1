param([string]$ProjectRoot = "C:\GitHub\energy-v2-demo")
$backup = Get-ChildItem $ProjectRoot -Directory -Filter ".aios.backup.*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (!$backup) { throw "No .aios backup found." }
Remove-Item (Join-Path $ProjectRoot ".aios") -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item $backup.FullName (Join-Path $ProjectRoot ".aios") -Recurse -Force
Write-Host "Rolled back .aios from $($backup.FullName)"
