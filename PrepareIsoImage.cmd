@ECHO OFF
setlocal ENABLEDELAYEDEXPANSION

rem
rem Generate current date
rem
for /f "skip=1" %%x in ('wmic os get localdatetime') do if not defined CustomDate set CustomDate=%%x
set today=%CustomDate:~0,4%%CustomDate:~4,2%%CustomDate:~6,2%

rem
rem Set variables for local use
rem
set WIMFILE=%~1
set WORKINGDIR=%~2
set DEST=%~3

set TEMPL=media
set FWFILES=fwfiles
set EXITCODE=0

rem
rem Input validation
rem
if /i "%1"=="/?" goto usage
if /i "%1"=="" goto usage
if /i "%~2"=="" goto usage
if /i "%~3"=="" goto usage
if /i not "%~4"=="" goto usage

rem
rem Make sure OSCDImg is available
rem
if not exist "%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe" (
    echo ERROR: OSCDImg is not available. Have you installed Windows ADK
    goto fail
)

rem
rem Make sure the working directory exists
rem
if not exist "%WORKINGDIR%" (
  echo ERROR: Working directory does not exist: "%WORKINGDIR%".
  goto fail
)

rem
rem Make sure the working directory is valid as per our requirements
rem
if not exist "%WORKINGDIR%\%TEMPL%" (
  echo ERROR: Working directory is not valid: "%WORKINGDIR%".
  goto fail
)

cls
echo.
echo **************************************************
echo ***              PrepareIsoImage               ***
echo **************************************************
echo.
echo WimFile:     %WIMFILE%
echo WorkingDir:  %WORKINGDIR%
echo Destination: %DEST%

rem
rem ISO section of the script, for creating bootable ISO image
rem
:ISOWorker

  rem
  rem Make sure the destination refers to an ISO file, ending in .ISO
  rem
  echo %DEST%| findstr /E /I "\.iso" >NUL
  if errorlevel 1 (
    echo ERROR: Destination needs to be an .ISO file.
    goto fail
  )

  if not exist "%DEST%" goto ISOWorker_CopyWimFile

  rem
  rem Confirm from the user that they want to overwrite the existing ISO file
  rem
  choice /T 5 /D Y /C YN /M "Destination file %DEST% exists, overwrite it "
  if errorlevel 2 goto ISOWorker_DestinationFileExists
  if errorlevel 1 goto ISOWorker_CleanDestinationFile

:ISOWorker_DestinationFileExists
  echo Destination file %DEST% will not be overwritten; exiting.
  goto cleanup

:ISOWorker_CleanDestinationFile
  rem
  rem Delete the existing ISO file
  rem
  del /F /Q "%DEST%"
  if errorlevel 1 (
    echo ERROR: Failed to delete "%DEST%".
    goto fail
  )

:ISOWorker_CopyWimFile
  rem
  rem Make sure the file is ending in .wim
  rem
  echo %WIMFILE%| findstr /E /I "\.wim" >NUL
  if errorlevel 1 (
    echo ERROR: Destination needs to be an .WIM file.
    goto fail
  )

  rem
  rem Delete install.wim in working dir
  rem
  if exist "%WORKINGDIR%\%TEMPL%\sources\install.wim" (
      echo Deleting existing install.wim ...
      echo.
      del /F /Q "%WORKINGDIR%\%TEMPL%\sources\install.wim"
        if errorlevel 1 (
            echo ERROR: Failed to delete "%WORKINGDIR%\%TEMPL%\sources\install.wim".
            goto fail
        )
  )

  rem
  rem Copy source wim file to working dir
  rem
  echo Copy WIM file to working directory
  echo.
  copy /Y "%WIMFILE%" "%WORKINGDIR%\%TEMPL%\sources\install.wim"
  if errorlevel 1 (
    echo ERROR: Failed to copy WIM file to working directory.
    goto fail
  )

:ISOWorker_OscdImgCommand

  rem
  rem Set the correct boot argument based on availability of boot apps
  rem
  set BOOTDATA=1#pEF,e,b"%WORKINGDIR%\%FWFILES%\efisys.bin"
  if exist "%WORKINGDIR%\%FWFILES%\etfsboot.com" (
    set BOOTDATA=2#p0,e,b"%WORKINGDIR%\%FWFILES%\etfsboot.com"#pEF,e,b"%WORKINGDIR%\%FWFILES%\efisys.bin"
  )

  rem
  rem Create the ISO file using the appropriate OSCDImg command
  rem
  echo Creating %DEST%...
  echo.
  oscdimg -bootdata:%BOOTDATA% -l"WinSetup%today%" -u1 -udfver102 "%WORKINGDIR%\%TEMPL%" "%DEST%" >NUL
  if errorlevel 1 (
    echo ERROR: Failed to create "%DEST%" file.
    goto fail
  )

  goto success


:success
set EXITCODE=0
echo.
echo Success
echo.
goto cleanup


:usage
set EXITCODE=1
echo Creates bootable Windows ISO file.
echo.
echo PrepareIsoImage ^<WIMFile^> ^<workingDirectory^> ^<destination^>
echo.
echo  WIMFile           Specifies the WIM file that contains the windows image.
echo                    This file will be copied to the
echo                    ^<workingDirectory^>\media\sources folder. Any existing file
echo                    will be overwritten.
echo  workingDirectory  Specifies the working directory created using copype.cmd
echo                    The contents of the ^<workingDirectory^>\media folder
echo                    will be copied to the ISO.
echo  destination       Specifies the .ISO path and file name.
echo.
echo  Examples:
echo    PrepareIsoImage C:\winsetup\windows-10-install.wim C:\winsetup C:\winsetup\windows-setup.iso
echo.
goto cleanup


:fail
set EXITCODE=1
goto cleanup

:cleanup
endlocal & exit /b %EXITCODE%