// Run ONCE after `flutter create`:   dart run tools/apply_android_config.dart
// Copies the manifest, switches MainActivity to FlutterFragmentActivity (needed for fingerprint
// unlock), and patches Gradle (minSdk 29, core-library desugaring). Safe to run twice.
import 'dart:io';

void main() {
  final root = Directory.current.path;
  final sep = Platform.pathSeparator;
  String p(String rel) => '$root$sep${rel.replaceAll('/', sep)}';

  // 1. Manifest
  final src = File(p('android_overlay/AndroidManifest.xml'));
  final dst = File(p('android/app/src/main/AndroidManifest.xml'));
  if (!src.existsSync() || !dst.parent.existsSync()) {
    stderr.writeln('Run this from the project folder AFTER "flutter create". android/ not found.');
    exit(1);
  }
  dst.writeAsStringSync(src.readAsStringSync());
  print('OK  AndroidManifest.xml');

  // 2. MainActivity -> FlutterFragmentActivity
  final kotlinDir = Directory(p('android/app/src/main'));
  for (final f in kotlinDir.listSync(recursive: true)) {
    if (f is File && f.path.endsWith('MainActivity.kt')) {
      var s = f.readAsStringSync();
      if (!s.contains('FlutterFragmentActivity')) {
        s = s.replaceAll('import io.flutter.embedding.android.FlutterActivity', 'import io.flutter.embedding.android.FlutterFragmentActivity');
        s = s.replaceAll('FlutterActivity()', 'FlutterFragmentActivity()');
        f.writeAsStringSync(s);
      }
      print('OK  MainActivity.kt');
    }
  }

  // 3. Gradle (supports build.gradle and build.gradle.kts)
  final kts = File(p('android/app/build.gradle.kts'));
  final groovy = File(p('android/app/build.gradle'));
  if (kts.existsSync()) {
    var s = kts.readAsStringSync();
    s = s.replaceAll(RegExp(r'minSdk\s*=\s*[^\n]+'), 'minSdk = 29');
    if (!s.contains('isCoreLibraryDesugaringEnabled')) {
      s = s.replaceFirst(RegExp(r'compileOptions\s*\{'), 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true');
    }
    if (!s.contains('desugar_jdk_libs')) {
      s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n';
    }
    kts.writeAsStringSync(s);
    print('OK  build.gradle.kts');
  } else if (groovy.existsSync()) {
    var s = groovy.readAsStringSync();
    s = s.replaceAll(RegExp(r'minSdk(Version)?\s*[= ]\s*[^\n]+'), 'minSdkVersion 29');
    if (!s.contains('coreLibraryDesugaringEnabled')) {
      s = s.replaceFirst(RegExp(r'compileOptions\s*\{'), 'compileOptions {\n        coreLibraryDesugaringEnabled true');
    }
    if (!s.contains('desugar_jdk_libs')) {
      s += '\ndependencies {\n    coreLibraryDesugaring \'com.android.tools:desugar_jdk_libs:2.1.4\'\n}\n';
    }
    groovy.writeAsStringSync(s);
    print('OK  build.gradle');
  } else {
    stderr.writeln('Could not find android/app/build.gradle(.kts)');
    exit(1);
  }
  print('\nDone. Now run: flutter pub get   then   flutter run');
}
