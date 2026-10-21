import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'boarding_validation.dart';

/// Browser-local walkthrough. Never imports Firebase or writes live records.
class WebPreviewScreen extends StatefulWidget {
  final WidgetBuilder liveBuilder;
  const WebPreviewScreen({super.key, required this.liveBuilder});
  @override
  State<WebPreviewScreen> createState() => _WebPreviewScreenState();
}

class _PreviewFlight {
  final String code, date, destination;
  final watchlist = <String>['ALARM/YOLCU'];
  final pax = <String, Map<String, String>>{};
  final logs = <String>[];
  bool closed = false;
  _PreviewFlight(this.code, this.date, this.destination);
}

class _WebPreviewScreenState extends State<WebPreviewScreen> {
  final _raw = TextEditingController();
  final _name = TextEditingController();
  final _flights = [
    _PreviewFlight('LS1730', '2026-10-21', 'MAN'),
    _PreviewFlight('OR3057', '2026-10-22', 'AMS'),
    _PreviewFlight('BY412', '2026-10-21', 'LGW'),
  ];
  _PreviewFlight? _selected;
  List<String> get _watchlist => _selected!.watchlist;
  Map<String, Map<String, String>> get _pax => _selected!.pax;
  List<String> get _logs => _selected!.logs;
  String get _date => _selected!.date;
  String get _code => _selected!.code;
  bool get _closed => _selected!.closed;
  set _closed(bool value) => _selected!.closed = value;
  bool _random = false;
  bool _busy = false;

  String _sample({bool watch = false, bool wrong = false}) {
    final date = strictDate(_date)!;
    final julian = (date.difference(DateTime.utc(date.year)).inDays + 1).toString().padLeft(3, '0');
    return 'M1${(watch ? 'ALARM/YOLCU' : 'DEMO/YOLCU').padRight(20)}E'
      '${'DEMO01'.padRight(7)}${wrong ? 'BJV' : 'DLM'}${_selected!.destination}${_code.substring(0,2).padRight(3)}'
      '${_code.substring(2).padRight(5)}${julian}Y${watch ? '014C' : '012A'}'
      '${(watch ? '00124' : '00123').padRight(5)}100';
  }

  void _openFlight(_PreviewFlight flight) => setState(() {
    _selected = flight;
    _raw.clear();
    _name.clear();
    _random = false;
  });

  void _flightList() => setState(() {
    _selected = null;
    _raw.clear();
    _name.clear();
  });

  @override
  void dispose() { _raw.dispose(); _name.dispose(); super.dispose(); }

