@ECHO OFF
title Windows 10 Education 1909 image creation
setlocal ENABLEDELAYEDEXPANSION

rem
rem Input validation
rem
if /i "%1"=="/?" goto usage
if /i not "%~2"=="" goto usage


cls
echo.
echo ************************************************************
echo ***           Windows 10 Education 1909 P720             ***
echo ***               automated image creation               ***
echo ************************************************************
rem created by Martin Aulenbach 11/14/2019
rem last modified 01/17/2020
echo.

rem
rem Generate current date
rem
for /f "skip=1" %%x in ('wmic os get localdatetime') do if not defined MyDate set MyDate=%%x
set today=%MyDate:~0,4%%MyDate:~4,2%%MyDate:~6,2%

rem
rem Set variables for local use
rem
set BASEWIM=%~d0\2_IMAGES\WIM\edu-1909-base.wim
if /i "%~1"=="" ( set TARGETIMAGE=%~d0\2_IMAGES\edu-1909-P720-%today%.wim ) else ( set TARGETIMAGE=%~1 )
set PATCHESPATH=%~d0\4_WindowsUpdateKatalog\Updates\Windows10-x64\General\18362
set MOUNTDIR=%SYSTEMDRIVE%\mount\windows
set IMAGEX="C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\imagex.exe"
set EXITCODE=0

rem check administrative rights
whoami /groups | find "S-1-16-12288" > nul
if errorlevel 1 (
  echo ERROR: Script needs to be run with administrative rights!
  goto fail
)

rem check imagex location
if not exist %IMAGEX% (
  echo ERROR: ImageX must be available
  goto fail
)

rem check presence of nodejs
where /Q node.exe 1> nul 2>&1
if %errorlevel% neq 0 (
  echo ERROR: NodeJs must be present
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
for /f "tokens=*" %%i in ('node "%~d0\7_Sysprep\getWindowsUpdates\getWindowsUpdates.js" "%~d0\4_WindowsUpdateKatalog\Windows10-x64.xml" 18362') do set PATCHES=%%i
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
choice /T 10 /D Y /C YN /M "Create image from scratch? (existing image will be deleted) default: yes"
if errorlevel 2 goto mountimage

if exist %TARGETIMAGE% ( del /Q %TARGETIMAGE% )
echo.
:export
rem
rem export image
rem
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
set /a MountIndex=1
set /a LastNumberMount=1
set /a MaxMountNumber=1
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
rem setting image marker
rem
echo *** Set image marker file ***
DEL /Q "%MOUNTDIR%\*.MRK"
echo %today% > "%MOUNTDIR%\EDU-1909-P720-%today%.MRK"
echo %PATCHES% >> "%MOUNTDIR%\EDU-1909-P720-%today%.MRK"
echo.


:updates
rem
rem integrate updates
rem
choice /T 5 /D Y /C YN /M "Integrate patches? default: yes"
if errorlevel 2 goto startlayout
pushd %PATCHESPATH%
for %%f in (%PATCHES%) do (
  echo.
  echo *** Installing: %%f ***
  dism /English /Image:%MOUNTDIR% /Add-Package /PackagePath:"%%~dpnxf"
  echo ======================
)
popd
echo.


:startlayout
rem
rem startlayout
rem
echo *** Copy default start menu layout ***
choice /T 5 /D N /C YN /M "Copy start menu layout? default: no"
if errorlevel 2 goto drivers
rem powershell "Import-StartLayout -LayoutPath '%~d0\7_Sysprep\StartLayout_with_taskbar.xml' -MountPath '%MOUNTDIR%\\'"
copy /y "%~d0\7_Sysprep\StartLayout_with_taskbar_201909.xml" "%MOUNTDIR%\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml"
echo.


:drivers
rem
rem driver integration Q957
rem
echo *** Integrate Q957 drivers ***
dism /English /Image:%MOUNTDIR% /Add-Driver /Driver:"%~d0\5_Treiber\drivers-P720" /Recurse


:registysettings
rem
rem edit default registry settings
rem
echo *** Apply default registry settings ***
choice /T 5 /D Y /C YN /M "Apply default registry settings? default: yes"
if errorlevel 2 goto optimize
reg load HKLM\DEFAULT "%MOUNTDIR%\Users\Default\NTUSER.DAT"
reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization" /v SystemSettingsDownloadMode /t REG_DWORD /d 3 /f
reg add "HKLM\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f
reg add "HKLM\DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" /v PeopleBand /t REG_DWORD /d 0 /f
reg add "HKLM\DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 1 /f
reg add "HKLM\DEFAULT\Software\Microsoft\Office\16.0\Common\General" /v ShownFirstRunOptin /t REG_DWORD /d 1 /f
reg add "HKLM\DEFAULT\SOFTWARE\Adobe\Acrobat Reader\DC\AdobeViewer" /v EULA /t REG_DWORD /d 1 /f
reg delete "HKLM\DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v OneDriveSetup /F
reg unload HKLM\DEFAULT
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
choice /T 5 /D A /C AS /M "[A]ppend or [S]ave image? default: A"
if errorlevel 2 ( 
  echo.
  echo * Saving Image
  echo.
  dism /English /Unmount-Image /MountDir:%MOUNTDIR% /Commit /CheckIntegrity
)
if errorlevel 1 (
  echo.
  echo * Appending Image
  echo.
  dism /English /Unmount-Image /MountDir:%MOUNTDIR% /Commit /CheckIntegrity /Append

  rem get the image number for appended image
  set /a LastNumberMount=1
  for /f "tokens=1,2* delims=: " %%L in ('dism /English /Get-WimInfo /WimFile:%TARGETIMAGE%') do (
    if "%%L"=="Index" (
      set /a LastNumberMount=%%M
    )
  )
  rem change name for appended image
  echo MountNumber of new image is !LastNumberMount!
  echo %IMAGEX% /INFO %TARGETIMAGE% !LastNumberMount! "Windows 10 Education P720 %today%" "[Script] Anpassungen & Patches, Drivers Esprimo P720"
  if exist %IMAGEX% (
    %IMAGEX% /INFO %TARGETIMAGE% !LastNumberMount! "Windows 10 Education P720 %today%" "[Script] Anpassungen & Patches, Drivers Esprimo P720"
  )
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
echo  WIMFile        Specifies the WIM file that contains the windows image to
echo                 be edited.
echo                 A selection will be shown if there is more than one image.
echo.
echo  Examples:
echo    %~n0 C:\winsetup\windows-10-install.wim
echo.
goto cleanup


:fail
set EXITCODE=1
pause
goto cleanup

:cleanup
endlocal & exit /b %EXITCODE%