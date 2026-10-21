/// Fixed-width IATA BCBP mandatory fields. Never repair whitespace or guess data.
class BoardingPass {
  final String fullName, pnr, origin, destination, flightCode, seat, sequence;
  final int? julianDay;
  final String? travelDate;
  const BoardingPass({
    required this.fullName,
    required this.pnr,
    required this.origin,
    required this.destination,
    required this.flightCode,
    required this.seat,
    required this.sequence,
    this.julianDay,
    this.travelDate,
  });
  String get surname => fullName.contains('/') ? fullName.split('/').first.trim() : '';
  List<String> get _givenAndTitle {
    if (!fullName.contains('/')) return [fullName, ''];
    final given = fullName.split('/').last.trim();
    for (final t in ['MASTER', 'MSTR', 'MISS', 'MRS', 'MR', 'MS', 'DR']) {
      if (given.endsWith(t) && given.length > t.length + 1) {
        return [given.substring(0, given.length - t.length).trim(), t];
      }
    }
    return [given, ''];
  }
  String get givenName => _givenAndTitle[0];
  String get title => _givenAndTitle[1];

  Map<String, String> toMap() => {
    'fullName': fullName,
    'surname': surname, 'givenName': givenName, 'title': title,
    'pnr': pnr,
    'origin': origin,
    'destination': destination,
    'flightCode': flightCode,
    'seat': seat,
    'sequence': sequence,
    'julianDay': julianDay?.toString() ?? '',
    'travelDate': travelDate ?? '',
  };
}

const carrierAliases = {
  'EXS': 'LS',
  'BAW': 'BA',
  'TFL': 'OR',
  'TUI': 'X3',
  'TOM': 'BY',
  'SXS': 'XQ',
  'FHY': 'FH',
  'TWI': 'TI',
};
String normalizeFlightCode(String input) {
  final s = input.trim().toUpperCase().replaceAll(' ', '');
  final m = RegExp(r'^([A-Z]{3}|[A-Z][A-Z0-9]|[0-9][A-Z])(\d{1,4})([A-Z]?)$')
      .firstMatch(s);
  if (m == null) return '';
  final carrier = carrierAliases[m[1]] ?? m[1]!;
  return '$carrier${int.parse(m[2]!)}${m[3]}';
}

bool flightCodesMatch(String expected, String scanned) {
  final a = normalizeFlightCode(expected), b = normalizeFlightCode(scanned);
  return a.isNotEmpty && a == b;
}

String normalizeSeat(String input) {
  final s = input.trim().toUpperCase();
  if (s == 'INF') return s;
  final m = RegExp(r'^(\d{1,3})([A-Z])$').firstMatch(s);
  return m == null ? '' : '${int.parse(m[1]!)}${m[2]}';
}

DateTime? strictDate(String input) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(input);
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final date = DateTime.utc(y, mo, d);
  return date.year == y && date.month == mo && date.day == d ? date : null;
}

List<BoardingPass> parseBcbp(String raw) {
  final s = raw.replaceFirst(RegExp(r'[\r\n]+$'), '').toUpperCase();
  if (!RegExp(r'^M[1-4]').hasMatch(s) ||
      s.length < 60 ||
      RegExp(r'[^\x20-\x7E]').hasMatch(s)) {
    throw const FormatException('BCBP başlığı/uzunluğu geçersiz.');
  }
  final name = s.substring(2, 22).trim();
  if (!name.contains('/') ||
      name.split('/').length != 2 ||
      name.split('/').any((p) => p.trim().isEmpty)) {
    throw const FormatException('BCBP yolcu adı eksik.');
  }
  final count = int.parse(s[1]);
  final result = <BoardingPass>[];
  var offset = 23;
  for (var i = 0; i < count; i++) {
    if (s.length < offset + 37)
      throw const FormatException('Eksik BCBP segmenti.');
    String field(int a, int b) => s.substring(offset + a, offset + b).trim();
    final origin = field(7, 10), destination = field(10, 13);
    final carrier = field(13, 16), number = field(16, 21);
    final dayText = field(21, 24), seat = normalizeSeat(field(25, 29));
    final sequence = field(29, 34),
        pnr = field(0, 7),
        lengthText = field(35, 37);
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(origin) ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(destination) ||
        !RegExp(r'^(?:[A-Z]{3}|[A-Z0-9]{2})$').hasMatch(carrier) ||
        !RegExp(r'^\d{1,4}[A-Z]?$').hasMatch(number) ||
        !RegExp(r'^\d{3}$').hasMatch(dayText) ||
        !RegExp(r'^[A-Z0-9]{0,7}$').hasMatch(pnr) ||
        !RegExp(r'^[A-Z0-9]{0,5}$').hasMatch(sequence) ||
        !RegExp(r'^[0-9A-F]{2}$').hasMatch(lengthText)) {
      throw const FormatException('BCBP sabit alanları geçersiz.');
    }
    final day = int.parse(dayText),
        code = normalizeFlightCode('$carrier$number');
    if (day < 1 || day > 366 || code.isEmpty)
      throw const FormatException('BCBP uçuş/gün bilgisi geçersiz.');
    final next = offset + 37 + int.parse(lengthText, radix: 16);
    if (next > s.length)
      throw const FormatException('BCBP değişken alanı eksik.');
    result.add(
      BoardingPass(
        fullName: name,
        pnr: pnr,
        origin: origin,
        destination: destination,
        flightCode: code,
        seat: seat,
        sequence: sequence,
        julianDay: day,
      ),
    );
    offset = next;
  }
  return result;
}

