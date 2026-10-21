import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozen_boarding_pro/web_preview.dart';

void main() {
  testWidgets('preview boards a sample, blocks duplicate and wrong origin', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home:WebPreviewScreen(liveBuilder:(_)=>const Scaffold())));
    await tester.tap(find.text('Örnek kart')); await tester.pump();
    await tester.ensureVisible(find.text('Kartı Doğrula'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kartı Doğrula')); await tester.pumpAndSettle();
    expect(find.text('PRE-BOARD SUCCESSFUL'),findsOneWidget);
    await tester.tap(find.text('Tamam')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kartı Doğrula'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kartı Doğrula')); await tester.pumpAndSettle();
    expect(find.text('ALREADY BOARDED / DUPLICATE'),findsOneWidget);
    await tester.tap(find.text('Tamam')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Yanlış kalkış örneği'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yanlış kalkış örneği')); await tester.pump();
    await tester.ensureVisible(find.text('Kartı Doğrula'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kartı Doğrula')); await tester.pumpAndSettle();
    expect(find.text('WRONG FLIGHT'),findsOneWidget);
  });
}
