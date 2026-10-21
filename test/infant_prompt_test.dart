import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozen_boarding_pro/field_test_screen.dart';

void main(){
 testWidgets('local field-test entry has real flight choices without requesting a Firebase account',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:FieldTestScreen()));
  expect(find.text('GOZEN • Android Saha Testi'),findsOneWidget);
  expect(find.textContaining('Admin hesabı oluşturmaz'),findsOneWidget);
  expect(find.text('LS164 • DLM–GLA'),findsOneWidget);
  await tester.scrollUntilVisible(find.text('Test uçuşunu aç / kaldığı yerden devam et'),200,
   scrollable:find.byType(Scrollable).first);
  expect(find.text('Test uçuşunu aç / kaldığı yerden devam et'),findsOneWidget);
 });
}
