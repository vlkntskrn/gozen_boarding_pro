import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'boarding_validation.dart';

class FlightSpec {
  final String id, code, date, origin, destination;
  const FlightSpec(this.id,this.code,this.date,this.origin,this.destination);
  String? validate(BoardingPass p) => validationError(p,code,date,
    expectedOrigin:origin,expectedDestination:destination);
  String get reportForm => normalizeFlightCode(code).startsWith('BA') ? 'OPR-FRM-0012' : 'OPR-FRM-0011';
}

class LpPassenger {
  final String name, pnr, sequence;
  const LpPassenger(this.name,this.pnr,this.sequence);
  Map<String,dynamic> toJson() => {'name':name,'pnr':pnr,'sequence':sequence};
}

/// Only table names/PNRs/security numbers are imported. Free text (including
/// medical notes in supplied LP files) is deliberately excluded.
List<LpPassenger> parseLp(List<int> bytes, FlightSpec flight) {
  if (bytes.length > 5 * 1024 * 1024) throw const FormatException('LP dosyası çok büyük.');
  final zip = ZipDecoder().decodeBytes(bytes,verify:true);
  final entry = zip.findFile('word/document.xml');
  if (entry == null || entry.size > 10 * 1024 * 1024) throw const FormatException('Geçerli DOCX gerekli.');
  final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
  String text(XmlElement e) => e.findAllElements('w:t').map((t)=>t.innerText).join('');
  final paragraphs = doc.findAllElements('w:p').map(text).toList();
  final header = paragraphs.firstWhere((p)=>p.startsWith('Flight Number:'),orElse:()=> '');
  final match = RegExp(r'Flight Number:\s*([A-Z0-9]+)\s*\(([A-Z]{3})\s*-\s*([A-Z]{3})\)').firstMatch(header);
  if (match == null || !flightCodesMatch(flight.code,match[1]!) || match[2]!=flight.origin || match[3]!=flight.destination) {
    throw const FormatException('LP uçuşu veya kalkış/varış eşleşmiyor.');
  }
  final dateLine = paragraphs.firstWhere((p)=>p.startsWith('Flight Date & Time:'),orElse:()=> '');
  final dm = RegExp(r'(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})').firstMatch(dateLine);
  const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  if(dm==null) throw const FormatException('LP tarihi okunamadı.');
  final month = months.indexWhere((m)=>m.toLowerCase()==dm[2]!.toLowerCase())+1;
  final date = '${dm[3]}-${month.toString().padLeft(2,'0')}-${dm[1]!.padLeft(2,'0')}';
  if(strictDate(date)==null || date!=flight.date) throw const FormatException('LP tarihi eşleşmiyor.');
  final rows = <LpPassenger>[];
  for(final row in doc.findAllElements('w:tr')) {
    final cells = row.findElements('w:tc').map(text).map((s)=>s.trim()).toList();
    if(cells.length<7 || int.tryParse(cells[0])==null) continue;
    final name = cells[2], pnr=cells[5].toUpperCase(), seq=cells[6];
    if(name.isEmpty || !RegExp(r'^[A-Z0-9]{5,7}$').hasMatch(pnr) || (seq.isNotEmpty && !RegExp(r'^\d{1,5}$').hasMatch(seq))) {
      throw const FormatException('LP satırı doğrulanamadı; dosya yüklenmedi.');
    }
    rows.add(LpPassenger(name,pnr,seq));
  }
  if(rows.isEmpty) throw const FormatException('LP yolcu tablosu bulunamadı.');
  return rows;
}

