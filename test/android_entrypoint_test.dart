import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

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
    const androidNamespace = 'http://schemas.android.com/apk/res/android';
    final document = XmlDocument.parse(manifest);
    final launcherActivities = document
        .findAllElements('activity')
        .where(
          (activity) => activity
              .findElements('intent-filter')
              .any(
                (filter) =>
                    filter
                        .findElements('action')
                        .any(
                          (action) =>
                              action.getAttribute(
                                'name',
                                namespace: androidNamespace,
                              ) ==
                              'android.intent.action.MAIN',
                        ) &&
                    filter
                        .findElements('category')
                        .any(
                          (category) =>
                              category.getAttribute(
                                'name',
                                namespace: androidNamespace,
                              ) ==
                              'android.intent.category.LAUNCHER',
                        ),
              ),
        )
        .toList();

    expect(applicationId, 'com.matos.scythe_companion');
    expect(namespace, applicationId);
    expect(launcherActivities, hasLength(1));

    final activityName = launcherActivities.single.getAttribute(
      'name',
      namespace: androidNamespace,
    );
    expect(activityName, '.MainActivity');

    final className = activityName!.substring(1);
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
      matches(
        RegExp(
          '^[ \\t]*package[ \\t]+${RegExp.escape(namespace)}[ \\t]*;?[ \\t]*\$',
          multiLine: true,
        ),
      ),
      reason: 'The launcher activity package must match the Android namespace.',
    );
  });
}
