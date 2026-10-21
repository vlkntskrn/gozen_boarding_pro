import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozen_boarding_pro/web_preview.dart';

void main() {
  testWidgets('preview boards a sample, blocks duplicate and wrong origin', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home:WebPreviewScreen(liveBuilder:(_)=>const Scaffold())));
    expect(find.text('Uçuş Seçimi'), findsOneWidget);
    await tester.tap(find.text('LS1730')); await tester.pumpAndSettle();
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

  testWidgets('flight selection isolates boarding and validates selected flight and date', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home:WebPreviewScreen(liveBuilder:(_)=>const Scaffold())));
    Future<void> validate() async {
      await tester.ensureVisible(find.text('Kartı Doğrula'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kartı Doğrula')); await tester.pumpAndSettle();
    }
    Future<void> dismiss() async {
      await tester.tap(find.text('Tamam')); await tester.pumpAndSettle();
    }
    Future<void> sample() async {
      await tester.ensureVisible(find.text('Örnek kart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Örnek kart')); await tester.pump();
    }
    Future<void> switchTo(String code) async {
      await tester.tap(find.text('Uçuş Değiştir')); await tester.pumpAndSettle();
      await tester.tap(find.text(code)); await tester.pumpAndSettle();
    }
    await tester.tap(find.text('LS1730')); await tester.pumpAndSettle();
    await sample();
    final lsCard = tester.widget<TextField>(find.byType(TextField).first).controller!.text;
    await validate();
    expect(find.text('PRE-BOARD SUCCESSFUL'), findsOneWidget);
    await dismiss();
    await switchTo('OR3057');
    await tester.enterText(find.byType(TextField).first, lsCard);
    await validate();
    expect(find.text('WRONG FLIGHT'), findsOneWidget);
    await dismiss();
    await sample();
    final orCard = tester.widget<TextField>(find.byType(TextField).first).controller!.text;
    await tester.enterText(find.byType(TextField).first, orCard.replaceRange(44, 47, '294'));
    await validate();
    expect(find.text('WRONG FLIGHT'), findsOneWidget);
    await dismiss();
    await sample(); await validate();
    expect(find.text('PRE-BOARD SUCCESSFUL'), findsOneWidget);
    await dismiss();
    await switchTo('LS1730');
    await sample(); await validate();
    expect(find.text('ALREADY BOARDED / DUPLICATE'), findsOneWidget);
  });
}
