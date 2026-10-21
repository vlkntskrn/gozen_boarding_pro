import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'local_flight.dart';

const dailyFields = <String,String>{
 'G3':'G.S.C','G4':'Station Manager','G5':'Check-in Supervisor','G6':'Gate Supervisor','G7':'Transit Supervisor',
 'G9':'Uçak tipi','G10':'Tescil','G11':'Shift başlangıcı','G12':'Shift bitişi','G13':'Pre briefing başlangıcı',
 'G14':'Pre briefing bitişi','G15':'Post briefing başlangıcı','G16':'Post briefing bitişi','G17':'Check-in podyum',
 'L3':'Kontuarı arayan','L4':'Gate arayan','L5':'Gate numarası','L6':'Boarding başlangıcı','L7':'Boarding bitişi',
 'L8':'Uçak arama başlangıcı','L9':'Uçak arama bitişi','L10':'Temizlik başlangıcı','L11':'Temizlik bitişi',
 'L13':'Transit yolcu','L14':'Profiling selectee','L15':'SSSS','L17':'Gate podyum',
 'P4':'ETA','P5':'ATA','P6':'ETD','P7':'ATD','P8':'Transit bagaj','P9':'Rush bagaj','P10':'Local bagaj',
 'P11':'Yetersiz doküman','P12':'Sahte doküman','P15':'ETD marka/model/seri',
 'O13':'Fiziksel arama (X)','O14':'ETD arama (X)','G18':'Notlar','G33':'Delay code',
};
const baFields = <String,String>{
 'E13':'Uçak tipi','E14':'Tescil','E15':'Shift başlangıcı','E16':'Shift bitişi',
 'E17':'Pre briefing başlangıcı','E18':'Pre briefing bitişi','E19':'Post briefing başlangıcı','E20':'Post briefing bitişi',
 'L13':'ETA','L14':'ATA','L15':'ETD','L16':'ATD','L17':'Gate açılışı','L18':'Cabin crew varışı','L19':'Cabin crew kontrolü',
 'O12':'ETD marka/model/seri','O15':'Gate numarası','O16':'Transit bagaj','O17':'Rush bagaj','O18':'Local bagaj','O19':'Gate bagajı',
 'O20':'X-ray bagajı','N10':'Fiziksel arama (X)','N11':'ETD arama (X)','L24':'Notlar','M34':'Duty officer adı',
};
const commonFields = <String,String>{
 'airline':'Havayolu adı','searchTl':'Aramayı yaptıran team leader','airlineRep':'Onaylayan havayolu temsilcisi',
 'agent1':'Aramayı yapan personel 1','agent2':'Aramayı yapan personel 2',
 'agent3':'Aramayı yapan personel 3','agent4':'Aramayı yapan personel 4',
 'staff':'Personel: her satıra ad soyad | pozisyon','equipment':'Ekipman: marka | model | seri',
 'preBrief':'Operasyon öncesi brifing: her satıra bir konu','postBrief':'Operasyon sonrası brifing: her satıra bir konu',
};

List<int> _rewrite(List<int> template, Map<String,List<int>> changes) {
 final zip=ZipDecoder().decodeBytes(template,verify:true), out=Archive();
 for(final f in zip.files) {final bytes=changes[f.name] ?? (f.content as List<int>);out.addFile(ArchiveFile(f.name,bytes.length,bytes));}
 return ZipEncoder().encode(out)!;
}
void _wordText(XmlElement e,String value) {
 final ts=e.findAllElements('w:t').toList();
 if(ts.isNotEmpty) {ts.first.innerText=value;for(final t in ts.skip(1)) {t.innerText='';}}
 else {
  final p=e.name.qualified=='w:p'?e:e.findAllElements('w:p').first;
  p.children.add(XmlElement(XmlName('r','w'),[],[XmlElement(XmlName('t','w'),[],[XmlText(value)])]));
 }
}

