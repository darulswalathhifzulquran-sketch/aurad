@echo off
REM Double-click (or run in VS Code terminal) from the project folder.
REM 1) imports EVERYTHING inside the content folder in one go
REM 2) builds the web app into build\web  (this is what you upload / host)
echo ===== Importing content =====
dart tool\import_content.dart
if errorlevel 1 (
  echo Import failed - see messages above.
  pause
  exit /b 1
)
echo.
echo Report saved in tool\import_report.txt
echo.
echo ===== Building web app =====
call flutter build web --release
echo.
echo Done. Upload the folder  build\web  (see PUBLISH_GUIDE.txt)
pause
