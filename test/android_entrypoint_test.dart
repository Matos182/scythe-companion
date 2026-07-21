import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android launcher activity matches the application namespace', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    final namespace = RegExp(
      r'''namespace\s+["']([^"']+)["']''',
    ).firstMatch(gradle)!.group(1)!;
    final applicationId = RegExp(
      r'''applicationId\s+["']([^"']+)["']''',
    ).firstMatch(gradle)!.group(1)!;
    final activityName = RegExp(
      r'''<activity\b[^>]*android:name=["']([^"']+)["']''',
      dotAll: true,
    ).firstMatch(manifest)!.group(1)!;

    expect(applicationId, 'com.matos.scythe_companion');
    expect(namespace, applicationId);
    expect(activityName, startsWith('.'));

    final className = activityName.substring(1);
    final source = File(
      'android/app/src/main/kotlin/${namespace.replaceAll('.', '/')}/$className.kt',
    );
    expect(
      source.existsSync(),
      isTrue,
      reason:
          'The manifest launcher activity must exist under its package path.',
    );
    expect(
      source.readAsStringSync(),
      contains('package $namespace'),
      reason: 'The launcher activity package must match the Android namespace.',
    );
  });
}
