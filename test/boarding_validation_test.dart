import 'package:flutter_test/flutter_test.dart';
import 'package:gozen_boarding_pro/boarding_validation.dart';

const or3057 =
    'M1AKBULUT/FATIH        G1KDYB DLMAMSOR 3057 267Y010G0227 148>5181WO4267BOR 00000000000002A0000000000000 2                          N';
const ls1730 =
    'M1HELLEWELL/BLAKEMR   E3Z58D4 DLMMANLS 1730 294G032F0137 100>10000';
BoardingPass manual({
  String flight = 'LS1850',
  String date = '2026-10-21',
  String origin = 'DLM',
}) => BoardingPass(
  fullName: 'HELLEWELL/BLAKE',
  pnr: 'ABC123',
  origin: origin,
  destination: 'MAN',
  flightCode: flight,
  seat: '32F',
  sequence: '',
  travelDate: date,
);
void main() {
  test('OR3057 real card has exact mandatory fields', () {
    final p = parseBcbp(or3057).single;
    expect(p.fullName, 'AKBULUT/FATIH');
    expect(p.pnr, 'G1KDYB');
    expect(p.origin, 'DLM');
    expect(p.destination, 'AMS');
    expect(p.flightCode, 'OR3057');
    expect(p.julianDay, 267);
    expect(p.seat, '10G');
    expect(p.sequence, '0227');
    expect(validationError(p, 'TFL3057', '2026-09-24'), isNull);
  });
  test('LS1730 real card has exact fields and Julian date', () {
    final p = parseBcbp(ls1730).single;
    expect(p.fullName, 'HELLEWELL/BLAKEMR');
    expect(p.pnr, '3Z58D4');
    expect(p.flightCode, 'LS1730');
    expect(p.seat, '32F');
    expect(p.sequence, '0137');
    expect(p.origin, 'DLM');
    expect(p.destination, 'MAN');
    expect(p.julianDay, 294);
    expect(validationError(p, 'EXS1730', '2026-10-21'), isNull);
    expect(validationError(p, 'LS1730', '2026-10-20'), isNotNull);
  });
  test('strict number, carrier and suffix checks', () {
    expect(flightCodesMatch('LS1850', 'LS185'), isFalse);
    expect(flightCodesMatch('LS1850', '1850'), isFalse);
    expect(flightCodesMatch('LS1850', 'LS1851'), isFalse);
    expect(flightCodesMatch('LS1850', 'LS1850A'), isFalse);
    expect(flightCodesMatch('LS185', 'EXS0185'), isTrue);
    expect(flightCodesMatch('OR3057', 'TFL3057'), isTrue);
    expect(flightCodesMatch('TOM123', 'BY0123'), isTrue);
    expect(flightCodesMatch('X3123', 'TUI123'), isTrue);
  });
  test('origin and complete calendar date are mandatory', () {
    expect(
      validationError(manual(origin: 'BJV'), 'LS1850', '2026-10-21'),
      isNotNull,
    );
    for (final d in ['', '21OCT', '2026-02-30', '2026-10-20', '2025-10-21']) {
      expect(
        validationError(manual(date: d), 'LS1850', '2026-10-21'),
        isNotNull,
      );
    }
    expect(validationError(manual(), 'LS1850', '2026-10-21'), isNull);
    expect(validationError(manual(), 'LS1850', ''), isNotNull);
  });
  test(
    'corruption, collapsed spaces, truncated variable fields fail closed',
    () {
      for (final s in [
        '',
        ls1730.substring(0, 55),
        or3057.substring(0, 100),
        ls1730.replaceAll(' ', ''),
        'S' + ls1730.substring(1),
      ]) {
        expect(() => parseBcbp(s), throwsFormatException);
      }
    },
  );
  test(
    'multi segment uses declared hex lengths and selects exactly one leg',
    () {
      final first = ls1730.substring(0, 58) + '00';
      final next = or3057.substring(23, 58) + '00';
      final legs = parseBcbp('M2' + first.substring(2) + next);
      expect(legs.length, 2);
      expect(selectBcbpLeg(legs, 'LS1730', '2026-10-21').seat, '32F');
      expect(
        () => selectBcbpLeg(legs, 'LS1730', '2026-10-20'),
        throwsFormatException,
      );
      final repeated = parseBcbp(
        'M2' + first.substring(2) + first.substring(23),
      );
      expect(
        () => selectBcbpLeg(repeated, 'LS1730', '2026-10-21'),
        throwsFormatException,
      );
    },
  );
  test('Julian day 366 only matches leap-year last day', () {
    final p = parseBcbp(ls1730.replaceRange(44, 47, '366')).single;
    expect(validationError(p, 'LS1730', '2024-12-31'), isNull);
    expect(validationError(p, 'LS1730', '2026-12-31'), isNotNull);
  });
  test('watchlist supports surname slash, order and safe titles', () {
    expect(watchlistMatches('HELLEWELL/BLAKEMR', 'BLAKE HELLEWELL'), isTrue);
    expect(watchlistMatches('AKBULUT/FATIH', 'FATIH AKBULUT MR'), isTrue);
    expect(watchlistMatches('SMITH/ANNA MARIA', 'MARIA ANNA SMITH'), isTrue);
    expect(watchlistMatches('ZEYNEP TURK', 'ZEYNEP KOPUZ'), isFalse);
    expect(watchlistMatches('JOHN PAUL SMITH', 'JOHN PAUL JONES'), isFalse);
    expect(
      watchlistMatches(
        'SMITH/JOHN',
        'SMITH/JANE',
        pnr: 'ABC123',
        watchPnr: 'ABC123',
      ),
      isFalse,
    );
    expect(watchlistMatches('SMITH/JOHN', 'SMITH/JOHNNY'), isFalse);
    expect(watchlistMatches('AKBULUT/FATIH', 'AKBULUT/FATI'), isFalse);
  });
}