  Future<void> _result(Color color, String title, String detail) => showDialog<void>(
    context: context, barrierDismissible: false,
    builder: (ctx) => Dialog.fullscreen(child: ColoredBox(color: color,
      child: Center(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(
            fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 16),
          Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam')),
        ]),
      )),
    )));

  Future<void> _scan() async {
    if (_closed || _busy) return;
    setState(() => _busy = true);
    try {
      final legs = parseBcbp(_raw.text);
      final pass = legs.length == 1 ? legs.single : selectBcbpLeg(legs, _code, _date);
      final error = validationError(pass, _code, _date, expectedDestination:_selected!.destination);
      if (error != null) { await _result(Colors.purple, 'WRONG FLIGHT', error); return; }
      final key = pass.sequence.isNotEmpty ? pass.sequence : '${pass.fullName}|${pass.seat}';
      if (_pax[key]?['status'] == 'PREBOARDED' || _pax[key]?['status'] == 'DFT_BOARDED') {
        await _result(Colors.grey, 'ALREADY BOARDED / DUPLICATE', 'Örnek yolcu zaten board edildi.'); return;
      }
      final watch = _watchlist.any((name) => watchlistMatches(pass.fullName, name));
      if (watch && !_random) {
        await _result(Colors.red, 'FLY PASSENGER ATTENTION!!!', 'Yalnız DFT Random ile devam edilebilir.'); return;
      }
      setState(() {
        _pax[key] = {'name':pass.fullName, 'seat':pass.seat, 'pnr':pass.pnr,
          'status':_random ? 'DFT_BOARDED' : 'PREBOARDED'};
        _logs.add('${DateTime.now().toLocal()} • ${_random ? 'DFT Random' : 'Pre-BOARD'} • ${pass.fullName}');
      });
      await _result(watch ? Colors.red : _random ? Colors.blue : Colors.green,
        watch ? 'FLY PASSENGER ATTENTION!!!' : _random ? 'DFT RANDOM SUCCESSFUL' : 'PRE-BOARD SUCCESSFUL',
        '${pass.givenName} ${pass.surname} • ${pass.seat}\nÖnizleme kaydı oluşturuldu.');
    } on FormatException catch (e) {
      await _result(Colors.blueGrey, 'KART DOĞRULANAMADI', e.message);
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _export() async {
    String cell(String text) {
      final safe = RegExp(r'^[=+@-]').hasMatch(text) ? "'$text" : text;
      return '"${safe.replaceAll('"','""')}"';
    }
    final csv = ['FULL_NAME,PNR,SEAT,STATUS', ..._pax.values.map((p) =>
      [p['name']!,p['pnr']!,p['seat']!,p['status']!].map(cell).join(','))].join('\r\n');
    final filename = 'GOZEN_DEMO_${_code}_$_date.csv';
    final file = XFile.fromData(Uint8List.fromList(utf8.encode('\uFEFF$csv')),
      mimeType:'text/csv', name:filename);
    try { await Share.shareXFiles([file], fileNameOverrides:[filename]); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('İndirme açılamadı. Tarayıcının indirme izinlerini kontrol edin.'))); }
  }

  Widget _panel(String title, Widget child) => Card(child: Padding(
    padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16), child])));

  Widget _scanTab() => ListView(padding: const EdgeInsets.all(16), children: [
    _panel('$_code • DLM → ${_selected!.destination}', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('$_date • ${_closed ? 'KAPALI' : 'AÇIK'} • ${_pax.length} örnek yolcu'),
      const SizedBox(height: 16),
      const Text('Kart doğrulamasını dene', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton(onPressed: () => _raw.text = _sample(), child: const Text('Örnek kart')),
        OutlinedButton(onPressed: () => _raw.text = _sample(watch:true), child: const Text('Watchlist örneği')),
        OutlinedButton(onPressed: () => _raw.text = _sample(wrong:true), child: const Text('Yanlış kalkış örneği')),
      ]),
      const SizedBox(height: 12),
      TextField(controller:_raw, maxLines:4, decoration:const InputDecoration(
        labelText:'BCBP barkod metni', helperText:'Sabit alanlardaki boşlukları koruyun.')),
      const SizedBox(height: 16),
      Wrap(spacing: 12, children: [
        ChoiceChip(label:const Text('Pre-BOARD'), selected:!_random, onSelected: (_) => setState(() => _random=false)),
        ChoiceChip(label:const Text('DFT Random'), selected:_random, onSelected: (_) => setState(() => _random=true)),
      ]),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed:_closed || _busy ? null : _scan,
        icon:const Icon(Icons.qr_code_scanner), label:const Text('Kartı Doğrula')),
      const SizedBox(height: 12),
      const Text('Canlı kamerayla tarama, yetkili girişten sonra Scan sekmesindedir.'),
    ])),
  ]);

  Widget _flightsPage() => Scaffold(
    appBar: AppBar(title: const Text('GOZEN BOARDING PRO'), actions: [
      TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: widget.liveBuilder)),
        icon: const Icon(Icons.lock_outline), label: const Text('Yetkili Giriş')),
    ]),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _panel('Uçuş Seçimi', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('WEB ÖNİZLEME • Aşağıdaki uçuşlar örnektir. Gerçek uçuş listesi için Yetkili Giriş kullanılır.'),
          const SizedBox(height: 16),
          const Text('İşlem yapmak istediğin uçuşu seç. Her uçuşun yolcu, watchlist ve işlem kayıtları ayrıdır.'),
          const SizedBox(height: 12),
          for (final flight in _flights) Card(margin: const EdgeInsets.only(top: 10),
            child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: const Icon(Icons.flight_takeoff),
              title: Text(flight.code, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('DLM → ${flight.destination} • ${flight.date}\n${flight.closed ? 'KAPALI' : 'AÇIK'} • ${flight.pax.length} örnek yolcu'),
              isThreeLine: true, trailing: const Icon(Icons.chevron_right),
              onTap: () => _openFlight(flight))),
        ])),
      ]),
    )),
  );

  @override
  Widget build(BuildContext context) => _selected == null ? _flightsPage() : DefaultTabController(length:7, child: Scaffold(
    appBar:AppBar(leading: BackButton(onPressed: _flightList),
      title:Text('GOZEN BOARDING PRO • $_code'), actions:[
      TextButton(onPressed: _busy ? null : _flightList, child: const Text('Uçuş Değiştir')),
      TextButton.icon(onPressed:() => Navigator.push(context, MaterialPageRoute(builder:widget.liveBuilder)),
        icon:const Icon(Icons.lock_outline), label:const Text('Yetkili Giriş')),
    ], bottom:const TabBar(isScrollable:true, tabs:[
      Tab(text:'Scan'), Tab(text:'Yolcu Listesi'), Tab(text:'WatchList'), Tab(text:'Personel'),
      Tab(text:'Ekipman'), Tab(text:'Op. Times'), Tab(text:'Rapor'),
    ])),
    body:Column(children:[
      Container(width:double.infinity, color:const Color(0xFFE0F4FF),
        padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),
        child:const Text('WEB ÖNİZLEME • Örnek veriler • Değişiklikler yalnız bu oturumda tutulur; canlı uçuşlara yazılmaz.',
          style:TextStyle(color:Color(0xFF143A57),fontWeight:FontWeight.w600))),
      Expanded(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1100),
        child:TabBarView(children:[
          _scanTab(),
          ListView(padding:const EdgeInsets.all(16), children:[
            _panel('Yolcu Listesi', Column(children:[
              if (_pax.isEmpty) const Padding(padding:EdgeInsets.all(24),child:Text('Scan sekmesinden örnek kartı okutun.')),
              for (final entry in _pax.entries) ListTile(title:Text(entry.value['name']!),
                subtitle:Text('${entry.value['seat']} • ${entry.value['status']}'),
                trailing:TextButton(onPressed:_closed || entry.value['status']=='OFFLOADED' ? null : () => setState(() {
                  entry.value['status']='OFFLOADED'; _logs.add('${DateTime.now()} • OFFLOADED • ${entry.value['name']}');
                }), child:const Text('Offload'))),
            ])),
          ]),
          ListView(padding:const EdgeInsets.all(16),children:[_panel('WatchList • Örnek isimler',Column(children:[
            for (final name in _watchlist) ListTile(title:Text(name),trailing:IconButton(
              tooltip:'Örnek kaydı sil',onPressed:() => setState(() => _watchlist.remove(name)),icon:const Icon(Icons.delete_outline))),
            TextField(controller:_name,decoration:const InputDecoration(labelText:'Örnek ad soyad')),
            const SizedBox(height:12),
            FilledButton(onPressed:() { final n=_name.text.trim(); if(n.isNotEmpty) setState(() {_watchlist.add(n);_name.clear();}); },child:const Text('Örnek Ekle')),
          ]))]),
          ListView(padding:const EdgeInsets.all(16),children:[_panel('Personel • Örnek ekip',const Column(children:[
            ListTile(leading:Icon(Icons.supervisor_account),title:Text('Örnek Ekip Şefi'),subtitle:Text('Supervisor • Gate TL')),
            ListTile(leading:Icon(Icons.badge_outlined),title:Text('Örnek Tarama Personeli'),subtitle:Text('Agent • Gate Screening')),
          ]))]),
          ListView(padding:const EdgeInsets.all(16),children:[_panel('Ekipman • Örnek envanter',const Column(children:[
            ListTile(leading:Icon(Icons.scanner_outlined),title:Text('ETD Cihazı'),subtitle:Text('Marka/model ve seri no • DEMO-ETD-001')),
            ListTile(leading:Icon(Icons.table_restaurant),title:Text('Gate Masası'),subtitle:Text('Örnek masa • DEMO-001')),
          ]))]),
          ListView(padding:const EdgeInsets.all(16),children:[_panel('Operasyon Saatleri',Column(children:[
            SwitchListTile(title:const Text('Uçuş kapalı'),subtitle:const Text('Yalnız önizleme uçuşunu etkiler.'),
              value:_closed,onChanged:(v)=>setState(()=>_closed=v)),
            for(final line in _logs) ListTile(leading:const Icon(Icons.history),title:Text(line)),
            if(_logs.isEmpty) const Text('Boarding işlemleri yapıldığında örnek işlem geçmişi burada görünür.'),
          ]))]),
          ListView(padding:const EdgeInsets.all(16),children:[_panel('CSV Raporu',Column(children:[
            Text('${_pax.length} örnek yolcu • Excel ile açılabilir'),const SizedBox(height:16),
            FilledButton.icon(onPressed:_export,icon:const Icon(Icons.download),label:const Text('Örnek CSV İndir')),
            const SizedBox(height:16),const Text('Gerçek uçuş raporları için Yetkili Giriş kullanılır.'),
          ]))]),
        ]),
      ))),
    ]),
  ));
}
