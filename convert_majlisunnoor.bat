@echo off
REM Double-click. Put the Majlisunnoor PDF (name contains "majlis") in this folder first.
cd /d "%~dp0"
set PY=
where python >nul 2>&1 && set PY=python
if "%PY%"=="" where py >nul 2>&1 && set PY=py
if "%PY%"=="" (
  echo Python is not installed. Install it from the Microsoft Store ^(search "Python 3"^) and run this again.
  pause
  exit /b 1
)
%PY% -m pip install --quiet pymupdf
set PDF=
for %%f in (*majlis*.pdf) do set PDF=%%f
if "%PDF%"=="" (
  echo No PDF with "majlis" in its name found in this folder.
  pause
  exit /b 1
)
echo Using %PDF%
%PY% tool\pdf_to_pages.py "%PDF%" --out assets\majlis --width 900 --quality 80 --expect 0
echo.
echo Now stop the app ^(press q in the terminal^) and run:  flutter pub get  then  flutter run -d chrome
pause
