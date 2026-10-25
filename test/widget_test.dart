import 'package:flutter_test/flutter_test.dart';
import 'package:pin_download/main.dart';
import 'package:pin_download/services/pinterest_service.dart';

void main() {
  testWidgets('Pin Downloader smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PinDownloadApp());
    expect(find.text('Pin Downloader'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Get Video'), findsOneWidget);
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
