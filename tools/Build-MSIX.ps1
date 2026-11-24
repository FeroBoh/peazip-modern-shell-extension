# Build Windows x64 COM extension and MSI(X) companion identity package.
# Requires VS x64 Developer Command Prompt and Windows SDK.
[CmdletBinding()]
param(
    [ValidateSet('LocalTest','Production','Unsigned')][string]$SignMode = 'LocalTest',
    [string]$CertThumbprint,
    [ValidateSet('CurrentUser','LocalMachine')][string]$CertStore = 'CurrentUser',
    [string]$TimestampUrl,
    [switch]$NoSign # backwards-compatible alias for -SignMode Unsigned
)
$ErrorActionPreference = 'Stop'
if ($NoSign) { $SignMode = 'Unsigned' }
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root 'out'
$stage = Join-Path $out 'stage'
$obj = Join-Path $out 'obj'
$version = '1.2.1.0'
$pkg = Join-Path $out "PeaZip.ModernMenu.Community_${version}_x64.msix"

function Need-Command([string]$name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if (-not $cmd) { throw "Missing $name. Use the VS 2022/2026 x64 Developer Command Prompt with Windows SDK." }
    return $cmd.Source
}
$compiler = Need-Command 'cl.exe'
# A 32-bit cl.exe silently emits x86 .obj files even if the linker is told /MACHINE:X64.
# Check both the VS target environment and the actual compiler architecture *before*
# touching any build output. This also guards against a stale PATH from an x86 prompt.
$targetArchitecture = $env:VSCMD_ARG_TGT_ARCH
if ($targetArchitecture -ne 'x64' -or
    $compiler -notmatch '(?i)[\\/]bin[\\/]Host(?:x64|x86)[\\/]x64[\\/]cl\.exe$') {
    throw ("x64 Visual Studio toolchain is required. Detected target='" +
        $targetArchitecture + "', compiler='" + $compiler +
        "'. In a normal Command Prompt run tools\Build-x64.cmd, " +
        "or open 'x64 Native Tools Command Prompt' and retry.")
}
Write-Host "Verified x64 MSVC toolchain: $compiler"
$makeappx = Need-Command 'makeappx.exe'
if ($SignMode -ne 'Unsigned') { $signTool = Need-Command 'signtool.exe' }

$signingCert = $null
$publisher = 'CN=PeaZipModernMenuLocal'
if ($SignMode -eq 'LocalTest') {
    $now = Get-Date
    $signingCert = Get-ChildItem Cert:\CurrentUser\My |
        Where-Object { $_.Subject -eq $publisher -and $_.HasPrivateKey -and $_.NotBefore -le $now -and $_.NotAfter -gt $now } |
        Sort-Object NotAfter -Descending | Select-Object -First 1
    if (-not $signingCert) {
        $signingCert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $publisher `
             -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -CertStoreLocation Cert:\CurrentUser\My
    }
} elseif ($SignMode -eq 'Production') {
    if (-not $CertThumbprint) { throw 'Production signing requires -CertThumbprint of an installed code-signing certificate.' }
    $storePath = if ($CertStore -eq 'LocalMachine') { 'Cert:\LocalMachine\My' } else { 'Cert:\CurrentUser\My' }
    $signingCert = Get-ChildItem $storePath | Where-Object { $_.Thumbprint -eq $CertThumbprint.Replace(' ','').ToUpperInvariant() } | Select-Object -First 1
    if (-not $signingCert -or -not $signingCert.HasPrivateKey -or $signingCert.NotAfter -le (Get-Date)) {
        throw 'The selected production certificate is unavailable, expired, or missing its private key.'
    }
    $publisher = $signingCert.Subject
}

New-Item -ItemType Directory -Force -Path $stage, $obj | Out-Null
# Prevent a previous x86 attempt from leaving incompatible .obj/.lib files behind.
Get-ChildItem -LiteralPath $obj -Force | Remove-Item -Force -Recurse
Get-ChildItem -LiteralPath $stage -Force | Remove-Item -Force -Recurse
Copy-Item (Join-Path $root 'packaging\Assets') (Join-Path $stage 'Assets') -Recurse
[xml]$manifest = Get-Content -LiteralPath (Join-Path $root 'packaging\AppxManifest.xml') -Raw
$manifest.Package.Identity.Version = $version
$manifest.Package.Identity.Publisher = $publisher
$manifest.Save((Join-Path $stage 'AppxManifest.xml'))

Push-Location $obj
try {
    $cpp = Join-Path $root 'src\PeaZipShellExtension.cpp'
    $dll = Join-Path $stage 'PeaZip.ModernShellExtension.dll'
    $def = Join-Path $root 'src\PeaZipShellExtension.def'
    & $compiler /nologo /std:c++17 /utf-8 /W4 /EHsc /O2 /MD /LD /DUNICODE /D_UNICODE $cpp '/link' "/OUT:$dll" "/DEF:$def" /MACHINE:X64 Ole32.lib Shell32.lib Shlwapi.lib Advapi32.lib Uuid.lib User32.lib
    if ($LASTEXITCODE -ne 0) { throw 'Failed to compile COM DLL.' }
    $stubSrc = Join-Path $root 'src\Stub.cpp'
    $stubExe = Join-Path $stage 'PeaZipMenuStub.exe'
    & $compiler /nologo /std:c++17 /W4 /O2 /MD /DUNICODE /D_UNICODE $stubSrc '/link' "/OUT:$stubExe" /MACHINE:X64 /SUBSYSTEM:WINDOWS
    if ($LASTEXITCODE -ne 0) { throw 'Failed to compile EXE stub.' }
    $configSrc = Join-Path $root 'src\PeaZipMenuConfig.cpp'
    $configExe = Join-Path $stage 'PeaZipMenuConfig.exe'
    & $compiler /nologo /std:c++17 /utf-8 /W4 /EHsc /O2 /MD /DUNICODE /D_UNICODE $configSrc '/link' "/OUT:$configExe" /MACHINE:X64 /SUBSYSTEM:WINDOWS User32.lib Comctl32.lib Comdlg32.lib Shlwapi.lib Advapi32.lib Gdi32.lib
    if ($LASTEXITCODE -ne 0) { throw 'Failed to compile configuration GUI.' }
} finally { Pop-Location }

& $makeappx pack /d $stage /p $pkg /o
if ($LASTEXITCODE -ne 0) { throw 'MakeAppx failed. Check manifest schema and assets.' }

if ($SignMode -ne 'Unsigned') {
    $signArgs = @('sign','/fd','SHA256','/sha1',$signingCert.Thumbprint,'/s','My')
    if ($CertStore -eq 'LocalMachine' -and $SignMode -eq 'Production') { $signArgs += '/sm' }
    if ($TimestampUrl) { $signArgs += @('/tr',$TimestampUrl,'/td','SHA256') }
    $signArgs += $pkg
    & $signTool @signArgs
    if ($LASTEXITCODE -ne 0) { throw 'SignTool failed.' }
    if ($SignMode -eq 'LocalTest') {
        Export-Certificate -Cert $signingCert -FilePath (Join-Path $out 'PeaZipModernMenuLocal.cer') -Force | Out-Null
        Write-Warning 'Development certificate only. Do not distribute this as a production trust anchor.'
        Write-Host "Test certificate SHA1: $($signingCert.Thumbprint)"
    }
} else { Write-Warning 'Package is unsigned; standard Windows MSIX installation will reject it.' }
Write-Host "Created: $pkg"
Write-Host 'Install with tools\Install-Companion.ps1 or build a per-user Inno Setup installer.'
