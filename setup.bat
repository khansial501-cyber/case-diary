@echo off
REM One-time project setup for Windows. Run from this folder (double-click or in VS Code terminal).
echo === Case Diary setup ===
call flutter create --org com.jdsoftware --project-name case_diary --platforms android .
if errorlevel 1 goto :err
call dart run tools/apply_android_config.dart
if errorlevel 1 goto :err
call flutter pub get
if errorlevel 1 goto :err
echo.
echo Setup finished. Connect your phone (USB debugging ON) and run:  flutter run
goto :eof
:err
echo.
echo Something failed - read the message above and send it to me.
