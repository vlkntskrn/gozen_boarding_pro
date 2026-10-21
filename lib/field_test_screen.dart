import 'package:flutter/material.dart';
import 'boarding_validation.dart';
import 'local_flight.dart';
import 'local_operations_screen.dart';

/// Only selected in an APK built with --dart-define=FIELD_TEST=true.
/// Uses a separate local flight ID prefix and never authenticates/writes Firebase.
class FieldTestScreen extends StatefulWidget {
 const FieldTestScreen({super.key});
 @override State<FieldTestScreen> createState()=>_FieldTestScreenState();
}
class _FieldTestScreenState extends State<FieldTestScreen> {
 final code=TextEditingController(text:'LS164'),date=TextEditingController(text:'2026-10-21'),
  origin=TextEditingController(text:'DLM'),dest=TextEditingController(text:'GLA'),actor=TextEditingController(text:'TEST_OPERATOR');
 String? error;
 @override void dispose(){for(final c in [code,date,origin,dest,actor]){c.dispose();}super.dispose();}
 void open(){
  final flight=normalizeFlightCode(code.text),from=origin.text.trim().toUpperCase(),to=dest.text.trim().toUpperCase();
  if(flight.isEmpty||strictDate(date.text)==null||!RegExp(r'^[A-Z]{3}$').hasMatch(from)||
    !RegExp(r'^[A-Z]{3}$').hasMatch(to)||from==to||actor.text.trim().isEmpty){setState(()=>error='Uçuş, tarih, rota ve işlem yapan bilgisini kontrol edin.');return;}
  final id='fieldtest-$flight-${date.text}-$from-$to';
  Navigator.push(context,MaterialPageRoute(builder:(_)=>LocalOperationsScreen(flightId:id,
   localTestFlight:FlightSpec(id,flight,date.text,from,to),localTestActor:actor.text.trim())));
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('GOZEN • Android Saha Testi')),
  body:ListView(padding:const EdgeInsets.all(20),children:[
   const Text('Kamera, Word LP, infant, yerel kayıt ve rapor testi',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
   const SizedBox(height:12),
   const Text('Bu sürüm cihazda test içindir. Admin hesabı oluşturmaz. Firebase dashboard ve otomatik kurumsal e-posta bağlantısı içermez. Kayıtlar bu telefonda şifreli kalır; uygulamayı kaldırınca kaybolabilir.'),
   const SizedBox(height:16),
   DropdownButtonFormField<String>(initialValue:'LS164',decoration:const InputDecoration(labelText:'Hızlı uçuş seçimi'),
    items:const [DropdownMenuItem(value:'LS164',child:Text('LS164 • DLM–GLA')),DropdownMenuItem(value:'LS922',child:Text('LS922 • DLM–MAN')),
     DropdownMenuItem(value:'OR3057',child:Text('OR3057 • DLM–AMS')),DropdownMenuItem(value:'custom',child:Text('Başka uçuş'))],
    onChanged:(v){if(v!=null&&v!='custom')setState((){code.text=v;dest.text={'LS164':'GLA','LS922':'MAN','OR3057':'AMS'}[v]!;});}),
   for(final e in <TextEditingController,String>{actor:'İşlemi yapan (yerel test logu)',code:'Uçuş numarası',date:'Tarih YYYY-MM-DD',origin:'Kalkış IATA',dest:'Varış IATA'}.entries)
    Padding(padding:const EdgeInsets.only(top:12),child:TextField(controller:e.key,decoration:InputDecoration(labelText:e.value))),
   if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
   const SizedBox(height:20),FilledButton(onPressed:open,child:const Text('Test uçuşunu aç / kaldığı yerden devam et')),
   const SizedBox(height:12),const Text('Aynı uçuş/tarih/rota tekrar açıldığında bu cihazdaki kayıtlar geri yüklenir. Yeni test için uçuş/tarih değiştirin.'),
  ]));
}
