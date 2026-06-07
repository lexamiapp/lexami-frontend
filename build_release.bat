@echo off
cd android
call gradlew.bat assembleRelease --no-daemon > build_release_output.txt 2>&1
echo Build finished with exit code %ERRORLEVEL% >> build_release_output.txt
cd ..
type build_release_output.txt
