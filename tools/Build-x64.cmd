@echo off
setlocal EnableExtensions
rem Build the x64 MSIX from any normal Windows Command Prompt.
rem Force x64 MSVC + SDK INCLUDE/LIB rather than trusting the caller's toolchain.
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
    echo ERROR: vswhere.exe not found. Install Visual Studio C++ Build Tools. 1>&2
    exit /b 1
)
set "VSROOT=" 
for /f "usebackq delims=" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSROOT=%%I"
if not defined VSROOT (
    echo ERROR: No Visual Studio installation with MSVC x86/x64 tools found. 1>&2
    exit /b 1
)
if not exist "%VSROOT%\Common7\Tools\VsDevCmd.bat" (
    echo ERROR: Visual Studio developer environment not found. 1>&2
    exit /b 1
)
call "%VSROOT%\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64
if errorlevel 1 exit /b 1
if /I not "%VSCMD_ARG_TGT_ARCH%"=="x64" (
    echo ERROR: Failed to initialize x64 MSVC target environment. 1>&2
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-MSIX.ps1" %*
exit /b %errorlevel%
