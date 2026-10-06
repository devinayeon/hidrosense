import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/main.dart';

void main() {
  testWidgets('Aplikasi membuka login tanpa data demo', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Benih Selada Grand Rapids'), findsNothing);
  });
}
