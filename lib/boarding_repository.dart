import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'boarding_validation.dart';

class DuplicateBoarding implements Exception {}

/// Transactions intentionally require a connection. Never report queued writes
/// as completed boarding. Locks serialize competing scans from multiple devices.
class BoardingRepository {
  final DocumentReference<Map<String, dynamic>> flight;
  final String uid;
  BoardingRepository(this.flight, this.uid);
  String _key(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  bool _boarded(Map<String, dynamic> d) =>
      ['PREBOARDED', 'DFT_BOARDED'].contains(d['status']);

  Future<bool> board(
    BoardingPass pass, {
    required bool random,
    required bool watchlist,
    required bool manual,
    String? adultId,
  }) async {
    final wl = await flight
        .collection('watchlist')
        .get(const GetOptions(source: Source.server));
    watchlist =
        watchlist ||
        wl.docs.any(
          (d) => watchlistMatches(
            pass.fullName,
            (d.data()['fullName'] ?? '').toString(),
            pnr: pass.pnr,
          ),
        );
    if (watchlist && !random)
      throw Exception(
        'Watchlist güncellendi. Yalnız DFT Random kullanılabilir.',
      );
    final seatDocs = await flight
        .collection('pax')
        .where('seat', isEqualTo: pass.seat)
        .get(const GetOptions(source: Source.server));
    final nameKey = pass.fullName.toUpperCase().replaceAll(
      RegExp(r'[^A-Z]'),
      '',
    );
    final same = seatDocs.docs.where((d) => watchlistMatches(pass.fullName,
      (d.data()['fullName'] ?? '').toString())).toList();
    if (same.length > 1)
      throw Exception(
        'Birden çok eski yolcu kaydı var; yönetici incelemesi gerekli.',
      );
    final identity = pass.sequence.isNotEmpty
        ? 'seq:${pass.sequence.replaceFirst(RegExp(r'^0+'), '')}'
        : 'name:$nameKey:${pass.pnr}';
    final keyRef = flight.collection('boarding_keys').doc(_key(identity));
    final paxRef = same.isNotEmpty
        ? same.single.reference
        : flight.collection('pax').doc(_key(identity));
    final seatRef = flight.collection('seat_locks').doc(pass.seat);
    final logRef = flight.collection('logs').doc();
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final f = (await tx.get(flight)).data();
      final key = (await tx.get(keyRef)).data();
      final old = (await tx.get(paxRef)).data() ?? {};
      final lock = (await tx.get(seatRef)).data();
      if (f == null || f['closed'] == true)
        throw Exception('Uçuş kapalı/bulunamadı.');
      final error = validationError(
        pass,
        (f['flightCode'] ?? '').toString(),
        (f['etdDateText'] ?? '').toString(),
      );
      if (error != null) throw Exception(error);
      if (key?['active'] == true || _boarded(old)) throw DuplicateBoarding();
      final occupantIds = lock != null
          ? List<String>.from(lock['paxIds'] ?? [])
          : seatDocs.docs
                .where((d) => _boarded(d.data()))
                .map((d) => d.id)
                .toList();
      // Read all occupants inside the transaction; all reads precede writes.
      final occupants = <String, Map<String, dynamic>>{};
      for (final id in occupantIds) {
        final data = (await tx.get(flight.collection('pax').doc(id))).data();
        if (data != null && _boarded(data)) occupants[id] = data;
      }
      if (occupants.isNotEmpty) {
        if (occupants.containsKey(paxRef.id) ||
            adultId == null ||
            !occupants.containsKey(adultId) ||
            occupants[adultId]?['adultPaxId'] != null ||
            occupants.length >= 2)
          throw DuplicateBoarding();
      } else if (adultId != null) {
        throw Exception(
          'Bağlı yetişkin artık board edilmiş değil; tekrar doğrulayın.',
        );
      }
      final now = FieldValue.serverTimestamp();
      tx.set(paxRef, {
        'fullName': pass.fullName,
        'surname': pass.surname, 'givenName': pass.givenName, 'title': pass.title,
        'seat': pass.seat,
        'pnr': pass.pnr,
        'sequence': pass.sequence,
        'status': random ? 'DFT_BOARDED' : 'PREBOARDED',
        'watchlistMatch': watchlist,
        'boardedAt': now,
        'boardedByUid': uid,
        'boardedByEmail': FirebaseAuth.instance.currentUser?.email ?? '',
        'manualBoarded': manual,
        'validationFlightCode': normalizeFlightCode(f['flightCode'].toString()),
        'validationDate': f['etdDateText'],
        'validationOrigin': pass.origin,
        'boardingKey': keyRef.id,
        'seatLock': seatRef.id,
        'adultPaxId': adultId,
        'createdAt': old['createdAt'] ?? now,
      }, SetOptions(merge: true));
      tx.set(keyRef, {
        'active': true,
        'paxId': paxRef.id,
        'byUid': uid,
        'at': now,
      });
      tx.set(seatRef, {
        'paxIds': [...occupants.keys, paxRef.id],
        'byUid': uid,
        'at': now,
      });
      final times = Map<String, dynamic>.from(f['opTimes'] ?? {});
      final localTime = DateTime.now().toIso8601String();
      times.putIfAbsent('ILK_YOLCU_MURACAAT', () => localTime);
      times['SON_YOLCU_MURACAAT'] = localTime;
      times.putIfAbsent('BOARDING_STARTED', () => localTime);
      tx.update(flight, {'opTimes': times});
      tx.set(logRef, {
        'type': 'PAX_BOARDED',
        'byUid': uid,
        'at': now,
        'meta': {
          'paxId': paxRef.id,
          'random': random,
          'manual': manual,
          'watchlistMatch': watchlist,
        },
      });
    });
    return watchlist;
  }

  /// Offload an adult and its linked infant atomically. The UI must confirm
  /// this relationship before calling this method.
  Future<void> offload(DocumentReference<Map<String, dynamic>> pax) async {
    final linked = await flight
        .collection('pax')
        .where('adultPaxId', isEqualTo: pax.id)
        .get(const GetOptions(source: Source.server));
    if (linked.docs.any((d) => _boarded(d.data()))) {
      throw Exception('Bağlı infant mevcut. Önce infant kaydını offload edin.');
    }
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final f = (await tx.get(flight)).data();
      final d = (await tx.get(pax)).data();
      if (f == null || f['closed'] == true)
        throw Exception('Kapalı uçuşta offload yapılamaz.');
      if (d == null || !_boarded(d)) return;
      final lockId = d['seatLock']?.toString();
      final lockRef = lockId == null
          ? null
          : flight.collection('seat_locks').doc(lockId);
      final lock = lockRef == null ? null : (await tx.get(lockRef)).data();
      // Recheck linked occupants inside the same transaction.
      final ids = List<String>.from(lock?['paxIds'] ?? []);
      for (final id in ids.where((id) => id != pax.id)) {
        final other = (await tx.get(flight.collection('pax').doc(id))).data();
        if (other?['adultPaxId'] == pax.id && _boarded(other!)) {
          throw Exception('Önce bağlı infant kaydını offload edin.');
        }
      }
      final now = FieldValue.serverTimestamp();
      tx.update(pax, {
        'status': 'OFFLOADED',
        'offloadedAt': now,
        'offloadedByUid': uid,
        'offloadedByEmail': FirebaseAuth.instance.currentUser?.email ?? '',
      });
      if (d['boardingKey'] != null) {
        tx.set(
          flight.collection('boarding_keys').doc(d['boardingKey'].toString()),
          {'active': false, 'paxId': pax.id, 'byUid': uid, 'at': now},
        );
      }
      if (lockRef != null)
        tx.set(lockRef, {
          'paxIds': ids.where((id) => id != pax.id).toList(),
          'byUid': uid,
          'at': now,
        });
      tx.set(flight.collection('logs').doc(), {
        'type': 'PAX_OFFLOADED',
        'byUid': uid,
        'at': now,
        'meta': {'paxId': pax.id},
      });
    });
  }
}
