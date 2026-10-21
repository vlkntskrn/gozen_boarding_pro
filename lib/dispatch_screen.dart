import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'boarding_validation.dart';
import 'local_operations_screen.dart';

/// Firebase contains only flight dispatch metadata; passenger modules never use it.
class DispatchScreen extends StatelessWidget {
 final VoidCallback logout;
 const DispatchScreen({super.key,required this.logout});
 String get uid=>FirebaseAuth.instance.currentUser!.uid;
 FirebaseFirestore get db=>FirebaseFirestore.instance;
 Future<void> edit(BuildContext context,{DocumentSnapshot<Map<String,dynamic>>? existing}) async {
  try {
   final users=await db.collection('users').where('active',isEqualTo:true).get(const GetOptions(source:Source.server));
   if(!context.mounted) return;
   final d=existing?.data()??{};
   final code=TextEditingController(text:d['flightCode']),date=TextEditingController(text:d['etdDateText']),
    dest=TextEditingController(text:d['arrivalAirport']),recipients=TextEditingController(text:(d['reportRecipients'] as List? ?? []).join(', ')),
    booked=TextEditingController(text:'${d['bookedPax']??0}');
   final selected=Set<String>.from(d['participants']??[]);
   String? error;
   final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,set)=>AlertDialog(
    title:Text(existing==null?'Uçuş Oluştur ve Ata':'Uçuş Ataması ve Rapor Alıcıları'),
    content:SizedBox(width:500,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
     if(existing==null) ...[
      TextField(controller:code,decoration:const InputDecoration(labelText:'Uçuş kodu (LS196 / BA...)')),
      TextField(controller:date,decoration:const InputDecoration(labelText:'Tarih YYYY-MM-DD')),
      const ListTile(title:Text('Kalkış: DLM')),
      TextField(controller:dest,decoration:const InputDecoration(labelText:'Varış IATA (GLA / MAN...)')),
      TextField(controller:booked,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Booked pax')),
     ],
     TextField(controller:recipients,decoration:const InputDecoration(labelText:'Rapor e-posta alıcıları (virgülle ayır)')),
     const Text('Atanan kişiler (SPV ve Admin tüm uçuşlara erişir)'),
     for(final u in users.docs) CheckboxListTile(value:selected.contains(u.id),
      title:Text('${u.data()['username']??u.data()['email']??u.id} • ${u.data()['role']??'Agent'}'),
      onChanged:(v)=>set(()=>v==true?selected.add(u.id):selected.remove(u.id))),
     if(error!=null) Text(error!,style:const TextStyle(color:Colors.red)),
    ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Vazgeç')),
     FilledButton(onPressed:(){
      final emails=recipients.text.split(',').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList();
      if(emails.isEmpty || emails.any((s)=>!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)) ||
       (existing==null && (normalizeFlightCode(code.text).isEmpty || strictDate(date.text)==null ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(dest.text.trim().toUpperCase()) || int.tryParse(booked.text)==null))) {
       set(()=>error='Uçuş, tarih, varış ve e-posta adreslerini kontrol edin.');return;
      }
      Navigator.pop(ctx,true);
     },child:const Text('Kaydet'))],
   )));
   if(ok==true) {
    final ref=existing?.reference??db.collection('flights').doc();
    final batch=db.batch();
    final value=<String,dynamic>{'participants':selected.toList(),
     'reportRecipients':recipients.text.split(',').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList()};
    if(existing==null) value.addAll({'flightCode':normalizeFlightCode(code.text),'departureAirport':'DLM',
     'arrivalAirport':dest.text.trim().toUpperCase(),'etdDateText':date.text,'bookedPax':int.parse(booked.text),
     'ownerUid':uid,'createdAt':FieldValue.serverTimestamp(),'closed':false});
    if(existing==null) {batch.set(ref,value);} else {batch.update(ref,value);}
    batch.set(ref.collection('logs').doc(),{'type':existing==null?'FLIGHT_CREATED':'ASSIGNMENT_CHANGED',
     'byUid':uid,'at':FieldValue.serverTimestamp()});
    await batch.commit();
   }
   for(final c in [code,date,dest,recipients,booked]) {c.dispose();}
  } catch(e) {if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('İşlem tamamlanamadı: $e')));}
 }
 @override
 Widget build(BuildContext context)=>StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
  stream:db.collection('users').doc(uid).snapshots(),builder:(ctx,profile){
   final me=profile.data?.data();
   if(me==null) return const Scaffold(body:Center(child:CircularProgressIndicator()));
   final role=me['role'],admin=role=='Admin',spv=role=='Supervisor';
   final Query<Map<String,dynamic>> q=admin||spv?db.collection('flights'):db.collection('flights').where('participants',arrayContains:uid);
   return Scaffold(appBar:AppBar(title:Text('GOZEN • ${spv?'SPV':role}'),actions:[
    IconButton(onPressed:logout,icon:const Icon(Icons.logout),tooltip:'Çıkış')]),
    floatingActionButton:admin?FloatingActionButton.extended(onPressed:()=>edit(context),icon:const Icon(Icons.add),label:const Text('Uçuş Oluştur / Ata')):null,
    body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:q.snapshots(),builder:(ctx,snap){
     if(snap.hasError) return const Center(child:Text('Uçuş erişimi alınamadı. Güvenlik kuralları ve hesabı kontrol edin.'));
     if(!snap.hasData) return const Center(child:CircularProgressIndicator());
     final docs=snap.data!.docs.toList()..sort((a,b)=>'${b.data()['etdDateText']}'.compareTo('${a.data()['etdDateText']}'));
     return ListView(children:[
      const ListTile(title:Text('Yolcu listesi yalnız kayıt telefonundadır.'),subtitle:Text('Bu liste uçuş bilgilerini gösterir. Her uçuş tek kayıt telefonuna bağlanır.')),
      if(docs.isEmpty) const ListTile(title:Text('Atanmış uçuş yok. Admin uçuş atamalıdır.')),
      for(final doc in docs) ListTile(title:Text('${doc.data()['flightCode']} • ${doc.data()['departureAirport']} → ${doc.data()['arrivalAirport']??'VARIŞ TANIMSIZ'}'),
       subtitle:Text('${doc.data()['etdDateText']} • ${doc.data()['closed']==true?'KAPALI':'AÇIK'}'),
       onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>LocalOperationsScreen(flightId:doc.id))),
       trailing:admin?IconButton(icon:const Icon(Icons.manage_accounts),tooltip:'Kişileri ve alıcıları ata',onPressed:()=>edit(context,existing:doc)):null),
     ]);
    }));
  });
}
