import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'boarding_validation.dart';
import 'local_flight.dart';
import 'flight_forms.dart';
import 'flight_local_storage.dart';
import 'ocr_adapter.dart';

class LocalOperationsScreen extends StatefulWidget {
 final String flightId;
 const LocalOperationsScreen({super.key,required this.flightId});
 @override State<LocalOperationsScreen> createState()=>_LocalOperationsScreenState();
}
class _LocalOperationsScreenState extends State<LocalOperationsScreen> {
 final storage=FlightLocalStorage(),raw=TextEditingController();
 final scanner=MobileScannerController(formats:const [BarcodeFormat.qrCode,BarcodeFormat.pdf417,BarcodeFormat.aztec,BarcodeFormat.dataMatrix]);
 late final ref=FirebaseFirestore.instance.collection('flights').doc(widget.flightId);
 String get uid=>FirebaseAuth.instance.currentUser!.uid;
 Map<String,dynamic>? metadata;
 LocalFlight? ledger;
 String? error;
 bool busy=false,camera=true,random=false,recorder=false;
 int tab=0;
 @override void initState(){super.initState();load();}
 @override void dispose(){scanner.dispose();raw.dispose();super.dispose();}
 Future<void> load() async {
  try {
   final f=(await ref.get(const GetOptions(source:Source.server))).data();
   if(f==null) throw StateError('Uçuş bulunamadı.');
   metadata=f;
   if(!kIsWeb) {
    recorder=f['recordingDeviceHash']==await storage.deviceId() && f['recordingUid']==uid;
    if(recorder) {
     final spec=FlightSpec(widget.flightId,f['flightCode'],f['etdDateText'],f['departureAirport'],f['arrivalAirport']??'');
     ledger=LocalFlight(spec,uid,(value)=>storage.write(widget.flightId,value),saved:await storage.read(widget.flightId));
     await ledger!.log('FLIGHT_OPENED');
    }
   }
  } catch(e) {error='$e';}
  if(mounted) setState((){});
 }
 Future<void> authorize({bool allowClosed=false}) async {
  // Fail closed on revoked assignment, wrong device or stale/offline metadata.
  final f=(await ref.get(const GetOptions(source:Source.server))).data();
  if(f==null || f['recordingDeviceHash']!=await storage.deviceId() || f['recordingUid']!=uid || (!allowClosed && f['closed']==true)) {
   throw StateError('Kayıt telefonu yetkisi yok veya uçuş kapalı.');
  }
  metadata=f;
 }
 Future<void> run(Future<void> Function() fn) async {
  if(busy) return;
  setState(()=>busy=true);
  try {await fn();} catch(e) {
   if(ledger!=null) {try {await ledger!.log('OPERATION_FAILED');} catch(_) {}}
   if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
  } finally {if(mounted) setState(()=>busy=false);}
 }
 Future<void> claim() async {
  final device=await storage.deviceId();
  await FirebaseFirestore.instance.runTransaction((tx) async {
   final f=(await tx.get(ref)).data();
   if(f==null || f['closed']==true || (f['recordingDeviceHash']??'')!='') throw StateError('Bu uçuş başka telefona bağlı veya kapalı.');
   if(!RegExp(r'^[A-Z]{3}$').hasMatch(f['arrivalAirport']??'')) throw StateError('Admin varış havalimanını tanımlamalı.');
   tx.update(ref,{'recordingDeviceHash':device,'recordingUid':uid});
   tx.set(ref.collection('logs').doc(),{'type':'RECORDER_CLAIMED','byUid':uid,'at':FieldValue.serverTimestamp()});
  });
  await load();
 }
 Future<void> result(Color color,String title,String detail) async {
  if(!mounted) return;
  await showDialog<void>(context:context,barrierDismissible:false,builder:(ctx)=>Dialog.fullscreen(
   child:ColoredBox(color:color,child:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Text(title,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.bold)),
    const SizedBox(height:18),Text(detail,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white)),
    FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Tamam')),
   ]))))));
 }
 Future<void> scan(String text) async {
  await authorize();
  final l=ledger!;
  try {
   final legs=parseBcbp(text),hits=legs.where((p)=>l.spec.validate(p)==null).toList();
   if(hits.length!=1) {
    await l.log('SCAN_REJECTED:FLIGHT_DATE_ROUTE');
    await result(Colors.purple,'WRONG FLIGHT','Uçuş numarası, tarih, kalkış veya varış eşleşmiyor.');return;
   }
   final p=hits.single;
   final seated=l.passengers.where((x)=>x['seat']==p.seat && ['PREBOARDED','DFT_BOARDED'].contains(x['status'])).toList();
   String? adult;
   if(seated.isNotEmpty && !seated.any((x)=>watchlistMatches(p.fullName,x['name']))) {
    if(!mounted) return;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Aynı koltukta yetişkin / infant'),
     content:Text('${seated.first['name']} ile aynı koltuk. Yeni kartın bağlı infant olduğunu doğruladınız mı?'),
     actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Vazgeç')),
      FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Infant olarak bağla'))]));
    if(ok!=true) {await l.log('INFANT_LINK_CANCELLED');return;}adult=seated.first['id'];
   }
   await authorize();
   await l.board(p,random:random,adultId:adult);
   final watch=(l.snapshot['watchlist'] as List).any((n)=>watchlistMatches(p.fullName,n.toString()));
   await result(watch?Colors.red:random?Colors.blue:Colors.green,
    watch?'FLY PASSENGER ATTENTION!!!':random?'DFT RANDOM SUCCESSFUL':'PRE-BOARD SUCCESSFUL',
    '${p.fullName} • ${p.seat}');
  } on FormatException catch(e) {
   await l.log('SCAN_UNREADABLE');await result(Colors.blueGrey,'KART DOĞRULANAMADI',e.message);
  } on StateError catch(e) {
   await l.log(e.message=='FLY PASSENGER ATTENTION!!!'?'WATCHLIST_BLOCKED':'BOARDING_BLOCKED');
   await result(e.message=='FLY PASSENGER ATTENTION!!!'?Colors.red:Colors.grey,e.message.toString(),'Kayıt eklenmedi.');
  }
 }
 Future<Map<String,String>?> fieldsDialog(String title,Map<String,String> labels,Map<String,dynamic> values) async {
  final controllers={for(final key in labels.keys) key:TextEditingController(text:'${values[key]??''}')};
  final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(title),
   content:SizedBox(width:600,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    for(final e in labels.entries) Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:controllers[e.key],
     minLines:1,maxLines:4,decoration:InputDecoration(labelText:e.value))),
   ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Vazgeç')),
    FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Kaydet'))]));
  final value=ok==true?{for(final e in controllers.entries)e.key:e.value.text.trim()}:null;
  for(final c in controllers.values){c.dispose();} return value;
 }
 Future<void> manual() async {
  final v=await fieldsDialog('Manuel doğrulama',const {'name':'SOYAD/AD','pnr':'PNR','seat':'Koltuk','sequence':'Güvenlik numarası',
   'code':'Karttaki uçuş kodu','date':'Karttaki tarih YYYY-MM-DD','origin':'Karttaki kalkış IATA','destination':'Karttaki varış IATA'},{});
  if(v==null) return;await authorize();
  final p=BoardingPass(fullName:v['name']!.toUpperCase(),pnr:v['pnr']!.toUpperCase(),seat:normalizeSeat(v['seat']!),
   sequence:v['sequence']!,flightCode:v['code']!.toUpperCase(),travelDate:v['date'],origin:v['origin']!.toUpperCase(),destination:v['destination']!.toUpperCase());
  final problem=ledger!.spec.validate(p);
  if(problem!=null) {await ledger!.log('MANUAL_REJECTED');await result(Colors.purple,'WRONG FLIGHT',problem);return;}
  if(!p.fullName.contains('/') || p.fullName.split('/').any((s)=>s.trim().isEmpty)) {
   throw const FormatException('Ad SOYAD/AD biçiminde doğrulanmalı.');
  }
  try {
   await ledger!.log('MANUAL_VERIFICATION');
   await ledger!.board(p,random:random);
   final watch=(ledger!.snapshot['watchlist'] as List).any((n)=>watchlistMatches(p.fullName,n.toString()));
   await result(watch?Colors.red:random?Colors.blue:Colors.green,
    watch?'FLY PASSENGER ATTENTION!!!':random?'DFT RANDOM SUCCESSFUL':'PRE-BOARD SUCCESSFUL',p.fullName);
  } on StateError catch(e) {
   await ledger!.log('MANUAL_BLOCKED');
   await result(e.message=='FLY PASSENGER ATTENTION!!!'?Colors.red:Colors.grey,e.message.toString(),'Kayıt eklenmedi.');
  }
 }
 Future<void> importLp() async {
  final pick=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['docx'],withData:true);
  if(pick==null) return;await authorize();
  final bytes=pick.files.single.bytes;
  if(bytes==null) throw StateError('Dosya okunamadı.');
  await ledger!.importLp(bytes);
 }
 Future<void> ocrAssist() async {
  final ocr=OcrAdapter();
  try {
   final text=await ocr.captureText();
   if(text==null || !mounted) return;
   await ledger!.log('OCR_ASSIST_OPENED');
   await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('OCR yardımcı okuma'),
    content:SingleChildScrollView(child:Text('$text\n\nMetni kartla karşılaştırın. Sonraki ekranda uçuş, tarih ve iki havalimanını ayrı girin.')),
    actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Manuel doğrulamaya geç'))]));
   await manual();
  } finally {ocr.close();}
 }
 Future<void> csv() async {
  await authorize(allowClosed:true);
  String cell(dynamic v)=>'"${v.toString().replaceAll('"','""')}"';
  final text=['NAME,PNR,SEAT,SEQUENCE,STATUS,LP',...ledger!.passengers.map((p)=>
   [p['name'],p['pnr'],p['seat'],p['sequence'],p['status'],p['lp']==true?'LP':''].map(cell).join(','))].join('\r\n');
  final name='${ledger!.spec.code}_LOCAL.csv';
  await ledger!.log('CSV_EXPORTED');
  await Share.shareXFiles([XFile.fromData(Uint8List.fromList(utf8.encode('\uFEFF$text')),mimeType:'text/csv',name:name)],fileNameOverrides:[name]);
 }
 Future<Map<String,List<int>>> reports() async {
  final l=ledger!,base=l.spec.reportForm=='OPR-FRM-0012'?'ba':'daily';
  if(l.closed && l.snapshot['reports']!=null) {
   return Map<String,dynamic>.from(l.snapshot['reports']).map((k,v)=>MapEntry(k,base64Decode(v)));
  }
  final word=await rootBundle.load('assets/forms/search.docx'),xls=await rootBundle.load('assets/forms/$base.xlsx');
  return {'OPR-FRM-0098_${l.spec.code}.docx':searchForm(word.buffer.asUint8List(),l.spec,l.snapshot),
   '${l.spec.reportForm}_${l.spec.code}.xlsx':dailyForm(xls.buffer.asUint8List(),l.spec,l.snapshot)};
 }
 Future<void> export() async {
  await authorize(allowClosed:true);
  final files=await reports();await ledger!.log('REPORTS_EXPORTED');
  await Share.shareXFiles(files.entries.map((e)=>XFile.fromData(Uint8List.fromList(e.value),name:e.key)).toList(),fileNameOverrides:files.keys.toList());
 }
 Future<void> sendMail({bool useComposer=false}) async {
  await authorize(allowClosed:true);
  if(!ledger!.closed) throw StateError('Önce uçuşu kapatın.');
  final files=await reports();
  if(useComposer) {
   final paths=await storage.exportFiles(widget.flightId,files);
   await storage.compose(List<String>.from(metadata!['reportRecipients']??[]),'${ledger!.spec.code} ${ledger!.spec.date} Uçuş Raporları',paths);
   await ledger!.mailOpened();return;
  }
  await ledger!.log('MAIL_SEND_REQUESTED');
  try {
   final response=await FirebaseFunctions.instance.httpsCallable('sendFlightClosure').call({
    'flightId':widget.flightId,'files':files.entries.map((e)=>{'name':e.key,'base64':base64Encode(e.value)}).toList()});
   if(response.data['status']!='ACCEPTED') throw StateError('Gönderim doğrulanamadı.');
   await ledger!.change('MAIL_ACCEPTED_BY_SERVER',(d)=>d['mail']='ACCEPTED',afterClose:true);
  } catch(_) {
   await ledger!.log('MAIL_SEND_UNCONFIRMED');
   throw StateError('Otomatik e-posta gönderimi doğrulanamadı. Yerel raporlar korundu. Servis kurulumu/bağlantıyı kontrol edin veya E-posta uygulamasında aç seçeneğini kullanın.');
  }
 }
 Future<void> closeFlight() async {
  await authorize();
  if((metadata!['reportRecipients'] as List? ?? []).isEmpty) throw StateError('Admin rapor alıcılarını tanımlamalı.');
  if(!mounted) return;
  final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Uçuşu kapat'),
   content:Text('Arama formu ve ${ledger!.spec.reportForm} hazırlanacak. Yeni boarding duracak. E-posta alıcıları: ${(metadata!['reportRecipients'] as List).join(', ')}'),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Vazgeç')),
    FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Kapat ve gönder'))]));
  if(ok!=true) return;
  final frozen=await reports(); // Freeze exact bytes for idempotent delivery retries.
  await ledger!.change('REPORTS_FINALIZED',(d)=>d['reports']=frozen.map((k,v)=>MapEntry(k,base64Encode(v))));
  await ledger!.close();
  await finalizeClosure();
  await sendMail();
 }
 Future<void> finalizeClosure() async {
  await authorize(allowClosed:true);
  if(metadata!['closed']==true) return;
  final batch=FirebaseFirestore.instance.batch();
  batch.update(ref,{'closed':true,'closedAt':FieldValue.serverTimestamp()});
  batch.set(ref.collection('logs').doc(),{'type':'FLIGHT_CLOSED','byUid':uid,'at':FieldValue.serverTimestamp()});await batch.commit();
 }
 Widget page(List<Widget> children)=>ListView(padding:const EdgeInsets.all(16),children:children);
 @override Widget build(BuildContext context) {
  final f=metadata,l=ledger;
  if(error!=null) return Scaffold(appBar:AppBar(title:const Text('Uçuş')),body:Center(child:Text(error!)));
  if(f==null) return const Scaffold(body:Center(child:CircularProgressIndicator()));
  if(!recorder || l==null) return Scaffold(appBar:AppBar(title:Text('${f['flightCode']} • Uçuş Bilgisi')),
   body:page([Text('${f['departureAirport']} → ${f['arrivalAirport']??'Varış tanımsız'} • ${f['etdDateText']}'),
    Text(f['closed']==true?'KAPALI':'AÇIK'),const Text('Yolcu listesi kayıt telefonunda tutulur; diğer telefonlardan veya webden görüntülenmez.'),
    if(kIsWeb) const Text('Kayıt telefonu olarak Android uygulamasını kullanın.')
    else if((f['recordingDeviceHash']??'')=='' && f['closed']!=true)
     FilledButton(onPressed:busy?null:()=>run(claim),child:const Text('Bu telefonu kayıt telefonu yap'))
    else const Text('Bu uçuş başka kayıt telefonu/kullanıcısına bağlı. Buradan yolcu işlemi yapılamaz.'),
   ]));
  final pax=l.passengers;
  final labels=<String,String>{...commonFields,...(l.spec.reportForm=='OPR-FRM-0012'?baFields:dailyFields)};
  return Scaffold(appBar:AppBar(title:Text('${l.spec.code} • ${l.spec.origin} → ${l.spec.destination}')),
   bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [
    NavigationDestination(icon:Icon(Icons.qr_code_scanner),label:'Scan'),NavigationDestination(icon:Icon(Icons.people),label:'Yolcular'),
    NavigationDestination(icon:Icon(Icons.assignment),label:'Operasyon'),NavigationDestination(icon:Icon(Icons.history),label:'Log / Rapor')]),
   body:Column(children:[
    MaterialBanner(content:Text('${l.spec.date} • ${l.closed?'KAPALI':'AÇIK'} • ${pax.length} kayıt • Yalnız bu telefon\nMail: ${l.snapshot['mail']}'),actions:const [SizedBox.shrink()]),
    if(busy) const LinearProgressIndicator(),
    Expanded(child:[
     page([
      if(camera && !l.closed && !kIsWeb && tab==0) SizedBox(height:240,child:MobileScanner(controller:scanner,onDetect:(capture){
       if(busy) return;final text=capture.barcodes.firstOrNull?.rawValue;if(text!=null) run(()=>scan(text));
      })),
      Wrap(spacing:8,children:[TextButton(onPressed:()=>setState(()=>camera=!camera),child:Text(camera?'Kamerayı kapat':'Kamerayı aç')),
       TextButton(onPressed:camera?()=>run(()=>scanner.toggleTorch()):null,child:const Text('Fener'))]),
      TextField(controller:raw,maxLines:3,decoration:const InputDecoration(labelText:'BCBP metni (boşlukları koru)')),
      SwitchListTile(title:const Text('DFT Random'),value:random,onChanged:(v)=>setState(()=>random=v)),
      FilledButton(onPressed:busy||l.closed?null:()=>run(()=>scan(raw.text)),child:const Text('Kartı Doğrula')),
      TextButton(onPressed:busy||l.closed?null:()=>run(manual),child:const Text('Güvenli manuel giriş')),
      if(!kIsWeb) TextButton(onPressed:busy||l.closed?null:()=>run(ocrAssist),child:const Text('OCR destekli manuel doğrulama')),
     ]),
     page([
      FilledButton(onPressed:busy||l.closed?null:()=>run(importLp),child:const Text('LP dosyası yükle (.docx)')),
      Text('${(l.snapshot['lp'] as List).length} LP kaydı'),
      for(final p in pax) ListTile(title:Text('${p['name']}${p['lp']==true?'  LP':''}'),subtitle:Text('${p['seat']} • ${p['sequence']} • ${p['status']}'),
       onTap:busy||l.closed?null:()=>run(() async {
        final v=await fieldsDialog('Arama bilgileri',const {'nationality':'Tabiiyet','remarks':'Notlar'},p);
        if(v!=null){await authorize();await l.searchDetails(p['id'],v['nationality']!,v['remarks']!);}
       }),trailing:TextButton(onPressed:busy||l.closed||p['status']=='OFFLOADED'?null:()=>run(() async {
        final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Offload'),
         content:const Text('Yolcu ve varsa bağlı infant birlikte offload edilecek.'),actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Vazgeç')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Offload'))]));
        if(ok==true){await authorize();await l.offload(p['id']);}
       }),child:const Text('Offload'))),
     ]),
     page([
      Text('Uçuş raporu: ${l.spec.reportForm}'),
      FilledButton(onPressed:busy||l.closed?null:()=>run(() async {
       final v=await fieldsDialog('Personel, ekipman, saatler ve rapor',labels,Map<String,dynamic>.from(l.snapshot['fields']));
       if(v!=null){await authorize();await l.saveFields(v);}
      }),child:const Text('Operasyon bilgilerini düzenle')),
      FilledButton(onPressed:busy||l.closed?null:()=>run(() async {
       final v=await fieldsDialog('Yerel Watchlist',const {'names':'Her satıra bir SOYAD/AD'},
        {'names':(l.snapshot['watchlist'] as List).join('\n')});
       if(v!=null){await authorize();await l.setWatchlist(v['names']!.split('\n').where((s)=>s.trim().isNotEmpty).toList());}
      }),child:const Text('Watchlist düzenle')),
      const Text('İmzalar dijital olarak üretilmez. Arama formundaki imza alanları çıktı üzerinde tamamlanmalıdır.'),
     ]),
     page([
      FilledButton(onPressed:busy?null:()=>run(export),child:const Text('Arama Formu + Daily Flight Report')),
      TextButton(onPressed:busy?null:()=>run(csv),child:const Text('Yerel yolcu CSV raporu')),
      FilledButton(onPressed:busy||l.closed?null:()=>run(closeFlight),child:const Text('Uçuşu Kapat ve E-posta Gönder')),
      if(l.closed) ...[
       TextButton(onPressed:busy?null:()=>run(() async {await finalizeClosure();await sendMail();}),child:const Text('Kapanış / Gönderimi yeniden dene')),
       TextButton(onPressed:busy?null:()=>run(()=>sendMail(useComposer:true)),child:const Text('E-posta uygulamasında aç (Gönder düğmesine basılmalı)')),
      ],
      const Text('Aşağıdaki geçmiş yalnız bu telefonda tutulur. E-posta uygulamasının açılması teslim onayı değildir.'),
      for(final event in (l.snapshot['logs'] as List).reversed) ListTile(title:Text(event['action']),subtitle:Text('${event['at']} • ${event['actor']}')),
     ]),
    ][tab]),
   ]));
 }
}
