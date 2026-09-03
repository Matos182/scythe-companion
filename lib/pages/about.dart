// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../ui/backdrop.dart';
import '../ui/panel_card.dart';
import '../ui/theme.dart';
import '../utils/strings.dart';

/// Credits, privacy, and legal notices. Nested under Settings so back
/// returns to the options screen. Copy lives in [AboutStrings].
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    const dim = TextStyle(
      color: ScytheColors.parchmentDim,
      fontSize: 13,
      height: 1.4,
    );
    const body = TextStyle(
      color: ScytheColors.parchment,
      fontSize: 14,
      height: 1.45,
    );

    return Scaffold(
      appBar: AppBar(title: const Text(AboutStrings.title)),
      body: ScytheBackdrop(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    AboutStrings.appName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Version ${AboutStrings.version}',
                    style: dim,
                  ),
                  const SizedBox(height: 16),
                  const _SectionTitle(AboutStrings.sectionThisApp),
                  const Text(AboutStrings.madeForFun, style: body),
                  const SizedBox(height: 12),
                  const Text(AboutStrings.whatItDoes, style: body),
                  const SizedBox(height: 20),
                  const _SectionTitle(AboutStrings.sectionLegal),
                  const Text(AboutStrings.unofficial, style: body),
                  const SizedBox(height: 12),
                  const Text(AboutStrings.trademark, style: body),
                  const SizedBox(height: 12),
                  const Text(AboutStrings.noOfficialContent, style: body),
                  const SizedBox(height: 12),
                  const Text(AboutStrings.license, style: body),
                  const SizedBox(height: 12),
                  const Text(AboutStrings.scoringDisclaimer, style: body),
                  const SizedBox(height: 12),
                  const Text(AboutStrings.sourceLabel, style: dim),
                  const SelectableText(AboutStrings.sourceUrl, style: body),
                  const SizedBox(height: 20),
                  const _SectionTitle(AboutStrings.sectionPrivacy),
                  const Text(AboutStrings.privacy, style: body),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: AboutStrings.appName,
                        applicationVersion: AboutStrings.version,
                        applicationLegalese: AboutStrings.legalese,
                      );
                    },
                    child: const Text(AboutStrings.openSourceLicenses),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: ScytheColors.brass,
        ),
      ),
    );
  }
}
