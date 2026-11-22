import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/main.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_onboarding_page.dart';

void main() {
  testWidgets('Aplikasi membuka login tanpa data demo', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    expect(find.byType(V2OnboardingPage), findsOneWidget);
    expect(find.text('Benih Selada Grand Rapids'), findsNothing);
  });
}