/// Preserve the uploaded Word template, including all consent translations and
/// blank signature fields. Fifteen passengers per copy of the full form.
List<int> searchForm(List<int> template,FlightSpec spec,Map<String,dynamic> data) {
 final z=ZipDecoder().decodeBytes(template), file=z.findFile('word/document.xml')!;
 final doc=XmlDocument.parse(utf8.decode(file.content as List<int>));
 final body=doc.findAllElements('w:body').single;
 final original=body.children.where((n)=>n is! XmlElement || n.name.local!='sectPr').map((n)=>n.copy()).toList();
 final section=body.findElements('w:sectPr').firstOrNull?.copy();
 final searched=Map<String,dynamic>.from(data['pax']).values.where((p)=>p['searched']==true).toList();
 final fields=Map<String,dynamic>.from(data['fields']);
 body.children.clear();
 final pages=(searched.length/15).ceil().clamp(1,1000);
 for(var page=0;page<pages;page++) {
  if(page>0) body.children.add(XmlElement(XmlName('p','w'),[],[XmlElement(XmlName('r','w'),[],[XmlElement(XmlName('br','w'),[XmlAttribute(XmlName('type','w'),'page')])])]));
  final nodes=original.map((n)=>n.copy()).toList();
  for(final n in nodes.whereType<XmlElement>()) {
   for(final p in [if(n.name.qualified=='w:p') n,...n.findAllElements('w:p')]) {
    final text=p.findAllElements('w:t').map((t)=>t.innerText).join();
    if(text.startsWith('TARİH (Date)')) _wordText(p,'TARİH (Date): ${spec.date}');
    if(text.startsWith('HAVAYOLU (Airline)')) _wordText(p,'HAVAYOLU (Airline): ${fields['airline']??spec.code.replaceAll(RegExp(r'[0-9]'),'')}');
    if(text.startsWith('UÇUŞ NO (Flight No)')) _wordText(p,'UÇUŞ NO (Flight No): ${spec.code} ${spec.origin}–${spec.destination}');
   }
   final table=n.name.qualified=='w:tbl'?n:null;
   if(table==null) continue;
   final rows=table.findElements('w:tr').skip(1).toList();
   for(var i=0;i<rows.length;i++) {
    final cells=rows[i].findElements('w:tc').toList(), index=page*15+i;
    if(cells.length!=6) throw const FormatException('Arama formu şablonu değişmiş.');
    final p=index<searched.length?searched[index]:null;
    final values=p==null?['${index+1})','','','','','']:[
      '${index+1}) ${p['name']}${p['lp']==true?' LP':''}',p['sequence']??'',p['nationality']??'',
      '${p['remarks']??''}${p['status']=='OFFLOADED'?' OFFLOADED':''}','',''];
    for(var c=0;c<6;c++) {_wordText(cells[c],values[c].toString());}
   }
  }
  // Named signatories are typed; handwritten signatures stay blank.
  var signatory=0;
  for(final n in nodes.whereType<XmlElement>()) {
   if(n.name.qualified!='w:p') continue;
   final text=n.findAllElements('w:t').map((t)=>t.innerText).join();
   if(!text.startsWith('ADI-SOYADI')) continue;
   final pair=signatory==0?['searchTl','airlineRep']:signatory==1?['agent1','agent2']:['agent3','agent4'];
   _wordText(n,'ADI-SOYADI: ${fields[pair[0]]??''}                       ADI-SOYADI: ${fields[pair[1]]??''}');signatory++;
  }
  body.children.addAll(nodes);
 }
 if(section!=null) body.children.add(section);
 return _rewrite(template,{'word/document.xml':utf8.encode(doc.toXmlString())});
}

/// Edit values directly in the existing OOXML cells so workbook drawings,
/// print layout, styles, merged cells and logos remain untouched.
List<int> dailyForm(List<int> template,FlightSpec spec,Map<String,dynamic> data) {
 final z=ZipDecoder().decodeBytes(template), file=z.findFile('xl/worksheets/sheet1.xml')!;
 final doc=XmlDocument.parse(utf8.decode(file.content as List<int>));
 final rows=doc.findAllElements('row').toList();
 void put(String ref,String value) {
  final rn=RegExp(r'\d+').firstMatch(ref)!.group(0)!;
  final row=rows.firstWhere((r)=>r.getAttribute('r')==rn);
  var cell=row.findElements('c').where((c)=>c.getAttribute('r')==ref).firstOrNull;
  if(cell==null) {cell=XmlElement(XmlName('c'),[XmlAttribute(XmlName('r'),ref)]);row.children.add(cell);}
  cell.setAttribute('t','inlineStr'); cell.children.clear();
  cell.children.add(XmlElement(XmlName('is'),[],[XmlElement(XmlName('t'),[XmlAttribute(XmlName('space','xml'),'preserve')],[XmlText(value)])]));
 }
 final pax=Map<String,dynamic>.from(data['pax']).values.toList();
 final active=pax.where((p)=>['PREBOARDED','DFT_BOARDED'].contains(p['status'])).length;
 final searched=pax.where((p)=>p['searched']==true).length;
 final fields=Map<String,dynamic>.from(data['fields']);
 final ba=spec.reportForm=='OPR-FRM-0012';
 if(!ba) {
  final times=Map<String,dynamic>.from(data['times']??{});
  if((fields['L6']??'').toString().isEmpty) fields['L6']=times['boardingStarted']??'';
  if((fields['L7']??'').toString().isEmpty) fields['L7']=times['lastPassenger']??'';
 }
 for(final key in (ba?baFields:dailyFields).keys) {put(key,(fields[key]??'').toString());}
 put(ba?'E12':'G8',spec.code);put(ba?'L12':'P3',spec.date);
 put(ba?'O13':'L12',active.toString());put(ba?'O14':'L16',searched.toString());
 final staff=(fields['staff']??'').toString().split('\n').where((s)=>s.trim().isNotEmpty).toList();
 if(staff.length>(ba?10:35)) throw const FormatException('Personel sayısı form kapasitesini aşıyor.');
 for(var i=0;i<(ba?10:35);i++) {
  final parts=i<staff.length?staff[i].split('|'):['',''];
  put(ba?'E${24+i}':'B${9+i}',parts.first.trim());
  if(ba) for(final col in ['F','G','H','I','J','K']) {put('$col${24+i}','');}
  if(!ba) put('C${9+i}',parts.length>1?parts[1].trim():'');
 }
 if(!ba) for(final pair in [('preBrief','E'),('postBrief','M')]) {
  final lines=(fields[pair.$1]??'').toString().split('\n');
  if(lines.length>5) throw const FormatException('Brifing bölümü en fazla 5 satır içerir.');
  for(var i=0;i<5;i++) {put('${pair.$2}${39+i}',i<lines.length?lines[i]:'');}
 }
 return _rewrite(template,{'xl/worksheets/sheet1.xml':utf8.encode(doc.toXmlString())});
}
