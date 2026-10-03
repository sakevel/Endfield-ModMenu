$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$package=Join-Path $root 'build/package/Release/mod-menu'
$manifest=Get-Content -LiteralPath (Join-Path $package 'zml-package.json') -Raw | ConvertFrom-Json
$dist=Join-Path $root 'dist';New-Item -ItemType Directory -Force $dist | Out-Null
$zip=Join-Path $dist ('EndfieldModMenu-0.3.3-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.zip')
$files=@($manifest.files | ForEach-Object {Join-Path $package $_}) + @(Join-Path $package 'zml-package.json')
foreach($file in $files){if(-not(Test-Path -LiteralPath $file -PathType Leaf)){throw "Missing release file: $file"}}
Compress-Archive -LiteralPath $files -DestinationPath $zip
(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash+'  '+(Split-Path $zip -Leaf) | Set-Content -Encoding ascii ($zip+'.sha256')
Write-Output $zip
