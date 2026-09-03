// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/pages/about.dart';
import 'package:scythe_companion/utils/strings.dart';

void main() {
  testWidgets('About states unofficial status, trademark, MIT, and privacy',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutPage()));

    expect(find.text(AboutStrings.appName), findsOneWidget);
    expect(find.text('Version ${AboutStrings.version}'), findsOneWidget);
    expect(find.text(AboutStrings.madeForFun), findsOneWidget);
    expect(find.text(AboutStrings.unofficial), findsOneWidget);
    expect(find.text(AboutStrings.trademark), findsOneWidget);
    expect(find.text(AboutStrings.noOfficialContent), findsOneWidget);
    expect(find.text(AboutStrings.license), findsOneWidget);
    expect(find.text(AboutStrings.sourceUrl), findsOneWidget);
    expect(find.text(AboutStrings.privacy), findsOneWidget);
    expect(find.text(AboutStrings.openSourceLicenses), findsOneWidget);

    expect(find.textContaining('official Scythe app'), findsNothing);
    expect(find.textContaining('endorsed by Stonemaier'), findsNothing);
  });
}
