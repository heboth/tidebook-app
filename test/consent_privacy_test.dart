import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidebook_app/screens/site_page_screen.dart';
import 'package:tidebook_app/services/site_links.dart';
import 'package:tidebook_app/services/texts_service.dart';

// GDPR: privatlivspolitikken og rejsebetingelserne hentes fra bookingsitet; teksterne til samtykke findes i den
// indbyggede pakke, så de kan rettes i TideCMS (pakken 'tidebookapp').
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bundled = jsonDecode(File('assets/i18n/da.json').readAsStringSync()) as Map<String, dynamic>;
  setUp(() => TextsService.instance.load(bundled));

  test('links peger på bookingsitets privatlivs- og betingelsesside (dev-adresse uden define)', () {
    expect(SiteLinks.privacyPolicy.toString(), endsWith('/?view=privatliv'));
    expect(SiteLinks.terms.toString(), endsWith('/?view=betingelser'));
    expect(SiteLinks.marketingConsentVersion, 'marketing-v1');
  });

  test('samtykke- og privatlivstekster findes i den indbyggede pakke', () {
    for (final key in [
      'bookingWizard.consent.termsAccept',
      'bookingWizard.consent.readTerms',
      'bookingWizard.consent.termsRequired',
      'bookingWizard.consent.marketing',
      'bookingWizard.consent.marketingHint',
      'bookingWizard.consent.privacyLink',
      'legal.privacyPolicy',
      'legal.privacyPolicySubtitle',
      'legal.terms',
      'legal.unavailable',
    ]) {
      expect(tr(key), isNot(key), reason: key);
    }
    expect(tr('bookingWizard.consent.marketing'), 'Ja tak, send mig tilbud og nyheder på e-mail');
  });

  testWidgets('punktet "Privatlivspolitik" vises', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PrivacyPolicyTile())));
    expect(find.text('Privatlivspolitik'), findsOneWidget);
    expect(find.byKey(const Key('privacy-policy-tile')), findsOneWidget);
  });
}
