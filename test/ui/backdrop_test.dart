// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scythe_companion/data/notifications.dart';
import 'package:scythe_companion/pages/home.dart';
import 'package:scythe_companion/ui/backdrop.dart';

void main() {
  testWidgets('HomePage uses the shared ScytheBackdrop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Provider<NotificationService>.value(
          value: _NoopNotificationService(),
          child: const HomePage(),
        ),
      ),
    );

    expect(find.byType(ScytheBackdrop), findsOneWidget);
  });
}

class _NoopNotificationService extends NotificationService {
  @override
  Future<bool> requestPermission() async => true;
}
