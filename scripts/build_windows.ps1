param(
    [string]$BuildType = "Release"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..")
$ZvecSrc = Join-Path $ProjectRoot "third_party\zvec"

if (-not (Test-Path (Join-Path $ZvecSrc "src"))) {
    Write-Error "third_party/zvec does not exist or is not initialized. Run: git submodule update --init --recursive"
}

$Arch = "x64"
$Nproc = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors

Write-Host "============================================"
Write-Host "  Zvec Windows Build"
Write-Host "  Build Type: $BuildType"
Write-Host "  Arch:       $Arch"
Write-Host "============================================"

Write-Host ""
Write-Host "[1/3] Building host protoc..."

$HostBuildDir = Join-Path $ProjectRoot "build\host"
$ProtocCandidates = @(
    Join-Path $HostBuildDir "bin\protoc.exe",
    Join-Path $HostBuildDir "bin\$BuildType\protoc.exe"
)
$ProtocExecutable = $ProtocCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($ProtocExecutable) {
    Write-Host "  Already exists, skipping: $ProtocExecutable"
} else {
    Push-Location $ZvecSrc
    git submodule foreach --recursive 'git stash --include-untracked || true' *> $null
    Pop-Location

    New-Item -ItemType Directory -Force -Path $HostBuildDir | Out-Null
    cmake -S $ZvecSrc -B $HostBuildDir -DCMAKE_BUILD_TYPE=$BuildType
    cmake --build $HostBuildDir --target protoc --config $BuildType --parallel $Nproc

    $ProtocExecutable = $ProtocCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $ProtocExecutable) {
        $ProtocExecutable = Get-ChildItem -Path $HostBuildDir -Filter protoc.exe -Recurse |
            Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $ProtocExecutable) {
        Write-Error "protoc.exe build artifact not found under $HostBuildDir"
    }
}

Write-Host "[1/3] Done"

Write-Host ""
Write-Host "[2/3] Building zvec_c_api for Windows..."

Push-Location $ZvecSrc
git submodule foreach --recursive 'git stash --include-untracked || true' *> $null
Pop-Location

$WindowsBuildDir = Join-Path $ProjectRoot "build\windows_build"
New-Item -ItemType Directory -Force -Path $WindowsBuildDir | Out-Null

cmake `
    -S $ZvecSrc `
    -B $WindowsBuildDir `
    -DCMAKE_BUILD_TYPE=$BuildType `
    -DBUILD_C_BINDINGS=ON `
    -DBUILD_PYTHON_BINDINGS=OFF `
    -DBUILD_TOOLS=OFF `
    -DCMAKE_INSTALL_PREFIX="$WindowsBuildDir\install" `
    -DGLOBAL_CC_PROTOBUF_PROTOC="$ProtocExecutable"

cmake --build $WindowsBuildDir --target zvec_c_api --config $BuildType --parallel $Nproc

Write-Host "[2/3] Done"

Write-Host ""
Write-Host "[3/3] Copying zvec.dll ..."

$WindowsOutputDir = Join-Path $ProjectRoot "build\windows"
$WindowsPluginLibDir = Join-Path $ProjectRoot "windows\lib"
New-Item -ItemType Directory -Force -Path $WindowsOutputDir, $WindowsPluginLibDir | Out-Null

$Dll = Get-ChildItem -Path $WindowsBuildDir -Filter zvec_c_api.dll -Recurse |
    Select-Object -First 1
if (-not $Dll) {
    Write-Host "CMake build directory DLLs:"
    Get-ChildItem -Path $WindowsBuildDir -Filter *.dll -Recurse | ForEach-Object { $_.FullName }
    Write-Error "zvec_c_api.dll build artifact not found"
}

$BuildDll = Join-Path $WindowsOutputDir "zvec.dll"
$PluginDll = Join-Path $WindowsPluginLibDir "zvec.dll"
Copy-Item $Dll.FullName $BuildDll -Force
Copy-Item $Dll.FullName $PluginDll -Force

Write-Host "[3/3] Done"

Write-Host ""
Write-Host "============================================"
Write-Host "  Build successful!"
Write-Host "  Output: build/windows/zvec.dll"
Write-Host "          windows/lib/zvec.dll"
Write-Host "  Size:   $([Math]::Round((Get-Item $BuildDll).Length / 1MB, 2)) MB"
Write-Host "============================================"

$ReleaseDir = Join-Path $ProjectRoot "build\release"
New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
$ZipPath = Join-Path $ReleaseDir "libzvec-windows-$Arch.zip"
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}
Compress-Archive -Path $BuildDll -DestinationPath $ZipPath
Write-Host "  Release zip: build/release/libzvec-windows-$Arch.zip"
