$ErrorActionPreference = 'Stop'
$parts = Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'RiceCommission-1.3.6.zip.part*' | Sort-Object Name
if ($parts.Count -ne 12) { throw 'Expected 12 parts. Download the full Games repository ZIP and extract it first.' }
$target = Join-Path $PSScriptRoot 'RiceCommission-1.3.6.zip'
if (Test-Path -LiteralPath $target) { throw 'Output ZIP already exists. Move it elsewhere before merging.' }
$output = [IO.File]::Create($target)
try { foreach ($part in $parts) { $inputFile = [IO.File]::OpenRead($part.FullName); try { $inputFile.CopyTo($output) } finally { $inputFile.Dispose() } } } finally { $output.Dispose() }
$hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
if ($hash -ne '779C5E3DD705A8569D004A6CC3B368974E480751B66EB869581A4788B77C4D43') { throw 'SHA256 mismatch. Download the parts again.' }
Write-Host 'ZIP restored and SHA256 verified:' $target