BoardingPass selectBcbpLeg(
  List<BoardingPass> legs,
  String expected,
  String date,
) {
  final hits = legs
      .where((p) => validationError(p, expected, date) == null)
      .toList();
  if (hits.length != 1)
    throw const FormatException(
      'Uçuşa ait tek ve doğrulanmış segment bulunamadı.',
    );
  return hits.single;
}

String? validationError(BoardingPass p, String expected, String date, {
  String expectedOrigin = 'DLM', String? expectedDestination,
}) {
  final d = strictDate(date);
  if (d == null) return 'Uçuş tarihi tanımlı/geçerli değil.';
  if (!flightCodesMatch(expected, p.flightCode))
    return 'Uçuş numarası eşleşmiyor.';
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(expectedOrigin) || p.origin != expectedOrigin) return 'Kalkış havalimanı eşleşmiyor.';
  if (expectedDestination != null &&
      (!RegExp(r'^[A-Z]{3}$').hasMatch(expectedDestination) || p.destination != expectedDestination)) {
    return 'Varış havalimanı eksik veya eşleşmiyor.';
  }
  if (p.julianDay != null) {
    final julian = d.difference(DateTime.utc(d.year)).inDays + 1;
    if (p.julianDay != julian) return 'Uçuş günü eşleşmiyor.';
  } else if (strictDate(p.travelDate ?? '') == null || p.travelDate != date) {
    return 'Uçuş tarihi eksik veya eşleşmiyor.';
  }
  if (p.fullName.trim().isEmpty || p.seat.isEmpty)
    return 'Yolcu adı/koltuk doğrulanamadı.';
  return null;
}

List<String> _nameForms(String name) {
  final s = name
      .toUpperCase()
      .replaceAll('İ', 'I')
      .replaceAll('Ş', 'S')
      .replaceAll('Ğ', 'G')
      .replaceAll('Ü', 'U')
      .replaceAll('Ö', 'O')
      .replaceAll('Ç', 'C');
  const titles = [
    'MASTER',
    'MSTR',
    'MISS',
    'MRS',
    'MR',
    'MS',
    'DR',
    'INF',
    'INFT',
  ];
  String clean(String v) => v
      .replaceAll(RegExp(r'[^A-Z ]'), ' ')
      .split(' ')
      .where((t) => t.isNotEmpty && !titles.contains(t))
      .join(' ');
  final forms = <String>[clean(s.replaceAll('/', ' '))];
  if (s.contains('/')) {
    final pieces = s.split('/');
    var given = pieces.last.trim();
    for (final title in titles) {
      if (given.endsWith(title) && given.length > title.length + 1) {
        given = given.substring(0, given.length - title.length);
        forms.add(clean('${pieces.first} $given'));
        break;
      }
    }
    forms.add(clean('$given ${pieces.first}'));
  }
  return forms.where((f) => f.split(' ').length >= 2).toList();
}

bool watchlistMatches(
  String scanned,
  String watchName, {
  String pnr = '',
  String watchPnr = '',
}) {
  // Shared family PNR alone must not label every family member a match.
  for (final a in _nameForms(scanned)) {
    for (final b in _nameForms(watchName)) {
      final aa = a.split(' ')..sort(), bb = b.split(' ')..sort();
      if (aa.join() == bb.join()) return true;
      if (scanned.contains('/') || watchName.contains('/')) {
        if (a.replaceAll(' ', '') == b.replaceAll(' ', '')) return true;
      }
    }
  }
  return false;
}
