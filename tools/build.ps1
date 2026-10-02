param([string]$LupaPath='', [string]$ServicesTestExe='')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
& cmake -S $root -B (Join-Path $root 'build') -G 'Visual Studio 17 2022' -A x64 "-DZML_LUPA_PATH=$LupaPath" "-DZML_SERVICES_TEST_EXE=$ServicesTestExe"
if($LASTEXITCODE -ne 0){throw 'Configure failed'}
& cmake --build (Join-Path $root 'build') --config Release --parallel 6
if($LASTEXITCODE -ne 0){throw 'Build failed'}
& ctest --test-dir (Join-Path $root 'build') -C Release --output-on-failure
if($LASTEXITCODE -ne 0){throw 'Tests failed'}
Write-Output (Join-Path $root 'build/package/Release/mod-menu')
