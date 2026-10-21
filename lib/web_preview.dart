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

class _WebPreviewScreenState extends State<WebPreviewScreen> {
  final _raw = TextEditingController();
  final _name = TextEditingController();
  final _watchlist = <String>['ALARM/YOLCU'];
  final _pax = <String, Map<String, String>>{};
  final _logs = <String>[];
  bool _random = false;
  bool _closed = false;
  bool _busy = false;
  static const _date = '2026-10-21';

  String _sample({bool watch = false, bool wrong = false}) =>
      'M1${(watch ? 'ALARM/YOLCU' : 'DEMO/YOLCU').padRight(20)}E'
      '${'DEMO01'.padRight(7)}${wrong ? 'BJV' : 'DLM'}MANLS '
      '${'1730'.padRight(5)}294Y${watch ? '014C' : '012A'}'
      '${(watch ? '00124' : '00123').padRight(5)}100';

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
      final pass = legs.length == 1 ? legs.single : selectBcbpLeg(legs, 'LS1730', _date);
      final error = validationError(pass, 'LS1730', _date);
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
    final file = XFile.fromData(Uint8List.fromList(utf8.encode('\uFEFF$csv')),
      mimeType:'text/csv', name:'GOZEN_DEMO_LS1730.csv');
    try { await Share.shareXFiles([file], fileNameOverrides:['GOZEN_DEMO_LS1730.csv']); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('İndirme açılamadı. Tarayıcının indirme izinlerini kontrol edin.'))); }
  }

  Widget _panel(String title, Widget child) => Card(child: Padding(
    padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16), child])));

  Widget _scanTab() => ListView(padding: const EdgeInsets.all(16), children: [
    _panel('LS1730 • DLM → MAN', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('21 Ekim 2026 • ${_closed ? 'KAPALI' : 'AÇIK'} • ${_pax.length} örnek yolcu'),
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

  @override
  Widget build(BuildContext context) => DefaultTabController(length:7, child: Scaffold(
    appBar:AppBar(title:const Text('GOZEN BOARDING PRO'), actions:[
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