/// A serialized, durable local ledger. Mutations are copy-on-write: no green
/// result until persistence succeeds. Neither payload nor audit is sent online.
class LocalFlight {
  final FlightSpec spec;
  final String actor;
  final Future<void> Function(String) persist;
  Map<String,dynamic> _data;
  Future<void> _tail = Future.value();
  LocalFlight(this.spec,this.actor,this.persist,{String? saved}) : _data = saved==null ? {
    'schema':1,'pax':<String,dynamic>{},'lp':<dynamic>[],'watchlist':<dynamic>[],
    'logs':<dynamic>[],'fields':<String,dynamic>{},'times':<String,dynamic>{},'closed':false,'mail':'NONE',
  } : Map<String,dynamic>.from(jsonDecode(saved)) {
    if(!validAudit(_data)) throw const FormatException('Yerel işlem geçmişi doğrulanamadı.');
  }
  Map<String,dynamic> get snapshot => jsonDecode(jsonEncode(_data));
  List<Map<String,dynamic>> get passengers => Map<String,dynamic>.from(_data['pax']).entries
    .map((e)=><String,dynamic>{...Map<String,dynamic>.from(e.value),'id':e.key}).toList();
  bool get closed => _data['closed']==true;
  static String _hash(Map<String,dynamic> e)=>sha256.convert(utf8.encode(jsonEncode(e))).toString();
  static bool validAudit(Map<String,dynamic> data) {
    var prior='';
    for(final item in data['logs'] ?? []) {
      final e=Map<String,dynamic>.from(item), hash=e.remove('hash');
      if(e['previous']!=prior || hash!=_hash(e)) return false;
      prior=hash;
    }
    return true;
  }
  Future<void> change(String action, void Function(Map<String,dynamic>) apply, {bool afterClose=false}) {
    final result=_tail.then((_) async {
      if(closed && !afterClose) throw StateError('Uçuş kapalı.');
      final next=snapshot;
      apply(next);
      final logs=next['logs'] as List;
      final event=<String,dynamic>{'action':action,'actor':actor,
        'at':DateTime.now().toUtc().toIso8601String(),
        'previous':logs.isEmpty?'':logs.last['hash']};
      event['hash']=_hash(event); logs.add(event);
      await persist(jsonEncode(next));
      _data=next;
    });
    _tail=result.then<void>((_) {},onError:(Object _,StackTrace __) {});
    return result;
  }
  Future<void> log(String action)=>change(action,(_){},afterClose:true);
  Future<void> importLp(List<int> bytes) {
    final list=parseLp(bytes,spec);
    return change('LP_IMPORTED:${list.length}',(d) {
      d['lp']=list.map((p)=>p.toJson()).toList();
      for(final p in (d['pax'] as Map).values) {
        p['lp']=list.where((x)=>watchlistMatches(p['name'],x.name,pnr:p['pnr'],watchPnr:x.pnr)).length==1;
      }
    });
  }
  Future<void> board(BoardingPass p,{required bool random,String? adultId}) async {
    final error=spec.validate(p);
    if(error!=null) {await log('SCAN_REJECTED:ROUTE_OR_DATE');throw FormatException(error);}
    await change('PAX_BOARDED:${random?'DFT':'PRE'}:${p.sequence}:${p.fullName}',(d) {
      final pax=d['pax'] as Map<String,dynamic>;
      final identity=p.sequence.isNotEmpty?'seq:${p.sequence.replaceFirst(RegExp(r'^0+'),'')}':'name:${p.fullName}|${p.pnr}';
      bool active(dynamic x)=>['PREBOARDED','DFT_BOARDED'].contains(x['status']);
      if(pax[identity]!=null && active(pax[identity])) throw StateError('ALREADY BOARDED / DUPLICATE');
      if(pax.values.any((x)=>active(x) && watchlistMatches(p.fullName,x['name'],pnr:p.pnr,watchPnr:x['pnr']))) {
        throw StateError('ALREADY BOARDED / DUPLICATE');
      }
      final seated=pax.entries.where((e)=>active(e.value) && e.value['seat']==p.seat).toList();
      if(seated.isNotEmpty && (adultId==null || seated.length!=1 || seated.single.key!=adultId || seated.single.value['adultId']!=null)) {
        throw StateError('SEAT_OCCUPIED: Yetişkin ve infant bağlantısı doğrulanmalı.');
      }
      if(adultId!=null && seated.isEmpty) throw StateError('Bağlı yetişkin bulunamadı.');
      final watch=(d['watchlist'] as List).any((n)=>watchlistMatches(p.fullName,n.toString()));
      if(watch && !random) throw StateError('FLY PASSENGER ATTENTION!!!');
      final hits=(d['lp'] as List).where((x)=>watchlistMatches(p.fullName,x['name'],pnr:p.pnr,watchPnr:x['pnr'])).toList();
      pax[identity]={'name':p.fullName,'pnr':p.pnr,'seat':p.seat,'sequence':p.sequence,
        'status':random?'DFT_BOARDED':'PREBOARDED','searched':random,'lp':hits.length==1,'watch':watch,
        'adultId':adultId,'nationality':'','remarks':'','by':actor,'at':DateTime.now().toUtc().toIso8601String()};
      final times=d.putIfAbsent('times',()=> <String,dynamic>{}) as Map;
      times.putIfAbsent('boardingStarted',()=>DateTime.now().toIso8601String());
      times['lastPassenger']=DateTime.now().toIso8601String();
    });
  }
  Future<void> offload(String id)=>change('PAX_OFFLOADED:$id',(d) {
    final pax=d['pax'] as Map;
    if(pax[id]==null) throw StateError('Yolcu bulunamadı.');
    for(final item in pax.values) {
      if(identical(item,pax[id]) || item['adultId']==id) item['status']='OFFLOADED';
    }
  });
  Future<void> saveFields(Map<String,String> values)=>change('REPORT_FIELDS_UPDATED',(d)=>d['fields']={...d['fields'],...values});
  Future<void> setWatchlist(List<String> names)=>change('WATCHLIST_UPDATED',(d)=>d['watchlist']=names);
  Future<void> searchDetails(String id,String nationality,String remarks)=>change('SEARCH_DETAILS_UPDATED:$id',(d) {
    d['pax'][id]['nationality']=nationality;d['pax'][id]['remarks']=remarks;
  });
  Future<void> close()=>change('FLIGHT_CLOSED',(d) {d['closed']=true;d['mail']='PENDING';});
  Future<void> mailOpened()=>change('MAIL_COMPOSER_OPENED',(d)=>d['mail']='AWAITING_SEND_CONFIRMATION',afterClose:true);
}
