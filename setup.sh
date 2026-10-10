#!/usr/bin/env bash
# One-time project setup for macOS/Linux.
set -e
flutter create --org com.jdsoftware --project-name case_diary --platforms android .
dart run tools/apply_android_config.dart
flutter pub get
echo "Setup finished. Connect your phone and run: flutter run"
