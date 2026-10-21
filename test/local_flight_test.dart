import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozen_boarding_pro/boarding_validation.dart';
import 'package:gozen_boarding_pro/local_flight.dart';
import 'package:gozen_boarding_pro/flight_forms.dart';

const spec=FlightSpec('f1','LS196','2026-10-20','DLM','GLA');
BoardingPass pass({String name='SMITH/JOHN',String seat='1A',String seq='001',String dest='GLA'})=>BoardingPass(
 fullName:name,pnr:'ABC123',origin:'DLM',destination:dest,flightCode:'LS196',seat:seat,sequence:seq,travelDate:'2026-10-20');
String lpXml({String dest='GLA',String date='20 October 2026'})=>'''<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
<w:p><w:r><w:t>Flight Number: LS196 (DLM - $dest)</w:t></w:r></w:p><w:p><w:r><w:t>Flight Date &amp; Time: $date 22:05:00</w:t></w:r></w:p>
<w:tbl><w:tr>${['70','Mr','John Smith','Adult','1','ABC123','1'].map((s)=>'<w:tc><w:p><w:r><w:t>$s</w:t></w:r></w:p></w:tc>').join()}</w:tr></w:tbl>
</w:body></w:document>''';
List<int> zipXml(String xml){final a=Archive(),b=utf8.encode(xml);a.addFile(ArchiveFile('word/document.xml',b.length,b));return ZipEncoder().encode(a)!;}
void main(){
 test('route and date are exact, including destination',(){
  expect(spec.validate(pass()),isNull);expect(spec.validate(pass(dest:'MAN')),isNotNull);
  expect(spec.reportForm,'OPR-FRM-0011');
  expect(const FlightSpec('b','BA196','2026-10-20','DLM','LHR').reportForm,'OPR-FRM-0012');
  expect(const FlightSpec('b','BAW196','2026-10-20','DLM','LHR').reportForm,'OPR-FRM-0012');
 });
 test('LP imports table only and rejects wrong flight route or date',(){
  expect(parseLp(zipXml(lpXml()),spec).single.name,'John Smith');
  expect(()=>parseLp(zipXml(lpXml(dest:'MAN')),spec),throwsFormatException);
  expect(()=>parseLp(zipXml(lpXml(date:'21 October 2026')),spec),throwsFormatException);
 });
 test('durable local boarding survives restart; concurrent duplicate preserves original',() async {
  String? saved;
  final l=LocalFlight(spec,'agent',(s) async {saved=s;});
  final results=await Future.wait([l.board(pass(),random:false).then((_)=>true).catchError((_)=>false),
   l.board(pass(),random:true).then((_)=>true).catchError((_)=>false)]);
  expect(results.where((x)=>x).length,1);expect(l.passengers.single['status'],'PREBOARDED');
  final restart=LocalFlight(spec,'agent',(s)async{},saved:saved);
  expect(restart.passengers.length,1);expect(LocalFlight.validAudit(restart.snapshot),isTrue);
  final tampered=restart.snapshot;tampered['logs'][0]['action']='FORGED';
  expect(()=>LocalFlight(spec,'agent',(s)async{},saved:jsonEncode(tampered)),throwsFormatException);
 });
 test('combined Word LP isolates flight sections and requires PNR',(){
  final first=lpXml(),second=lpXml().replaceAll('LS196','LS164').replaceAll('John Smith','Other Passenger');
  String body(String xml)=>xml.substring(xml.indexOf('<w:body>')+8,xml.indexOf('</w:body>'));
  final both='<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${body(first)}${body(second)}</w:body></w:document>';
  expect(parseLp(zipXml(both),spec).single.name,'John Smith');
  expect(parseLp(zipXml(both),const FlightSpec('x','LS164','2026-10-20','DLM','GLA')).single.name,'Other Passenger');
  expect(()=>parseLp(zipXml(both),const FlightSpec('x','LS922','2026-10-20','DLM','MAN')),throwsFormatException);
  expect(lpPassengerMatches(pass(),const LpPassenger('John Smith','OTHER1','1')),isFalse);
 });
 test('LP matching supports joined names and securely bounded truncation',(){
  BoardingPass card(String name,String seq)=>BoardingPass(fullName:name,pnr:'ABC123',origin:'DLM',destination:'GLA',flightCode:'LS196',seat:'1A',sequence:seq);
  expect(lpPassengerMatches(card('SMITH/JOHNPAULMR','001'),const LpPassenger('John Paul Smith','ABC123','1')),isTrue);
  final truncated='WORTHINGTON/CHRISTOPHERJAMES'.substring(0,20);
  const lp=LpPassenger('Christopher James Worthington','ABC123','1');
  expect(lpPassengerMatches(card(truncated,'001'),lp),isTrue);
  expect(lpPassengerMatches(card(truncated,''),lp),isFalse);
  expect(lpPassengerMatches(card(truncated,'002'),lp),isFalse);
 });
 test('LP itself requires DFT even without manually adding a watchlist',()async{
  final l=LocalFlight(spec,'operator',(s)async{});await l.importLp(zipXml(lpXml()));
  await expectLater(l.board(pass(),random:false),throwsStateError);
  await l.board(pass(),random:true);expect(l.passengers.single['lp'],isTrue);
 });
 test('duplicate adult card can add one named linked infant without overwriting adult',()async{
  String? saved;
  final l=LocalFlight(spec,'first',(s)async{saved=s;});await l.board(pass(),random:false);
  final parent=l.passengers.single['id'];
  expect(l.duplicateFor(pass())!['id'],parent);
  await expectLater(l.board(pass(),random:true,adultId:parent),throwsStateError);
  await l.board(pass(name:'SMITH/BABY'),random:false,adultId:parent);
  expect(l.passengers.length,2);expect(l.passengers.first['name'],'SMITH/JOHN');
  expect(l.passengers.first['status'],'PREBOARDED');expect(l.passengers.last['adultId'],parent);
  expect(l.passengers.last['infant'],isTrue);
  await expectLater(l.board(pass(name:'SMITH/OTHERBABY'),random:false,adultId:parent),throwsStateError);
  final reopened=LocalFlight(spec,'second',(s)async{},saved:saved);await reopened.offload(parent);
  expect(reopened.passengers.every((p)=>p['status']=='OFFLOADED'),isTrue);
  expect(LocalFlight.validAudit(reopened.snapshot),isTrue);
 });
 test('failed persistence never reports boarding complete',()async{
  final l=LocalFlight(spec,'agent',(s)async{throw StateError('disk full');});
  await expectLater(l.board(pass(),random:false),throwsStateError);expect(l.passengers,isEmpty);
 });
 test('offload and reboard retain completed search details for the form',()async{
  final l=LocalFlight(spec,'agent',(s)async{});
  await l.board(pass(),random:true);final id=l.passengers.single['id'];
  await l.searchDetails(id,'GBR','SEARCH COMPLETED');await l.offload(id);
  await l.board(pass(),random:false);
  expect(l.passengers.single['searched'],isTrue);
  expect(l.passengers.single['nationality'],'GBR');
  expect(l.passengers.single['remarks'],'SEARCH COMPLETED');
 });
 test('LP badge watchlist DFT only and adult infant offload',()async{
  final l=LocalFlight(spec,'agent',(s)async{});
  await l.importLp(zipXml(lpXml()));await l.setWatchlist(['JOHN SMITH']);
  await expectLater(l.board(pass(),random:false),throwsStateError);
  await l.board(pass(),random:true);expect(l.passengers.single['lp'],isTrue);
  await expectLater(l.board(pass(name:'SMITH/BABY',seq:'002'),random:false),throwsStateError);
  await l.board(pass(name:'SMITH/BABY',seq:'002'),random:false,adultId:l.passengers.first['id']);
  await l.offload(l.passengers.first['id']);expect(l.passengers.every((p)=>p['status']=='OFFLOADED'),isTrue);
  expect(l.passengers.first['searched'],isTrue);
  await l.close();await expectLater(l.board(pass(seq:'003'),random:false),throwsStateError);
 });
 test('forms preserve supplied templates, names LP and no signatures',()async{
  final l=LocalFlight(spec,'agent',(s)async{});await l.importLp(zipXml(lpXml()));await l.board(pass(),random:true);
  await l.searchDetails(l.passengers.single['id'],'GBR','TEST SEARCH / LP');
  await l.saveFields({'searchTl':'TEST TEAM LEADER','airlineRep':'TEST AIRLINE REPRESENTATIVE',
   'agent1':'TEST AGENT ONE','agent2':'TEST AGENT TWO','agent3':'TEST AGENT THREE','agent4':'TEST AGENT FOUR',
   'staff':'TEST SECURITY ONE | RAMP','G9':'B737','E13':'A320','G18':'TEST OPERATION','L24':'TEST BA OPERATION'});
  final word=searchForm(File('assets/forms/search.docx').readAsBytesSync(),spec,l.snapshot);
  final xml=utf8.decode(ZipDecoder().decodeBytes(word).findFile('word/document.xml')!.content as List<int>);
  expect(xml,contains('SMITH/JOHN LP'));expect(xml,contains('Passenger'));
  final original=ZipDecoder().decodeBytes(File('assets/forms/search.docx').readAsBytesSync());
  final generated=ZipDecoder().decodeBytes(word);
  for(final entry in original.files.where((f)=>f.name.startsWith('word/footer') || f.name.startsWith('word/header'))) {
   expect(generated.findFile(entry.name)!.content,entry.content);
  }
  final report=dailyForm(File('assets/forms/daily.xlsx').readAsBytesSync(),spec,l.snapshot);
  final sheet=utf8.decode(ZipDecoder().decodeBytes(report).findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
  expect(sheet,contains('LS196'));expect(sheet,contains('2026-10-20'));
  final ba=const FlightSpec('b','BA196','2026-10-20','DLM','LHR');
  final baReport=dailyForm(File('assets/forms/ba.xlsx').readAsBytesSync(),ba,l.snapshot);
  final baXml=utf8.decode(ZipDecoder().decodeBytes(baReport).findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
  expect(baXml,contains('BA196'));
  expect(XmlDocument.parse(baXml).findAllElements('c').firstWhere((c)=>c.getAttribute('r')=='E25').innerText,'TEST SECURITY ONE');
  // Synthetic-only outputs for print-layout QA in CI.
  Directory('build/form-qa').createSync(recursive:true);
  File('build/form-qa/search.docx').writeAsBytesSync(word);
  File('build/form-qa/daily.xlsx').writeAsBytesSync(report);
  File('build/form-qa/ba.xlsx').writeAsBytesSync(baReport);
 });
 test('sixteen searched passengers create two complete forms without duplicate drawing IDs',()async{
  final l=LocalFlight(spec,'agent',(s)async{});
  for(var i=0;i<16;i++) {
   await l.board(pass(name:'SYNTHETIC/PAX${String.fromCharCode(65+i)}',seat:'${i+1}A',seq:'${i+1}'),random:true);
  }
  final bytes=searchForm(File('assets/forms/search.docx').readAsBytesSync(),spec,l.snapshot);
  final xml=XmlDocument.parse(utf8.decode(ZipDecoder().decodeBytes(bytes).findFile('word/document.xml')!.content as List<int>));
  expect(xml.findAllElements('w:tbl').length,2);
  expect(xml.findAllElements('w:t').where((e)=>e.innerText.contains('PASSENGER CONTINUOUS & RANDOM SEARCH')).length,2);
  expect(xml.findAllElements('w:t').where((e)=>e.innerText.contains('OPR-FRM-0098')).length,2);
  final ids=xml.findAllElements('wp:docPr').map((e)=>e.getAttribute('id')).toList();
  expect(ids.toSet().length,ids.length);
  final names=xml.findAllElements('w:t').map((e)=>e.innerText).join(' ');
  for(var i=0;i<16;i++) {expect(names,contains('${i+1}) SYNTHETIC/PAX${String.fromCharCode(65+i)}'));}
  Directory('build/form-qa').createSync(recursive:true);
  File('build/form-qa/search_many.docx').writeAsBytesSync(bytes);
 });
}
