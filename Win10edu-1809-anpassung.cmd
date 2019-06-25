@ECHO OFF
title Windows 10 Education 1809 image creation
setlocal ENABLEDELAYEDEXPANSION

rem
rem Input validation
rem
if /i "%1"=="/?" goto usage
if /i not "%~2"=="" goto usage


cls
echo.
echo ************************************************************
echo ***               Windows 10 Education 1809              ***
echo ***               automated image creation               ***
echo ************************************************************
rem created by Martin Aulenbach 02-24-2019
rem last modified 06-16-2019
echo.

rem
rem Generate current date
rem
for /f "skip=1" %%x in ('wmic os get localdatetime') do if not defined MyDate set MyDate=%%x
set today=%MyDate:~0,4%%MyDate:~4,2%%MyDate:~6,2%

rem
rem Set variables for local use
rem
set BASEWIM=%~d0\2_IMAGES\WIM\win10edu-1809-base.wim
if /i "%~1"=="" ( set TARGETIMAGE=%~d0\2_IMAGES\win10edu-1809-%today%.wim ) else ( set TARGETIMAGE=%~1 )
set PATCHESPATH=%~d0\4_WindowsUpdateKatalog\Updates\Windows10-x64\General\17763
set MOUNTDIR=%SYSTEMDRIVE%\mount\windows
set EXITCODE=0

rem check administrative rights
whoami /groups | find "S-1-16-12288" > nul
if errorlevel 1 (
  echo ERROR: Script needs to be run with administrative rights!
  goto fail
)

if not exist %BASEWIM% (
  echo ERROR: Base image file not found at %BASEWIM%
  goto fail
)

if not exist %MOUNTDIR% (
  echo Mount folder does not exist. Creating it.
  mkdir %MOUNTDIR%
)

rem
rem get patches for this windows version
rem
for /f "tokens=*" %%i in ('node "%~d0\7_Sysprep\getWindowsUpdates\getWindowsUpdates.js" "%~d0\4_WindowsUpdateKatalog\Windows10-x64.xml" 17763') do set PATCHES=%%i
if errorlevel 1 (
  echo ERROR: Updates could not be determined
  goto fail
)

echo.
echo *** Initial checks passed ***
echo Base image: %BASEWIM%
echo Image name: %TARGETIMAGE%
echo Patches:    %PATCHESPATH%
echo.

pause

rem
rem create new image
rem
if not exist "%TARGETIMAGE%" goto export
choice /T 10 /D N /C YN /M "Create image from scratch? (existing image will be deleted) default: no"
if errorlevel 2 goto mountimage

if exist %TARGETIMAGE% ( del /Q %TARGETIMAGE% )
echo.
:export
echo *** Exporting image from base image ***
set BaseIndex=1
set LastNumberBase=1
for /f "tokens=1,2* delims=: " %%L in ('dism /English /Get-WimInfo /WimFile:%BASEWIM%') do (
  if "%%L"=="Index" set /a LastNumberBase=%%M
)
if !LastNumberBase! equ 1 echo *** Only one image available *** && goto exportnext

dism /English /Get-WimInfo /WimFile:%BASEWIM%
echo.
set /p BaseIndex=Select number of desired image: 
:exportnext
dism /English /Export-Image /SourceImageFile:%BASEWIM% /SourceIndex:%BaseIndex% /DestinationImageFile:%TARGETIMAGE%
echo.


:mountimage
rem
rem Mount image
rem
echo *** Mounting Windows image ***
set MountIndex=1
set LastNumberMount=1
set MaxMountNumber=1
for /f "tokens=1,2* delims=: " %%L in ('dism /English /Get-WimInfo /WimFile:%TARGETIMAGE%') do (
  if "%%L"=="Index" (
    set /a LastNumberMount=%%M
    set /a MaxMountNumber=%%M
  )
)
if !LastNumberMount! equ 1 echo *** Only one image in target file available *** && goto mountnext
dism /English /Get-WimInfo /WimFile:"%TARGETIMAGE%"
echo.
set /p MountIndex=Select number of desired image: 
:mountnext
dism /English /Mount-Image /ImageFile:%TARGETIMAGE% /Index:%MountIndex% /MountDir:%MOUNTDIR%
echo.


rem
rem integrate updates
rem
choice /T 10 /D N /C YN /M "Integrate patches? default: no"
if errorlevel 2 goto startlayout

pushd %PATCHESPATH%
for %%f in (%PATCHES%) do (
  echo.
  echo *** Installing: %%f ***
  dism /English /Image:%MOUNTDIR% /Add-Package /PackagePath:"%%~dpnxf"
  echo ======================
)
popd


:startlayout
rem
rem startlayout
rem
echo *** Copy default start menu layout ***
choice /T 5 /D N /C YN /M "Copy start menu layout? default: no"
if errorlevel 2 goto auditmode
powershell "Import-StartLayout -LayoutPath %~d0\7_Sysprep\StartLayout_with_taskbar.xml -MountPath %MOUNTDIR%\\"
rem copy "%~d0\7_Sysprep\StartLayout_with_taskbar.xml" "%MOUNTDIR%\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml"
echo.


:auditmode
rem
rem copy unattend.xml for audit mode
rem
echo *** Copy unattend.xml for boot to audit ***
choice /T 10 /D N /C YN /M "Copy unattend.xml for audit mode? default: no"
if errorlevel 2 goto optimize
if not exist "%MOUNTDIR%\Windows\Panther\Unattend" ( mkdir "%MOUNTDIR%\Windows\Panther\Unattend" )
copy /y "%~dp0\unattend-audit.xml" "%MOUNTDIR%\Windows\Panther\Unattend\Unattend.xml"
echo.


:optimize
rem
rem optimize image
rem
echo *** Optimize Windows image - will take a long time ***
choice /T 10 /D N /C YN /M "Optimize image? default: no"
if errorlevel 2 goto unmount
dism /English /Image:%MOUNTDIR% /Cleanup-Image /StartComponentCleanup
echo.


:unmount
rem
rem unmount image
rem
echo *** Unmount Windows 10 image ***
choice /T 10 /D S /C AS /M "[A]ppend image or [S]ave it? default: Save"
if errorlevel 2 ( dism /English /Unmount-Image /MountDir:%MOUNTDIR% /Commit /CheckIntegrity )
if errorlevel 1 (
  dism /English /Unmount-Image /MountDir:%MOUNTDIR% /Commit /CheckIntegrity /Append
  set /a MaxMountNumber=%MaxMountNumber%+1
)

powershell "get-windowsimage -imagepath '%TARGETIMAGE%'"

goto success




:success
set EXITCODE=0
echo.
echo Success
echo.
goto cleanup


:usage
set EXITCODE=1
echo Edits a Windows image.
echo.
echo %~n0 ^[^<WIMFile^>^]
echo.
echo  WIMFile           Specifies the WIM file that contains the windows image to be edited.
echo                    A selection will be shown if there is more than one image.
echo.
echo  Examples:
echo    %~n0 C:\winsetup\windows-10-install.wim
echo.
goto cleanup


:fail
set EXITCODE=1
goto cleanup

:cleanup
endlocal & exit /b %EXITCODE%