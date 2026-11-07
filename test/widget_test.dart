import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pin_download/branding/omnix_brand.dart';
import 'package:pin_download/services/pinterest_service.dart';

void main() {
  testWidgets('OMNIX brand smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(OmnixBrand.name),
                Text(OmnixBrand.tagline),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text(OmnixBrand.name), findsOneWidget);
    expect(find.text(OmnixBrand.tagline), findsOneWidget);
  });

  group('PinterestService URL parsing tests', () {
    test('extracts direct pin.it URL', () {
      const input = 'https://pin.it/5uY4aBC';
      expect(PinterestService.extractUrl(input), 'https://pin.it/5uY4aBC');
    });

    test('extracts URL from raw shared text from Pinterest app', () {
      const input =
          'Hey check this out on Pinterest! https://www.pinterest.com/pin/123456789/ cool right?';
      expect(PinterestService.extractUrl(input),
          'https://www.pinterest.com/pin/123456789/');
    });

    test('returns null for non-url text', () {
      const input = 'just some random text with no links';
      expect(PinterestService.extractUrl(input), isNull);
    });
  });
}
