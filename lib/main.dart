
// GOZEN BOARDING PRO (Flutter) - main.dart
// Platform: Android + iOS
// Firebase Project ID: volkan-589c1
// Report export: Share as file (CSV readable by Excel)
//
// NOTE: Add these dependencies in pubspec.yaml (versions are examples; pick latest compatible):
//   firebase_core: ^3.0.0
//   firebase_auth: ^5.0.0
//   cloud_firestore: ^5.0.0
//   share_plus: ^10.0.0
//   path_provider: ^2.1.4
//   intl: ^0.19.0
//
// Then run: flutterfire configure (or add google-services.json + GoogleService-Info.plist)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Force login prompt each app start (no session persistence)
  await FirebaseAuth.instance.signOut();
runApp(const GozenBoardingApp());
}

class GozenBoardingApp extends StatefulWidget {
  const GozenBoardingApp({super.key});

  @override
  State<GozenBoardingApp> createState() => _GozenBoardingAppState();
}

class _GozenBoardingAppState extends State<GozenBoardingApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void setThemeMode(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override


  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GOZEN BOARDING PRO',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
      ),
      home: AuthGate(
        onThemeChanged: setThemeMode,
        themeMode: _themeMode,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  final void Function(bool isDark) onThemeChanged;
  final ThemeMode themeMode;

  const AuthGate({
    super.key,
    required this.onThemeChanged,
    required this.themeMode,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        if (snap.data == null) {
          return LoginScreen(
            onThemeChanged: onThemeChanged,
            themeMode: themeMode,
          );
        }
        return HomeScreen(
          onThemeChanged: onThemeChanged,
          themeMode: themeMode,
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ==========================
// Data models (simple maps)
// ==========================

enum PaxStatus { none, preboarded, dftBoarded, offloaded }

String paxStatusLabel(PaxStatus s) {
  switch (s) {
    case PaxStatus.preboarded:
      return 'PREBOARDED';
    case PaxStatus.dftBoarded:
      return 'DFT_BOARDED';
    case PaxStatus.offloaded:
      return 'OFFLOADED';
    case PaxStatus.none:
    default:
      return 'NONE';
  }
}

PaxStatus paxStatusFromString(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'PREBOARDED':
      return PaxStatus.preboarded;
    case 'DFT_BOARDED':
      return PaxStatus.dftBoarded;
    case 'OFFLOADED':
      return PaxStatus.offloaded;
    default:
      return PaxStatus.none;
  }
}

class Db {
  static final fs = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> flights() =>
      fs.collection('flights');

  static CollectionReference<Map<String, dynamic>> users() {
    return FirebaseFirestore.instance.collection('users');
  }

  static DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      fs.collection('users').doc(uid);

  static CollectionReference<Map<String, dynamic>> invites() =>
      fs.collection('invites');
}


// ---------------- Offline Queue ----------------
// Stores operations locally (SharedPreferences) while offline mode is ON,
// and flushes them sequentially when offline mode is turned OFF.
class OfflineQueue {
  OfflineQueue(this.flightId);

  final String flightId;

  String get _key => 'offlineQueue_v1_$flightId';

  Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      // Corrupt queue -> reset
      await prefs.remove(_key);
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _save(List<Map<String, dynamic>> ops) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(ops));
  }

  Future<void> enqueue(Map<String, dynamic> op) async {
    final ops = await load();
    ops.add(op);
    await _save(ops);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<int> count() async {
    final ops = await load();
    return ops.length;
  }

  // Removes the first element (FIFO) after successful apply.
  Future<void> popFirst() async {
    final ops = await load();
    if (ops.isEmpty) return;
    ops.removeAt(0);
    await _save(ops);
  }
}
// ==========================
// Login
// ==========================

class LoginScreen extends StatefulWidget {
  final void Function(bool isDark) onThemeChanged;
  final ThemeMode themeMode;

  const LoginScreen({
    super.key,
    required this.onThemeChanged,
    required this.themeMode,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _loginOrRegister() async {
    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final email = _email.text.trim();
      final pass = _pass.text;

      if (email.isEmpty || pass.isEmpty) {
        throw Exception('Kullanıcı adı (email) ve şifre zorunlu.');
      }

      UserCredential cred;
      try {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: pass,
        );
      } on FirebaseAuthException catch (e) {
        // If user not found, auto-register (simple flow).
        if (e.code == 'user-not-found') {
          cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: pass,
          );
        } else {
          rethrow;
        }
      }

      // Create user profile if missing.
      final uid = cred.user!.uid;
      final ref = Db.userDoc(uid);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'email': email,
          'displayName': (email.contains('@') ? email.split('@').first : email),
          'usernameLower': (email.contains('@') ? email.split('@').first : email).toLowerCase(),
          'role': 'Agent', // Agent or Supervisor
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Ensure email updated
        await ref.set({
          'email': email,
          'updatedAt': FieldValue.serverTimestamp(),
          'displayName': (email.contains('@') ? email.split('@').first : email),
          'usernameLower': (email.contains('@') ? email.split('@').first : email).toLowerCase(),
          }, SetOptions(merge: true));
      }
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        actions: [
          Row(
            children: [
              const Icon(Icons.dark_mode),
              Switch(
                value: isDark,
                onChanged: (v) => widget.onThemeChanged(v),
              ),
              const SizedBox(width: 8),
            ],
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Kullanıcı Adı (email)',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      decoration: const InputDecoration(labelText: 'Şifre'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    if (_err != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _err!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _loginOrRegister,
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Giriş / Kayıt'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Not: Bu demo akışta kullanıcı yoksa otomatik kayıt olur.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================
// Home: Flights (create/list/join)
// ==========================

class HomeScreen extends StatefulWidget {
  final void Function(bool isDark) onThemeChanged;
  final ThemeMode themeMode;

  const HomeScreen({
    super.key,
    required this.onThemeChanged,
    required this.themeMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final String _uid = FirebaseAuth.instance.currentUser!.uid;

  Future<String> _getRole() async {
    final snap = await Db.userDoc(_uid).get();
    return (snap.data()?['role'] ?? 'Agent').toString();
  }

  Future<void> _logout() async => FirebaseAuth.instance.signOut();

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;

    return FutureBuilder<String>(
      future: _getRole(),
      builder: (context, snap) {
        final role = snap.data ?? 'Agent';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Uçuşlar'),
            actions: [
          IconButton(
            tooltip: 'Kullanıcı Adı',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () async {
              final u = FirebaseAuth.instance.currentUser;
              if (u == null) return;
              final doc = await Db.userDoc(u.uid).get();
              final code = (doc.data()?['usernameLower'] ?? '').toString();
              if (!context.mounted) return;
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Kullanıcı Adın'),
                  content: SelectableText(
                    code.isEmpty ? '—' : code,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
                  ],
                ),
              );
            },
          ),

              Row(
                children: [
                  const Icon(Icons.dark_mode),
                  Switch(
                    value: isDark,
                    onChanged: (v) => widget.onThemeChanged(v),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              IconButton(
                tooltip: 'Profil',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(uid: _uid),
                    ),
                  );
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.person),
              ),
              IconButton(
                tooltip: 'Çıkış',
                onPressed: _logout,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final res = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateFlightScreen(
                    uid: _uid,
                    email: (FirebaseAuth.instance.currentUser?.email ?? ''),
                  ),
                ),
              );
              if (!mounted) return;
              if (res != null && res['created'] == true && (res['flightId'] ?? '').toString().isNotEmpty) {
                final flightId = res['flightId'].toString();
                // Listeyi tazele ve direkt uçuşa gir
                setState(() {});
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FlightDetailScreen(
                      flightId: flightId,
                      currentUid: _uid,
                      forceAllow: true,
                    ),
                  ),
                );
              } else {
                setState(() {});
              }
},
            icon: const Icon(Icons.add),
            label: const Text('Uçuş Oluştur'),
          ),
          body: Column(
            children: [
              _PendingInvitesBar(uid: _uid),
              Expanded(
                child: FlightsList(uid: _uid, role: role),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  Future<Map<String, dynamic>> _load() async {
    final snap = await Db.userDoc(widget.uid).get();
    return snap.data() ?? {};
  }

  Future<void> _setRole(String role) async {
    setState(() => _busy = true);
    try {
      await Db.userDoc(widget.uid).set({'role': role}, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snap) {
        final data = snap.data ?? {};
        final email = (data['email'] ?? '').toString();
        final role = (data['role'] ?? 'Agent').toString();

        return Scaffold(
          appBar: AppBar(title: const Text('Profil')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Email'),
                  subtitle: Text(email),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Uygulama Kullanıcı Rolü'),
                  subtitle: const Text('Supervisor davetsiz her uçuşa girebilir.'),
                  trailing: DropdownButton<String>(
                    value: role,
                    items: const [
                      DropdownMenuItem(value: 'Agent', child: Text('Agent')),
                      DropdownMenuItem(
                          value: 'Supervisor', child: Text('Supervisor')),
                    ],
                    onChanged: _busy ? null : (v) => _setRole(v ?? 'Agent'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Not: Personel sekmesindeki roller ayrı; bu sadece uygulama erişim rolüdür.',
                  style: TextStyle(fontSize: 12),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PendingInvitesBar extends StatelessWidget {
  final String uid;
  const _PendingInvitesBar({required this.uid});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.isEmpty) return const SizedBox.shrink();

    final q = Db.invites()
        .where('inviteeUid', isEqualTo: uid)
        .where('status', isEqualTo: 'PENDING');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Material(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.mail),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Bekleyen davet var: ${docs.length}'),
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvitesScreen(uid: uid),
                      ),
                    );
                  },
                  child: const Text('Görüntüle'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class InvitesScreen extends StatelessWidget {
  final String uid;
  const InvitesScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final q = Db.invites()
        .where('inviteeUid', isEqualTo: uid)
        .where('status', isEqualTo: 'PENDING');

    return Scaffold(
      appBar: AppBar(title: const Text('Davetler')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Bekleyen davet yok.'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final flightId = (data['flightId'] ?? '').toString();
              final flightCode = (data['flightCode'] ?? '').toString();
              return ListTile(
                title: Text('Uçuş: $flightCode'),
                subtitle: Text('Flight ID: $flightId'),
                trailing: FilledButton(
                  onPressed: () async {
                    // Accept: add participant UID to flight + mark invite accepted
                    final flightRef = Db.flights().doc(flightId);
                    await Db.fs.runTransaction((tx) async {
                      final fSnap = await tx.get(flightRef);
                      if (!fSnap.exists) throw Exception('Uçuş bulunamadı.');
                      final participants =
                          List<String>.from(fSnap.data()?['participants'] ?? []);
                      if (!participants.contains(uid)) participants.add(uid);
                      tx.update(flightRef, {'participants': participants});
                      tx.update(d.reference, {
                        'status': 'ACCEPTED',
                        'acceptedAt': FieldValue.serverTimestamp(),
                        'acceptedByUid': uid,
                      });
                    });

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Davet kabul edildi.')),
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Kabul Et'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FlightsList extends StatelessWidget {
  final String uid;
  final String role;

  const FlightsList({super.key, required this.uid, required this.role});

  @override
  Widget build(BuildContext context) {
    // For Supervisor: show last 50 flights (simple). For Agents: only owner or participant.
    Query<Map<String, dynamic>> q;
    if (role == 'Supervisor') {
      q = Db.flights().orderBy('createdAt', descending: true).limit(50);
    } else {
      // Firestore limitation: cannot OR owner==uid OR array-contains uid in one query easily.
      // We do two queries and merge client-side.
      return _AgentHomeBody(uid: uid, email: (FirebaseAuth.instance.currentUser?.email ?? ''));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Henüz uçuş yok.'));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data();
            final code = (data['flightCode'] ?? '').toString();
            final booked = (data['bookedPax'] ?? 0).toString();
            final ownerUid = (data['ownerUid'] ?? '').toString();
            final isOwner = ownerUid == uid;

            return ListTile(
              title: Text('$code  •  Booked: $booked'),
              subtitle: Text(isOwner ? 'Sahibi sensin' : 'Supervisor erişimi'),
              trailing: FilledButton(
                onPressed: () async {
                  // Supervisor can enter without invite, agents need owner/participant.
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FlightDetailScreen(
                        flightId: doc.id,
                        currentUid: uid,
                        forceAllow: role == 'Supervisor',
                      ),
                    ),
                  );
                },
                child: const Text('Katıl'),
              ),
            );
          },
        );
      },
    );
  }
}


class _AgentHomeBody extends StatelessWidget {
  final String uid;
  final String email;
  const _AgentHomeBody({required this.uid, required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PendingInvitesList(uid: uid, email: email),
        const Divider(height: 1),
        Expanded(child: _MergedAgentFlights(uid: uid)),
      ],
    );
  }
}

class _PendingInvitesList extends StatelessWidget {
  final String uid;
  final String email;
  const _PendingInvitesList({required this.uid, required this.email});

  Future<void> _acceptInvite(
    BuildContext context, {
    required QueryDocumentSnapshot<Map<String, dynamic>> inviteDoc,
  }) async {
    final data = inviteDoc.data();
    final flightId = (data['flightId'] ?? '').toString();
    if (flightId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Davet verisi hatalı (flightId yok).')),
      );
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final inviteRef = inviteDoc.reference;

      // 1) Invite ACCEPTED
      batch.update(inviteRef, {
        'status': 'ACCEPTED',
        'acceptedByUid': uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // 2) Flight participants içine kendini ekle (self-join)
      final flightRef = Db.flights().doc(flightId);
      batch.update(flightRef, {
        'participants': FieldValue.arrayUnion([uid]),
      });

      await batch.commit();

      if (!context.mounted) return;

      // Direkt uçuşa gir
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FlightDetailScreen(
            flightId: flightId,
            currentUid: uid,
            forceAllow: true,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Davet kabul edilemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (email.isEmpty) return const SizedBox.shrink();

    final q = FirebaseFirestore.instance
        .collection('invites')
        .where('inviteeUid', isEqualTo: uid)
        .limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        final docsAll = snap.data?.docs ?? [];
        final docs = docsAll.where((d) => (d.data()['status'] ?? '').toString() == 'PENDING').toList();

        if (docs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Davetler',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...docs.map((d) {
                    final data = d.data();
                    final code = (data['flightCode'] ?? '').toString();
                    final inviter = (data['createdByUid'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(code.isEmpty ? '—' : code),
                      subtitle: Text(inviter.isEmpty ? 'Davet' : 'Davet eden: $inviter'),
                      trailing: FilledButton(
                        onPressed: () => _acceptInvite(context, inviteDoc: d),
                        child: const Text('Katıl'),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MergedAgentFlights extends StatelessWidget {
  final String uid;
  const _MergedAgentFlights({required this.uid});

  @override
  Widget build(BuildContext context) {
    final ownedQ = Db.flights()
        .where('ownerUid', isEqualTo: uid)
        .limit(50);

    final partQ = Db.flights()
        .where('participants', arrayContains: uid)
        .limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ownedQ.snapshots(),
      builder: (context, snapOwned) {
        if (snapOwned.hasError) {
          return Center(child: Text('Uçuş listesi okunamadı: ${snapOwned.error}'));
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: partQ.snapshots(),
          builder: (context, snapPart) {
            if (snapPart.hasError) {
              return Center(child: Text('Uçuş listesi okunamadı: ${snapPart.error}'));
            }
            final owned = snapOwned.data?.docs ?? [];
            final part = snapPart.data?.docs ?? [];
            final map = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
            for (final d in owned) map[d.id] = d;
            for (final d in part) map[d.id] = d;
            final docs = map.values.toList()
              ..sort((a, b) {
                final at = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                final bt = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                return bt.compareTo(at);
              });

            if (docs.isEmpty) {
              return const Center(
                child: Text('Henüz erişebildiğin uçuş yok. Davet bekliyor olabilirsin.'),
              );
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final doc = docs[i];
                final data = doc.data();
                final code = (data['flightCode'] ?? '').toString();
                final booked = (data['bookedPax'] ?? 0).toString();
                final ownerUid = (data['ownerUid'] ?? '').toString();
                final isOwner = ownerUid == uid;
                final isParticipant =
                    List<String>.from(data['participants'] ?? []).contains(uid);

                return ListTile(
                  title: Text('$code  •  Booked: $booked'),
                  subtitle: Text(isOwner
                      ? 'Sahibi sensin'
                      : isParticipant
                          ? 'Davetli katılımcı'
                          : '—'),
                  trailing: FilledButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FlightDetailScreen(
                            flightId: doc.id,
                            currentUid: uid,
                            forceAllow: true,
                          ),
                        ),
                      );
                    },
                    child: const Text('Katıl'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ==========================
// Create Flight
// ==========================

class CreateFlightScreen extends StatefulWidget {
  final String uid;
  final String email;
  const CreateFlightScreen({super.key, required this.uid, required this.email});

  @override
  State<CreateFlightScreen> createState() => _CreateFlightScreenState();
}

class _CreateFlightScreenState extends State<CreateFlightScreen> {
  final _flightCode = TextEditingController();
  final _bookedPax = TextEditingController();
  final List<String> _watchlistNames = [];

  bool _busy = false;
  String? _err;


  bool _isValidFlightCode(String s) {
    // Examples: LS976, BA2245
    return RegExp(r'^[A-Z]{2}\d{3,4}$').hasMatch(s);
  }

  Future<void> _addWatchlistDialog() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('WatchList Yolcu Ekle'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'İsim Soyisim'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ekle')),
        ],
      ),
    );

    if (ok == true) {
      final name = c.text.trim();
      if (name.isNotEmpty) {
        setState(() => _watchlistNames.add(name));
      }
    }
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final code = _flightCode.text.trim().toUpperCase();
      if (!_isValidFlightCode(code)) {
        throw Exception('Uçuş kodu formatı hatalı. Örn: LS976 / BA2245');
      }

      final booked = int.tryParse(_bookedPax.text.trim()) ?? 0;
      final flightRef = Db.flights().doc();

      // 1) Flight dokümanını önce oluştur (tek write)
      await flightRef.set({
        'flightCode': code,
        'bookedPax': booked,
        'ownerUid': widget.uid,
        'participants': <String>[widget.uid],
        'createdAt': Timestamp.now(),
        'offlineMode': false,
        'opTimes': <String, dynamic>{},
      });

      // 2) WatchList'i sonra yaz (flight artık var)
      final wlCol = flightRef.collection('watchlist');
      for (final n in _watchlistNames) {
        await wlCol.add({
          'fullName': n,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 3) Log
      await flightRef.collection('logs').add({
        'type': 'FLIGHT_CREATED',
        'byUid': widget.uid,
        'byEmail': widget.email,
        'at': FieldValue.serverTimestamp(),
        'meta': {'watchlistCount': _watchlistNames.length},
      });

      if (!mounted) return;

      // Home ekrana flightId dön: otomatik açmak için
      Navigator.pop(context, <String, dynamic>{
        'created': true,
        'flightId': flightRef.id,
      });
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uçuş Oluştur')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _flightCode,
                    decoration: const InputDecoration(
                      labelText: 'Uçuş Kodu (LS976 / BA2245)',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bookedPax,
                    decoration: const InputDecoration(labelText: 'Booked Pax'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'WatchList',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _addWatchlistDialog,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Ekle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ChipsWrap(
                    items: _watchlistNames,
                    onRemove: (i) => setState(() => _watchlistNames.removeAt(i)),
                  ),
                  if (_err != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _err!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _create,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Uçuşu Kaydet'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipsWrap extends StatelessWidget {
  final List<String> items;
  final void Function(int index) onRemove;

  const _ChipsWrap({required this.items, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('WatchList boş.'),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < items.length; i++)
          InputChip(
            label: Text(items[i]),
            onDeleted: () => onRemove(i),
          )
      ],
    );
  }
}

// ==========================
// Flight Detail (7 tabs)
// ==========================

class FlightDetailScreen extends StatefulWidget {
  final String flightId;
  final String currentUid;
  final bool forceAllow;

  const FlightDetailScreen({
    super.key,
    required this.flightId,
    required this.currentUid,
    required this.forceAllow,
  });

  @override
  State<FlightDetailScreen> createState() => _FlightDetailScreenState();
}

class _FlightDetailScreenState extends State<FlightDetailScreen> {
  late final flightRef = Db.flights().doc(widget.flightId);

  Future<bool> _isSupervisor() async {
    try {
      final u = await Db.userDoc(widget.currentUid).get();
      return (u.data()?['role'] ?? '').toString() == 'Supervisor';
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteFlightAndNotify({required String flightCode}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Uçuşu sil'),
        content: Text('Uçuş silinecek: $flightCode\n\nSadece Supervisor silebilir. Devam edilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;

    // 1) Logları çek (özet mail içeriği)
    String report = '';
    try {
      final f = await flightRef.get();
      final data = f.data() ?? {};
      final owner = (data['ownerUid'] ?? '').toString();
      final participants = (data['participants'] is List) ? List<String>.from(data['participants']) : <String>[];
      final createdAt = data['createdAt'];
      report += 'GOZEN BOARDING PRO\n';
      report += 'Silinen Uçuş: $flightCode\n';
      report += 'FlightId: ${flightRef.id}\n';
      report += 'OwnerUid: $owner\n';
      report += 'Participants: ${participants.join(', ')}\n';
      report += 'CreatedAt: $createdAt\n';
      report += 'DeletedByUid: ${widget.currentUid}\n';
      report += 'DeletedAt: ${DateTime.now().toIso8601String()}\n\n';

      // logs
      final logs = await flightRef.collection('logs').limit(500).get();
      report += '--- LOGS (up to 500) ---\n';
      for (final d in logs.docs) {
        report += '${d.id}: ${d.data()}\n';
      }
      report += '\n';

      // boardings/offloads counts
      final b = await flightRef.collection('boardings').get();
      final o = await flightRef.collection('offloads').get();
      report += 'BoardingsCount: ${b.size}\n';
      report += 'OffloadsCount: ${o.size}\n';
    } catch (e) {
      report += 'Report oluşturulamadı: $e\n';
    }

    // 2) Paylaş / mail taslağı (platforma göre mail uygulaması seçilebilir)
    try {
      await Share.share(
        'TO: vlkntskrn@gmail.com\nSUBJECT: GOZEN BOARDING PRO - Flight Deleted - $flightCode\n\n$report',
        subject: 'GOZEN BOARDING PRO - Flight Deleted - $flightCode',
      );
    } catch (_) {}

    // 3) Alt koleksiyonları sil (küçük dataset varsayımı). Büyük uçuşlarda Cloud Function önerilir.
    Future<void> deleteSubcollection(String name) async {
      while (true) {
        final snap = await flightRef.collection(name).limit(400).get();
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }

    try {
      for (final c in ['watchlist', 'boardings', 'offloads', 'logs', 'staff', 'equipment']) {
        await deleteSubcollection(c);
      }
      await flightRef.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uçuş silindi.')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silme başarısız: $e')));
    }
  }


  Future<_Access> _checkAccess() async {
    final doc = await flightRef.get();
    if (!doc.exists) return _Access(allowed: false, reason: 'Uçuş bulunamadı.');

    if (widget.forceAllow) return _Access(allowed: true, reason: null);

    // Supervisor: davetsiz tüm uçuşlara girebilir
    try {
      final u = await Db.userDoc(widget.currentUid).get();
      final role = (u.data()?['role'] ?? '').toString();
      if (role == 'Supervisor') return _Access(allowed: true, reason: null);
    } catch (_) {
      // ignore role read failures here; access will fall back to owner/participants
    }

    final data = doc.data()!;
    final owner = (data['ownerUid'] ?? '').toString();
    final participants = List<String>.from(data['participants'] ?? []);

    if (owner == widget.currentUid) return _Access(allowed: true, reason: null);
    if (participants.contains(widget.currentUid)) return _Access(allowed: true, reason: null);

    return _Access(
      allowed: false,
      reason: 'Bu uçuşa giriş için davet gerekli (Agent).',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Access>(
      future: _checkAccess(),
      builder: (context, snap) {
        final a = snap.data;
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (a == null || !a.allowed) {
          return Scaffold(
            appBar: AppBar(title: const Text('Uçuş')),
            body: Center(child: Text(a?.reason ?? 'Erişim yok.')),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: flightRef.snapshots(),
          builder: (context, flightSnap) {
            final f = flightSnap.data?.data();
            final code = (f?['flightCode'] ?? '—').toString();

            return DefaultTabController(
              length: 7,
              child: Scaffold(
                appBar: AppBar(
                  title: Text('Uçuş: $code'),
                  actions: [
                    FutureBuilder<bool>(
                      future: _isSupervisor(),
                      builder: (context, snapRole) {
                        final isSup = snapRole.data == true;
                        if (!isSup) return const SizedBox.shrink();
                        return IconButton(
                          tooltip: 'Uçuşu sil (Supervisor)',
                          icon: const Icon(Icons.delete_forever),
                          onPressed: () => _deleteFlightAndNotify(flightCode: code),
                        );
                      },
                    ),
                  ],
                  bottom: const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Scan'),
                      Tab(text: 'Yolcu Listesi'),
                      Tab(text: 'WatchList'),
                      Tab(text: 'Personel'),
                      Tab(text: 'Ekipman'),
                      Tab(text: 'Op. Times'),
                      Tab(text: 'Rapor'),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    ScanTab(flightRef: flightRef, currentUid: widget.currentUid),
                    PaxListTab(flightRef: flightRef, currentUid: widget.currentUid),
                    WatchlistTab(flightRef: flightRef, currentUid: widget.currentUid),
                    StaffTab(flightRef: flightRef),
                    EquipmentTab(flightRef: flightRef),
                    OpTimesTab(flightRef: flightRef, currentUid: widget.currentUid),
                    ReportTab(flightRef: flightRef, currentUid: widget.currentUid),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Access {
  final bool allowed;
  final String? reason;
  _Access({required this.allowed, required this.reason});
}

// ==========================
// Tab 1: Scan
// ==========================

class ScanTab extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> flightRef;
  final String currentUid;

  const ScanTab({super.key, required this.flightRef, required this.currentUid});

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> {
  bool _offline = false;
  bool _night = false;

  final _manualScan = TextEditingController();
  bool _busy = false;

  late final OfflineQueue _queue;
  int _queuedCount = 0;

  // Camera scanning (mobile/desktop); web uses manual input.
  late final MobileScannerController _scannerController;
  bool _manualTrigger = false;
  bool _armed = true; // when manualTrigger=false, always armed
  DateTime? _lastScanAt;
  String? _lastScanRaw;

  @override
  void initState() {
    super.initState();
    _queue = OfflineQueue(widget.flightRef.id);
    _scannerController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _refreshQueuedCount();
    _loadOffline();
  }

  Future<void> _refreshQueuedCount() async {
    final c = await _queue.count();
    if (mounted) setState(() => _queuedCount = c);
  }

  Future<void> _loadOffline() async {
    final snap = await widget.flightRef.get();
    final data = snap.data() ?? {};
    setState(() => _offline = (data['offlineMode'] ?? false) == true);
  }

  Future<void> _toggleOffline(bool v) async {
    setState(() => _offline = v);
    // Persist flag on flight for visibility across tabs/devices
    await widget.flightRef.set({'offlineMode': v}, SetOptions(merge: true));
    await _log('OFFLINE_MODE_TOGGLED', meta: {'value': v});

    if (!v) {
      // Turning OFF offline => attempt flush queued operations
      await _flushQueue();
    } else {
      await _refreshQueuedCount();
    }
  }

  Future<void> _flushQueue() async {
    final ops = await _queue.load();
    if (ops.isEmpty) return;
    setState(() => _busy = true);

    int ok = 0;
    String? lastErr;
    for (final op in ops) {
      try {
        final type = (op['type'] ?? '').toString();
        if (type == 'SCAN_BOARD') {
          final raw = (op['raw'] ?? '').toString();
          final choice = (op['choice'] ?? '').toString(); // PRE / RANDOM
          final isInf = (op['isInfant'] ?? false) == true;
          await _processScanString(
            raw,
            overrideChoice: choice.isEmpty ? null : choice,
            overrideIsInfant: isInf,
            suppressDialogs: true,
            suppressResultUi: true,
          );
        }
        ok++;
        await _queue.popFirst();
      } catch (e) {
        lastErr = e.toString();
        break; // keep remaining in queue
      }
    }

    await _refreshQueuedCount();
    if (mounted) {
      setState(() => _busy = false);
      if (ok > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offline kuyruğu gönderildi: $ok işlem')),
        );
      }
      if (lastErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offline sync hata: $lastErr')),
        );
      }
    }
  }

  Future<String> _emailOf(String uid) async {
    final s = await Db.userDoc(uid).get();
    return (s.data()?['email'] ?? '').toString();
  }

  Future<void> _log(String type, {Map<String, dynamic>? meta}) async {
    await widget.flightRef.collection('logs').add({
      'type': type,
      'byUid': widget.currentUid,
      'byEmail': await _emailOf(widget.currentUid),
      'at': FieldValue.serverTimestamp(),
      'meta': meta ?? {},
    });
  }

  Future<bool> _isWatchlistMatch(String fullName) async {
    final targetVars = _nameVariants(fullName);
    if (targetVars.isEmpty) return false;

    final snap = await widget.flightRef.collection('watchlist').limit(500).get();
    for (final d in snap.docs) {
      final n = (d.data()['fullName'] ?? '').toString();
      final vars = _nameVariants(n);
      for (final v in vars) {
        if (targetVars.contains(v)) return true;
      }
    }
    return false;
  }

  Future<void> _showResultScreen({
    required Color bg,
    required String title,
    String? subtitle,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(16),
          color: bg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Manual "scan" format: FLIGHTCODE|FULLNAME|SEAT|PNR
  // -------- Scan helpers --------
  String _normalizeFlightCode(String code) {
    final c = code.trim().toUpperCase().replaceAll(' ', '');
    // Common format: 2-3 letters + digits (ignore leading zeros on digits)
    final m = RegExp(r'^([A-Z]{2,3})(\d+)$').firstMatch(c);
    if (m == null) return c;
    final prefix = m.group(1)!;
    final digitsRaw = m.group(2)!;
    final digits = digitsRaw.replaceFirst(RegExp(r'^0+'), '');
    final normalizedDigits = digits.isEmpty ? '0' : digits;
    return '$prefix$normalizedDigits';
  }
  String _normalizeName(String s) {
    var v = s.trim().toLowerCase();

    // Turkish diacritics
    const map = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'â': 'a',
      'î': 'i',
      'û': 'u',
    };
    map.forEach((k, val) {
      v = v.replaceAll(k, val);
    });

    // Remove common honorifics/titles (mr/mrs/ms...) as tokens
    v = v.replaceAll(
      RegExp(r'\b(mr|mrs|ms|miss|mstr|dr|sir|madam)\b\.?', caseSensitive: false),
      ' ',
    );

    // Keep spaces for tokenization, wipe punctuation
    v = v.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    v = v.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Join tokens => "volkan tas" -> "volkantas"
    var joined = v.replaceAll(' ', '');

    // Remove leading title fragments even when concatenated: "mrvolkantas", "mrstasvolkan"
    joined = joined.replaceFirst(RegExp(r'^(mr|mrs|ms|miss|mstr|dr|sir|madam)+'), '');
    joined = joined.replaceFirst(RegExp(r'(mr|mrs|ms|miss|mstr|dr|sir|madam)+$'), '');

    return joined;
  }

  Set<String> _nameVariants(String s) {
    var tmp = s.trim().toLowerCase();
    if (tmp.isEmpty) return {};

    // Turkish diacritics
    const map = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'â': 'a',
      'î': 'i',
      'û': 'u',
    };
    map.forEach((k, val) {
      tmp = tmp.replaceAll(k, val);
    });

    tmp = tmp.replaceAll(
      RegExp(r'\b(mr|mrs|ms|miss|mstr|dr|sir|madam)\b\.?', caseSensitive: false),
      ' ',
    );
    tmp = tmp.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    tmp = tmp.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (tmp.isEmpty) return {};

    final tokens = tmp.split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return {};

    String joinTokens(List<String> t) {
      var j = t.join('');
      j = j.replaceFirst(RegExp(r'^(mr|mrs|ms|miss|mstr|dr|sir|madam)+'), '');
      j = j.replaceFirst(RegExp(r'(mr|mrs|ms|miss|mstr|dr|sir|madam)+$'), '');
      return j;
    }

    final out = <String>{};
    out.add(joinTokens(tokens));
    if (tokens.length >= 2) out.add(joinTokens(tokens.reversed.toList()));
    return out.where((e) => e.isNotEmpty).toSet();
  }

  String _extractFlightCode(String raw) {
    // Robust flight code extraction across common boarding pass layouts.
    // Accepts patterns like: "BA 679", "LS1850", "XQ0688", "TOM 836", "FH 612".
    String norm(String s) {
      final up = s.toUpperCase();
      final buf = StringBuffer();
      for (final r in up.runes) {
        final isAZ = (r >= 65 && r <= 90);
        final is09 = (r >= 48 && r <= 57);
        buf.write((isAZ || is09) ? String.fromCharCode(r) : ' ');
      }
      return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    final n = norm(raw);

    // 1) Compact pattern already: ABC123 / AB1234
    final compact = RegExp(r'\b[A-Z]{2,3}\d{3,4}\b').firstMatch(n.replaceAll(' ', ''));
    if (compact != null) return compact.group(0) ?? '';

    // 2) Separated airline + number: "BA 679", "LS 1850", "TOM 836"
    final stop = <String>{
      'SEQ', 'PNR', 'GATE', 'SEAT', 'FROM', 'TO', 'NAME', 'CLASS', 'DATE', 'TIME',
      'PCS', 'WT', 'BAGS', 'GROUP', 'BOARD', 'BOARDING', 'DEPART', 'DEPARTS',
      'ARRIVE', 'ARRIVES', 'ETKT', 'TKT', 'TKNE', 'SECURITY', 'CHECKIN'
    };

    for (final m in RegExp(r'\b([A-Z]{2,3})\s*([0-9]{3,4})\b').allMatches(n)) {
      final a = (m.group(1) ?? '').trim();
      final num = (m.group(2) ?? '').trim();
      if (a.isEmpty || num.isEmpty) continue;
      if (stop.contains(a)) continue;
      return '$a$num';
    }

    // 3) Loose fallback on raw text
    final loose = RegExp(r'\b([A-Z]{2})(?:\s|-)?(\d{3,4})\b').firstMatch(raw.toUpperCase());
    if (loose != null) {
      final a = loose.group(1) ?? '';
      final num = loose.group(2) ?? '';
      if (a.isNotEmpty && num.isNotEmpty && !stop.contains(a)) return '$a$num';
    }
    return '';
  }


  String _extractSeat(String raw) {
    final m = RegExp(r'\b\d{1,2}[A-Z]\b').firstMatch(raw.toUpperCase());
    return m?.group(0) ?? '';
  }

  String _extractPnr(String raw) {
    // PNR genelde 6 karakter alfanümerik
    final matches = RegExp(r'\b[A-Z0-9]{6}\b').allMatches(raw.toUpperCase()).toList();
    if (matches.isEmpty) return '';
    // flight code gibi görünenleri ele
    for (final mm in matches) {
      final v = mm.group(0) ?? '';
      if (!RegExp(r'^[A-Z]{2,3}\d{3,4}$').hasMatch(v)) return v;
    }
    return matches.first.group(0) ?? '';
  }

  String _extractName(String raw) {
    // Eğer manuel format değilse isim yakalamak her boarding kartında garanti değil.
    // Bu yüzden "NAME:" gibi anahtarlar varsa kullan, yoksa boş dön.
    final up = raw.toUpperCase();
    final idx = up.indexOf('NAME:');
    if (idx >= 0) {
      final sub = raw.substring(idx + 5).trim();
      final cut = sub.indexOf('|');
      return (cut >= 0 ? sub.substring(0, cut) : sub).trim();
    }
    return '';
  }

  String _hash32(String raw) {
    // FNV-1a 32-bit (deterministic)
    int hash = 0x811c9dc5;
    for (final c in raw.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<String> _usernameLowerOf(String uid) async {
    final s = await Db.userDoc(uid).get();
    return (s.data()?['usernameLower'] ?? '').toString();
  }

  // Manual scan supports:
  // 1) FLIGHTCODE|FULLNAME|SEAT|PNR
  // 2) Raw barcode/QR string (best-effort parse)
  Future<void> _processScanString(
    String raw, {
    String? overrideChoice, // 'PRE' or 'RANDOM'
    bool? overrideIsInfant,
    bool suppressDialogs = false,
    bool suppressResultUi = false,
  }) async {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return;

    String flightCode = '';
    String fullName = '';
    String seat = '';
    String pnr = '';

    final parts = cleaned.split('|').map((e) => e.trim()).toList();
    if (parts.length >= 3 && _extractFlightCode(parts[0]).isNotEmpty) {
      // Manual structured input
      flightCode = parts[0].toUpperCase();
      fullName = parts[1];
      seat = parts[2].toUpperCase();
      pnr = parts.length >= 4 ? parts[3].toUpperCase() : '';
    } else {
      // Raw barcode/QR
      flightCode = _extractFlightCode(cleaned);
      seat = _extractSeat(cleaned);
      pnr = _extractPnr(cleaned);
      fullName = _extractName(cleaned); // may be empty
    }

    final fSnap = await widget.flightRef.get();
    final fCode = (fSnap.data()?['flightCode'] ?? '').toString().toUpperCase();
    final normExpected = _normalizeFlightCode(fCode);
    final normScanned = _normalizeFlightCode(flightCode);

    if (flightCode.isEmpty) {
      throw Exception('Boarding card içinden uçuş kodu okunamadı.');
    }

    if (normScanned != normExpected) {
      if (!suppressResultUi) await _showResultScreen(
        bg: const Color(0xFF6A1B9A), // Purple
        title: 'WRONG FLIGHT!!\nFLIGHT NUMBER DOES NOT MATCH',
      );
      await _log('SCAN_WRONG_FLIGHT', meta: {'scannedFlightCode': flightCode, 'expectedFlightCode': fCode, 'scannedNorm': normScanned, 'expectedNorm': normExpected});
      return;
    }

    // Watchlist match (by name if available)
    final isWl = fullName.isNotEmpty ? await _isWatchlistMatch(fullName) : false;

    // Duplicate by boarding pass raw hash
    var bpId = _hash32('$normExpected|$cleaned');
    var boardingRef = widget.flightRef.collection('boardings').doc(bpId);
    final existing = await boardingRef.get();

    // Seat-duplicate (INFANT case): infants may share same seat number with adult.
    bool seatDuplicate = false;
    QueryDocumentSnapshot<Map<String, dynamic>>? seatOccupant;
    if (seat.isNotEmpty && seat.toUpperCase() != '—') {
      final paxSnap = await widget.flightRef.collection('pax').limit(1000).get();
      for (final d in paxSnap.docs) {
        final data = d.data();
        final st = (data['status'] ?? 'NONE').toString();
        final sSeat = (data['seat'] ?? '').toString().toUpperCase();
        final isInf = (data['isInfant'] ?? false) == true;
        if (!isInf && sSeat == seat.toUpperCase() && (st == 'PREBOARDED' || st == 'DFT_BOARDED')) {
          seatDuplicate = true;
          seatOccupant = d;
          break;
        }
      }
    }

    if (existing.exists) {
      if (isWl) {
        if (!suppressResultUi) await _showResultScreen(
          bg: Colors.red,
          title: 'FLY PASSANGER ATTANTION!!!',
          subtitle: 'ALREADY BOARDED / DUPLICATED BOARDING PASS',
        );
      } else {
        if (!suppressResultUi) await _showResultScreen(
          bg: Colors.grey,
          title: 'ALREADY BOARDED\nDUPLICATED BOARDING PASS',
        );
      }
      await _log('SCAN_DUPLICATE', meta: {'bpId': bpId, 'watchlistMatch': isWl});
      return;
    }

    bool isInfant = false;
    if (seatDuplicate) {
      bool? ans = overrideIsInfant;
      if (ans == null && !suppressDialogs) {
        ans = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Mükerrer Seat'),
            content: Text(
              'Bu seat numarası daha önce boardlandı: ${seat.toUpperCase()}\n\nYolcu INFANT mı?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hayır')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Evet, INFANT')),
            ],
          ),
        );
      }

      if (ans == true) {
        isInfant = true;
        // deterministic base + uniqueness for infant (same seat / same name) to allow multiple scans
        bpId = _hash32('$normExpected|$cleaned|INFANT|${DateTime.now().microsecondsSinceEpoch}');
        boardingRef = widget.flightRef.collection('boardings').doc(bpId);
      } else {

        if (isWl) {
          if (!suppressResultUi) await _showResultScreen(
            bg: Colors.red,
            title: 'FLY PASSANGER ATTANTION!!!',
            subtitle: 'ALREADY BOARDED / DUPLICATED BOARDING PASS',
          );
        } else {
          if (!suppressResultUi) await _showResultScreen(
            bg: Colors.grey,
            title: 'ALREADY BOARDED\nDUPLICATED BOARDING PASS',
          );
        }
        await _log('SCAN_DUPLICATE_SEAT', meta: {'seat': seat.toUpperCase(), 'watchlistMatch': isWl});
        return;
      }
    }

    String? choice = overrideChoice;
    if (choice == null && !suppressDialogs) {
      choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Boarding Seçimi'),
          content: Text(isWl
              ? 'WatchList MATCH: Sadece RANDOM SELECTION seçilebilir.'
              : 'İki seçenek: Pre-BOARD veya DFT Random'),
          actions: [
            TextButton(
              onPressed: isWl ? null : () => Navigator.pop(context, 'PRE'),
              child: const Text('Pre-BOARD'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'RANDOM'),
              child: const Text('DFT Random'),
            ),
          ],
        ),
      );
    }

    if (choice == null) return;

    // Enforce: watchlist match -> ONLY random
    if (isWl && choice == 'PRE') {
      choice = 'RANDOM';
    }


    // OFFLINE MODE: enqueue operation and exit (will be synced when online)
    if (_offline) {
      await _queue.enqueue({
        'type': 'SCAN_BOARD',
        'raw': raw,
        'choice': choice,
        'isInfant': isInfant,
        'queuedAt': DateTime.now().toIso8601String(),
      });
      await _refreshQueuedCount();
      if (!suppressResultUi) {
        await _showResultScreen(
          bg: Colors.orange,
          title: 'OFFLINE QUEUED',
          subtitle: 'Bu işlem online olunca otomatik sync edilecek.',
        );
      }
      return;
    }

    // Pax identity (no external pax list): create/update pax record from scan
    // If fullName is missing from QR, allow placeholder but still record scan.
    final paxCol = widget.flightRef.collection('pax');
    final nameSafe = fullName.isEmpty ? '—' : fullName;
    final seatSafe = seat.isEmpty ? '—' : seat;

    final q = await paxCol
        .where('fullName', isEqualTo: nameSafe)
        .where('seat', isEqualTo: seatSafe)
        .limit(1)
        .get();

    DocumentReference<Map<String, dynamic>> paxRef;
    if (q.docs.isNotEmpty) {
      paxRef = q.docs.first.reference;
    } else {
      paxRef = paxCol.doc();
      await paxRef.set({
        'fullName': nameSafe,
        'seat': seatSafe,
        'pnr': pnr,
        'status': 'NONE',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }


    // Infant meta (seat shared with adult)
    if (isInfant) {
      await paxRef.set({
        'isInfant': true,
        'parentSeat': seatSafe,
        'linkedAdultPaxId': seatOccupant?.id,
      }, SetOptions(merge: true));
    }
    final byEmail = await _emailOf(widget.currentUid);
    final byUsernameLower = await _usernameLowerOf(widget.currentUid);
    final now = FieldValue.serverTimestamp();

    if (choice == 'PRE') {
      await paxRef.set({
        'status': 'PREBOARDED',
        'boardedAt': now,
        'boardedByUid': widget.currentUid,
        'boardedByEmail': byEmail,
        'boardedByUsernameLower': byUsernameLower,
              'watchlistMatch': isWl,
      }, SetOptions(merge: true));

      await boardingRef.set({
        'bpId': bpId,
        'raw': cleaned,
        'flightCode': fCode,
        'fullName': nameSafe,
        'seat': seatSafe,
        'pnr': pnr,
        'kind': 'PRE',
        'watchlistMatch': isWl,
        'boardedAt': now,
        'boardedByUid': widget.currentUid,
        'boardedByEmail': byEmail,
        'boardedByUsernameLower': byUsernameLower,
      });

      await _log('PAX_PREBOARDED', meta: {'fullName': nameSafe, 'seat': seatSafe});

      if (!suppressResultUi) await _showResultScreen(
        bg: Colors.green,
        title: 'PRE-BOARD SUCCESSFULL',
      );
    } else {
      await paxRef.set({
        'status': 'DFT_BOARDED',
        'boardedAt': now,
        'boardedByUid': widget.currentUid,
        'boardedByEmail': byEmail,
        'boardedByUsernameLower': byUsernameLower,
              'watchlistMatch': isWl,
      }, SetOptions(merge: true));

      await boardingRef.set({
        'bpId': bpId,
        'raw': cleaned,
        'flightCode': fCode,
        'fullName': nameSafe,
        'seat': seatSafe,
        'pnr': pnr,
        'kind': 'RANDOM',
        'watchlistMatch': isWl,
        'boardedAt': now,
        'boardedByUid': widget.currentUid,
        'boardedByEmail': byEmail,
        'boardedByUsernameLower': byUsernameLower,
      });

      await _log('PAX_RANDOM_SELECTED', meta: {'fullName': nameSafe, 'seat': seatSafe, 'watchlistMatch': isWl});

      if (isWl) {
        if (!suppressResultUi) await _showResultScreen(
          bg: Colors.red,
          title: 'FLY PASSANGER ATTANTION!!!',
          subtitle: 'RANDOM SELECTION SUCCESSFULL',
        );
      } else {
        if (!suppressResultUi) await _showResultScreen(
          bg: Colors.blue,
          title: 'RANDOM SELECTION SUCCESSFULL',
        );
      }
    }
  }

  Future<void> _manualBoardOrOffload({required bool offload}) async {
    // Select pax from list (simple dialog)
    final pax = await widget.flightRef.collection('pax').orderBy('fullName').get();
    final docs = pax.docs;

    if (!mounted) return;

    final selected = await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(offload ? 'Manuel Offload' : 'Manuel Boardlama'),
          content: SizedBox(
            width: 420,
            height: 420,
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i];
                final data = d.data();
                final fullName = (data['fullName'] ?? '').toString();
                final seat = (data['seat'] ?? '').toString();
                final status = (data['status'] ?? 'NONE').toString();
                return ListTile(
                  title: Text(fullName.isEmpty ? '—' : fullName),
                  subtitle: Text('Seat: $seat  •  Status: $status'),
                  onTap: () => Navigator.pop(context, d),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
          ],
        );
      },
    );

    if (selected == null) return;

    if (offload) {
      final byEmail = await _emailOf(widget.currentUid);
      final byUsernameLower = await _usernameLowerOf(widget.currentUid);
      final now = FieldValue.serverTimestamp();

      final dataSel = selected.data();
      final seatSel = (dataSel['seat'] ?? '').toString().toUpperCase();
      final isInfSel = (dataSel['isInfant'] ?? false) == true;

      // Find linked pax with same seat (infant <-> adult) that is currently boarded
      final paxSnapAll = await widget.flightRef.collection('pax').limit(1500).get();
      final linked = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final d in paxSnapAll.docs) {
        if (d.id == selected.id) continue;
        final dd = d.data();
        final st = (dd['status'] ?? 'NONE').toString();
        final sSeat = (dd['seat'] ?? '').toString().toUpperCase();
        final isInf = (dd['isInfant'] ?? false) == true;
        if (sSeat == seatSel && (st == 'PREBOARDED' || st == 'DFT_BOARDED') && (isInfSel != isInf)) {
          linked.add(d);
        }
      }

      bool offloadTogether = false;
      if (linked.isNotEmpty && seatSel.isNotEmpty && seatSel != '—') {
        final ans = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('INFANT uyarısı'),
            content: Text('Bu seat numarası için bağlı INFANT/Adult yolcu bulundu: $seatSel\n\nBirlikte OFFLOAD edilsin mi?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hayır')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Evet, birlikte')),
            ],
          ),
        );
        offloadTogether = ans == true;
      }

      Future<void> offloadOne(QueryDocumentSnapshot<Map<String, dynamic>> d, {required bool linkedFlag}) async {
        final dd = d.data();
        final fullName = (dd['fullName'] ?? '').toString();
        final seat = (dd['seat'] ?? '').toString();
        await d.reference.set({
          'status': 'OFFLOADED',
          'offloadedAt': now,
          'offloadedByUid': widget.currentUid,
          'offloadedByEmail': byEmail,
          'offloadedByUsernameLower': byUsernameLower,
        }, SetOptions(merge: true));

        await widget.flightRef.collection('offloads').add({
          'paxId': d.id,
          'fullName': fullName,
          'seat': seat,
          'at': now,
          'byUid': widget.currentUid,
          'byEmail': byEmail,
          'byUsernameLower': byUsernameLower,
          'meta': {'linkedOffload': linkedFlag},
        });
      }

      // Always offload selected
      await offloadOne(selected, linkedFlag: false);

      // Optionally offload linked pax too
      if (offloadTogether) {
        for (final d in linked) {
          await offloadOne(d, linkedFlag: true);
        }
      }

      await _log('PAX_OFFLOADED_MANUAL', meta: {'paxId': selected.id, 'offloadTogether': offloadTogether, 'linkedCount': linked.length});
    } else {
      // Offer PRE vs RANDOM with watchlist rules
      final data = selected.data();
      final fullName = (data['fullName'] ?? '').toString();
      final seat = (data['seat'] ?? '').toString();
      final isWl = await _isWatchlistMatch(fullName);

      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Boarding Seçimi'),
          content: Text(isWl
              ? 'WatchList MATCH: Sadece RANDOM SELECTION seçilebilir.'
              : 'İki seçenek: Pre-BOARD veya DFT Random'),
          actions: [
            TextButton(
              onPressed: isWl ? null : () => Navigator.pop(context, 'PRE'),
              child: const Text('Pre-BOARD'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'RANDOM'),
              child: const Text('DFT Random'),
            ),
          ],
        ),
      );
      if (choice == null) return;

      final byEmail = await _emailOf(widget.currentUid);
      if (choice == 'PRE') {
        await selected.reference.set({
          'status': 'PREBOARDED',
          'boardedAt': FieldValue.serverTimestamp(),
          'boardedByUid': widget.currentUid,
          'boardedByEmail': byEmail,
        }, SetOptions(merge: true));
        await _log('PAX_PREBOARDED_MANUAL', meta: {'fullName': fullName, 'seat': seat});
        await _showResultScreen(bg: Colors.green, title: 'PRE-BOARD SUCCESSFULL');
      } else {
        await selected.reference.set({
          'status': 'DFT_BOARDED',
          'boardedAt': FieldValue.serverTimestamp(),
          'boardedByUid': widget.currentUid,
          'boardedByEmail': byEmail,
        }, SetOptions(merge: true));
        await _log('PAX_RANDOM_SELECTED_MANUAL', meta: {'fullName': fullName, 'seat': seat, 'watchlistMatch': isWl});
        if (isWl) {
          await _showResultScreen(
            bg: Colors.red,
            title: 'FLY PASSANGER ATTANTION!!!',
            subtitle: 'RANDOM SELECTION SUCCESSFULL',
          );
        } else {
          await _showResultScreen(bg: Colors.blue, title: 'RANDOM SELECTION SUCCESSFULL');
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(offload ? 'Offload işlendi' : 'Boarding işlendi')),
      );
    }
  }

  Future<void> _inviteUser() async {
    final ctl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Uygulama içi davet'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(
            labelText: 'Kullanıcı Adı (isim.soyisim)',
            hintText: 'Örn: volkan.taskiran',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Davet Et'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final usernameLower = ctl.text.trim().toLowerCase();
    if (usernameLower.isEmpty) return;

    try {
      // 1) Kullanıcı adından uid bul (email @ öncesi)
      final q = await Db.users()
          .where('usernameLower', isEqualTo: usernameLower)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı bulunamadı. İsim formatını kontrol et.')),
        );
        return;
      }

      final u = q.docs.first;
      final inviteeUid = u.id;
      final inviteeName = (u.data()['displayName'] ?? '').toString();

      // 2) Flight bilgisi (id + code)
      final flightId = widget.flightRef.id;
      final flightSnap = await widget.flightRef.get();
      final flightCode = (flightSnap.data()?['flightCode'] ?? '').toString();

      await FirebaseFirestore.instance.collection('invites').add({
        'flightId': flightId,
        'flightCode': flightCode,
        'inviteeUid': inviteeUid,
        'inviteeName': inviteeName,
        'status': 'PENDING',
        'createdByUid': widget.currentUid,
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Davet gönderildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Davet gönderilemedi: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  value: _offline,
                  onChanged: _toggleOffline,
                  title: const Text('Offline Mode'),
                  subtitle: const Text('Offline mode (şimdilik flag).'),
                ),
                SwitchListTile(
                  value: _night,
                  onChanged: (v) async {
                    setState(() => _night = v);
                    await _log('NIGHT_MODE_TOGGLED', meta: {'value': v});
                  },
                  title: const Text('Gece Modu (bu sekme içi)'),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _manualBoardOrOffload(offload: false),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Manuel Boardlama'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _manualBoardOrOffload(offload: true),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Manuel Offload'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _inviteUser,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Kullanıcı davet et'),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Scan Kamera',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_queuedCount > 0)
                      Chip(
                        label: Text('Offline queue: $_queuedCount'),
                        avatar: const Icon(Icons.cloud_upload, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Camera scanner on non-web; manual input remains as fallback (and for web).
                if (!kIsWeb) ...[
                  SizedBox(
                    height: 260,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) async {
                          if (_busy) return;
                          final barcodes = capture.barcodes;
                          if (barcodes.isEmpty) return;
                          final raw = (barcodes.first.rawValue ?? '').trim();
                          if (raw.isEmpty) return;

                          // Manual trigger: only accept when armed
                          if (_manualTrigger && !_armed) return;

                          final now = DateTime.now();
                          if (_lastScanRaw == raw &&
                              _lastScanAt != null &&
                              now.difference(_lastScanAt!).inMilliseconds < 350) {
                            // ignore accidental double-detect
                            return;
                          }
                          _lastScanRaw = raw;
                          _lastScanAt = now;

                          if (_manualTrigger) {
                            setState(() => _armed = false);
                          }

                          setState(() => _busy = true);
                          try {
                            await _processScanString(raw);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Torch',
                        onPressed: () async {
                          await _scannerController.toggleTorch();
                          setState(() {});
                        },
                        icon: Icon(
                          _scannerController.torchEnabled ? Icons.flash_on : Icons.flash_off,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _manualTrigger,
                          onChanged: (v) {
                            setState(() {
                              _manualTrigger = v;
                              _armed = !v;
                            });
                          },
                          title: const Text('Tetikleme butonu'),
                          subtitle: const Text('Kamera otomatik okuyamazsa, tetikle ve 1 kart oku.'),
                        ),
                      ),
                    ],
                  ),
                  if (_manualTrigger) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() => _armed = true);
                                // auto-disarm after a short window
                                Future.delayed(const Duration(seconds: 4), () {
                                  if (mounted && _manualTrigger) setState(() => _armed = false);
                                });
                              },
                        icon: const Icon(Icons.play_arrow),
                        label: Text(_armed ? 'TETİKLEME AKTİF' : 'TETİKLE'),
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                ] else ...[
                  const Text(
                    'Web testte kamera yerine manuel input kullanıyoruz.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const Divider(height: 24),
                ],

                TextField(
                  controller: _manualScan,
                  decoration: const InputDecoration(
                    labelText: 'Manuel Scan (FLIGHTCODE|FULLNAME|SEAT|PNR)',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await _processScanString(_manualScan.text.trim());
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Scan İşle'),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================
// Tab 2: Pax list (Preboard + DFT boarded + search) + Offloaded separate
// ==========================

class PaxListTab extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> flightRef;
  final String currentUid;

  const PaxListTab({super.key, required this.flightRef, required this.currentUid});

  @override
  State<PaxListTab> createState() => _PaxListTabState();
}

class _PaxListTabState extends State<PaxListTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final stream = widget.flightRef.collection('pax').orderBy('fullName').snapshots();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Yolcu adı / seat ara',
            ),
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final filtered = docs.where((d) {
                final data = d.data();
                final name = (data['fullName'] ?? '').toString().toLowerCase();
                final seat = (data['seat'] ?? '').toString().toLowerCase();
                if (_q.isEmpty) return true;
                return name.contains(_q) || seat.contains(_q);
              }).toList();

              final pre = filtered.where((d) => (d.data()['status'] ?? '') == 'PREBOARDED').toList();
              final dft = filtered.where((d) => (d.data()['status'] ?? '') == 'DFT_BOARDED').toList();
              final off = filtered.where((d) => (d.data()['status'] ?? '') == 'OFFLOADED').toList();
              final other = filtered.where((d) {
                final s = (d.data()['status'] ?? '').toString();
                return s != 'PREBOARDED' && s != 'DFT_BOARDED' && s != 'OFFLOADED';
              }).toList();

              return ListView(
                children: [
                  _Section(title: 'PREBOARDED', count: pre.length, children: pre.map(_paxTile).toList()),
                  _Section(title: 'DFT BOARDED (Random)', count: dft.length, children: dft.map(_paxTile).toList()),
                  _Section(title: 'OFFLOADED', count: off.length, children: off.map(_paxTile).toList()),
                  _Section(title: 'Diğer', count: other.length, children: other.map(_paxTile).toList()),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _paxTile(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final name = (data['fullName'] ?? '').toString();
    final seat = (data['seat'] ?? '').toString();
    final pnr = (data['pnr'] ?? '').toString();
    final status = (data['status'] ?? 'NONE').toString();

    final boardedBy = (data['boardedByEmail'] ?? '').toString();
    final offBy = (data['offloadedByEmail'] ?? '').toString();

    DateTime? boardedAt;
    final tsB = data['boardedAt'];
    if (tsB is Timestamp) boardedAt = tsB.toDate();

    DateTime? offAt;
    final tsO = data['offloadedAt'];
    if (tsO is Timestamp) offAt = tsO.toDate();

    String timeStr(DateTime? dt) => dt == null ? '—' : DateFormat('yyyy-MM-dd HH:mm').format(dt);

    return ListTile(
      title: Text(name.isEmpty ? '—' : name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seat: $seat  •  PNR: ${pnr.isEmpty ? "—" : pnr}'),
          const SizedBox(height: 2),
          Text(
            'Status: ${status == 'DFT_BOARDED' && (data['watchlistMatch'] == true) ? 'DFT Random - Watchlist Matched' : status}',
            style: TextStyle(
              color: (status == 'DFT_BOARDED' && (data['watchlistMatch'] == true)) ? Colors.red : null,
              fontWeight: (status == 'DFT_BOARDED' && (data['watchlistMatch'] == true)) ? FontWeight.w700 : null,
            ),
          ),
          const SizedBox(height: 2),
          Text('Boarded: ${timeStr(boardedAt)}  •  By: ${boardedBy.isEmpty ? "—" : boardedBy}'),
          Text('Offload: ${timeStr(offAt)}  •  By: ${offBy.isEmpty ? "—" : offBy}'),
        ],
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'BOARD') {
            await _manualBoard(d);
          } else if (v == 'OFFLOAD') {
            await _manualOffload(d);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'BOARD', child: Text('Manuel Boardla')),
          PopupMenuItem(value: 'OFFLOAD', child: Text('Manuel Offload')),
        ],
      ),
    );
  }

  Future<String> _emailOf(String uid) async {
    final s = await Db.userDoc(uid).get();
    return (s.data()?['email'] ?? '').toString();
  }

  Future<bool> _isWatchlistMatch(String fullName) async {
    final q = await widget.flightRef
        .collection('watchlist')
        .where('fullName', isEqualTo: fullName)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  Future<void> _log(String type, {Map<String, dynamic>? meta}) async {
    await widget.flightRef.collection('logs').add({
      'type': type,
      'byUid': widget.currentUid,
      'byEmail': await _emailOf(widget.currentUid),
      'at': FieldValue.serverTimestamp(),
      'meta': meta ?? {},
    });
  }

  Future<void> _manualBoard(QueryDocumentSnapshot<Map<String, dynamic>> paxDoc) async {
    final data = paxDoc.data();
    final name = (data['fullName'] ?? '').toString();
    final seat = (data['seat'] ?? '').toString();
    final isWl = await _isWatchlistMatch(name);

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Boarding Seçimi'),
        content: Text(isWl
            ? 'WatchList MATCH: Sadece RANDOM SELECTION seçilebilir.'
            : 'İki seçenek: Pre-BOARD veya DFT Random'),
        actions: [
          TextButton(
            onPressed: isWl ? null : () => Navigator.pop(context, 'PRE'),
            child: const Text('Pre-BOARD'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'RANDOM'),
            child: const Text('DFT Random'),
          ),
        ],
      ),
    );
    if (choice == null) return;

    final byEmail = await _emailOf(widget.currentUid);
    if (choice == 'PRE') {
      await paxDoc.reference.set({
        'status': 'PREBOARDED',
        'boardedAt': FieldValue.serverTimestamp(),
        'boardedByUid': widget.currentUid,
        'boardedByEmail': byEmail,
        'watchlistMatch': isWl,
      }, SetOptions(merge: true));
      await _log('PAX_PREBOARDED_MANUAL', meta: {'fullName': name, 'seat': seat});
    } else {
      await paxDoc.reference.set({
        'status': 'DFT_BOARDED',
        'boardedAt': FieldValue.serverTimestamp(),
        'boardedByUid': widget.currentUid,
        'boardedByEmail': byEmail,
        'watchlistMatch': isWl,
      }, SetOptions(merge: true));
      await _log('PAX_RANDOM_SELECTED_MANUAL', meta: {'fullName': name, 'seat': seat, 'watchlistMatch': isWl});
    }
  }

  Future<void> _manualOffload(QueryDocumentSnapshot<Map<String, dynamic>> paxDoc) async {
    final byEmail = await _emailOf(widget.currentUid);
    await paxDoc.reference.set({
      'status': 'OFFLOADED',
      'offloadedAt': FieldValue.serverTimestamp(),
      'offloadedByUid': widget.currentUid,
      'offloadedByEmail': byEmail,
    }, SetOptions(merge: true));
    await _log('PAX_OFFLOADED_MANUAL', meta: {'paxId': paxDoc.id});
  }
}

class _Section extends StatelessWidget {
  final String title;
  final int count;
  final List<Widget> children;

  const _Section({required this.title, required this.count, required this.children});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: title != 'Diğer',
      title: Text('$title ($count)'),
      children: children.isEmpty
          ? [const Padding(padding: EdgeInsets.all(12), child: Text('Boş.'))]
          : children,
    );
  }
}

// ==========================
// Tab 3: Watchlist (edit/delete/add)
// ==========================

class WatchlistTab extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> flightRef;
  final String currentUid;

  const WatchlistTab({super.key, required this.flightRef, required this.currentUid});

  Future<String> _emailOf(String uid) async {
    final s = await Db.userDoc(uid).get();
    return (s.data()?['email'] ?? '').toString();
  }

  Future<void> _log(String type, {Map<String, dynamic>? meta}) async {
    await flightRef.collection('logs').add({
      'type': type,
      'byUid': currentUid,
      'byEmail': await _emailOf(currentUid),
      'at': FieldValue.serverTimestamp(),
      'meta': meta ?? {},
    });
  }

  Future<void> _add(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('WatchList Ekle'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'İsim Soyisim')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
        ],
      ),
    );
    if (ok != true) return;

    final name = c.text.trim();
    if (name.isEmpty) return;

    await flightRef.collection('watchlist').add({
      'fullName': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _log('WATCHLIST_ADD', meta: {'fullName': name});
  }

  Future<void> _edit(BuildContext context, DocumentReference<Map<String, dynamic>> ref, String current) async {
    final c = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('WatchList Düzenle'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'İsim Soyisim')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok != true) return;

    final name = c.text.trim();
    if (name.isEmpty) return;

    await ref.set({'fullName': name}, SetOptions(merge: true));
    await _log('WATCHLIST_EDIT', meta: {'from': current, 'to': name});
  }

  Future<void> _delete(DocumentReference<Map<String, dynamic>> ref, String name) async {
    await ref.delete();
    await _log('WATCHLIST_DELETE', meta: {'fullName': name});
  }

  @override
  Widget build(BuildContext context) {
    final stream = flightRef.collection('watchlist').orderBy('createdAt', descending: true).snapshots();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('WatchList Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('WatchList boş.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i];
              final name = (d.data()['fullName'] ?? '').toString();

              return ListTile(
                title: Text(name.isEmpty ? '—' : name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Düzenle',
                      onPressed: () => _edit(context, d.reference, name),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      tooltip: 'Sil',
                      onPressed: () => _delete(d.reference, name),
                      icon: const Icon(Icons.delete),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================
// Tab 4: Staff (name + role; multiple per role)
// ==========================

class StaffTab extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> flightRef;
  const StaffTab({super.key, required this.flightRef});

  @override
  State<StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<StaffTab> {
  static const roles = [
    'Supervisor',
    'Team Leader',
    'Tarmac Team Leader',
    'Interviewer',
    'Pax ID',
    'Gate Search',
    'Gate Observer',
    'Ramp',
    'Back',
    'Jetty',
    'Chute',
    'Baggage Escort',
    'Kargo Escort',
    'Catering',
    'Barcode',
    'A/C Search',
    'Ramp 2',
    'APIS',
  ];

  Future<void> _addStaff() async {
    final name = TextEditingController();
    String role = roles.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Personel Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad Soyad')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role,
              items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => role = v ?? roles.first,
              decoration: const InputDecoration(labelText: 'Rol'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
        ],
      ),
    );

    if (ok == true) {
      final n = name.text.trim();
      if (n.isEmpty) return;
      await widget.flightRef.collection('staff').add({
        'fullName': n,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = widget.flightRef.collection('staff').orderBy('createdAt', descending: true).snapshots();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStaff,
        icon: const Icon(Icons.add),
        label: const Text('Personel Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Personel yok.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();
              return ListTile(
                title: Text((data['fullName'] ?? '').toString()),
                subtitle: Text((data['role'] ?? '').toString()),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => d.reference.delete(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================
// Tab 5: Equipment
// ==========================

class EquipmentTab extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> flightRef;
  const EquipmentTab({super.key, required this.flightRef});

  @override
  State<EquipmentTab> createState() => _EquipmentTabState();
}

class _EquipmentTabState extends State<EquipmentTab> {
  static const etdModels = ['IS600', 'Itimiser4DX'];

  Future<void> _addItem(String type) async {
    final c = TextEditingController();
    String etdModel = etdModels.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$type Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'ETD')
              DropdownButtonFormField<String>(
                value: etdModel,
                items: etdModels.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => etdModel = v ?? etdModels.first,
                decoration: const InputDecoration(labelText: 'ETD Model'),
              ),
            TextField(
              controller: c,
              decoration: InputDecoration(labelText: '$type Seri No'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
        ],
      ),
    );
    if (ok != true) return;
    final serial = c.text.trim();
    if (serial.isEmpty) return;

    await widget.flightRef.collection('equipment').add({
      'type': type,
      'serial': serial,
      if (type == 'ETD') 'model': etdModel,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final stream = widget.flightRef.collection('equipment').orderBy('createdAt', descending: true).snapshots();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showModalBottomSheet<void>(
            context: context,
            builder: (_) => SafeArea(
              child: Wrap(
                children: [
                  ListTile(title: const Text('Masa Seri No Ekle'), onTap: () { Navigator.pop(context); _addItem('Masa'); }),
                  ListTile(title: const Text('Desk Seri No Ekle'), onTap: () { Navigator.pop(context); _addItem('Desk'); }),
                  ListTile(title: const Text('Podyum Seri No Ekle'), onTap: () { Navigator.pop(context); _addItem('Podyum'); }),
                  ListTile(title: const Text('ETD Ekle'), onTap: () { Navigator.pop(context); _addItem('ETD'); }),
                ],
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Ekipman Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Ekipman yok.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();
              final type = (data['type'] ?? '').toString();
              final serial = (data['serial'] ?? '').toString();
              final model = (data['model'] ?? '').toString();
              return ListTile(
                title: Text('$type • $serial'),
                subtitle: model.isEmpty ? null : Text('Model: $model'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => d.reference.delete(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================
// Tab 6: Op Times
// ==========================

class OpTimesTab extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> flightRef;
  final String currentUid;
  const OpTimesTab({super.key, required this.flightRef, required this.currentUid});

  @override
  State<OpTimesTab> createState() => _OpTimesTabState();
}

class _OpTimesTabState extends State<OpTimesTab> {
  static const fields = [
    'ETA',
    'ATA',
    'ETD',
    'ATD',
    'BOARDING_STARTED',
    'BOARDING_FINISHED',
    'OPERATION_FINISHED',
    'ILK_YOLCU_MURACAAT',
    'SON_YOLCU_MURACAAT',
    'GATE_TAHSIS_SAATI',
  ];

  Future<Map<String, dynamic>> _load() async {
    final snap = await widget.flightRef.get();
    return Map<String, dynamic>.from(snap.data()?['opTimes'] ?? {});
  }

  Future<void> _setField(String key, DateTime? value) async {
    final map = await _load();
    map[key] = value?.toIso8601String();
    await widget.flightRef.set({'opTimes': map}, SetOptions(merge: true));
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime? current) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDate: current ?? now,
    );
    if (d == null) return null;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (t == null) return null;

    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snap) {
        final map = snap.data ?? {};
        String label(String iso) {
          try {
            final dt = DateTime.parse(iso);
            return DateFormat('yyyy-MM-dd HH:mm').format(dt);
          } catch (_) {
            return iso;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Op. Times',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final f in fields)
              Card(
                child: ListTile(
                  title: Text(f),
                  subtitle: Text(map[f] == null ? '—' : label(map[f].toString())),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Temizle',
                        onPressed: () => _setField(f, null),
                        icon: const Icon(Icons.clear),
                      ),
                      IconButton(
                        tooltip: 'Seç',
                        onPressed: () async {
                          final curIso = map[f]?.toString();
                          DateTime? cur;
                          if (curIso != null) {
                            try {
                              cur = DateTime.parse(curIso);
                            } catch (_) {}
                          }
                          final picked = await _pickDateTime(context, cur);
                          if (picked != null) await _setField(f, picked);
                        },
                        icon: const Icon(Icons.calendar_month),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Not: İLK/SON yolcu müracaat saatleri boarding kayıtlarından otomatik türetilebilir. Şimdilik manuel alan.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}

// ==========================
// Tab 7: Report (CSV -> Share)
// ==========================

class ReportTab extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> flightRef;
  final String currentUid;

  const ReportTab({super.key, required this.flightRef, required this.currentUid});

  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> {
  bool _busy = false;

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(ts.toDate());
    }
    return '';
  }

  Future<String> _emailOf(String uid) async {
    final s = await Db.userDoc(uid).get();
    return (s.data()?['email'] ?? '').toString();
  }

  Future<void> _log(String type, {Map<String, dynamic>? meta}) async {
    await widget.flightRef.collection('logs').add({
      'type': type,
      'byUid': widget.currentUid,
      'byEmail': await _emailOf(widget.currentUid),
      'at': FieldValue.serverTimestamp(),
      'meta': meta ?? {},
    });
  }

  Future<File> _buildCsvFile() async {
    final flightSnap = await widget.flightRef.get();
    final flightCode = (flightSnap.data()?['flightCode'] ?? 'FLIGHT').toString();

    final paxSnap = await widget.flightRef.collection('pax').orderBy('fullName').get();
    final rows = <List<String>>[];

    // Header (Excel-friendly)
    rows.add([
      'FULL_NAME',
      'PNR',
      'SEAT',
      'STATUS',
      'BOARDING_TIME',
      'BOARDED_BY',
      'OFFLOADED_TIME',
      'OFFLOADED_BY',
    ]);

    for (final d in paxSnap.docs) {
      final data = d.data();
      final name = (data['fullName'] ?? '').toString();
      final pnr = (data['pnr'] ?? '').toString();
      final seat = (data['seat'] ?? '').toString();
      final status = (data['status'] ?? 'NONE').toString();

      rows.add([
        name,
        pnr,
        seat,
        status,
        _fmtTs(data['boardedAt']),
        (data['boardedByEmail'] ?? '').toString(),
        _fmtTs(data['offloadedAt']),
        (data['offloadedByEmail'] ?? '').toString(),
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);

    final dir = await getTemporaryDirectory();
    final safeCode = flightCode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File('${dir.path}/GOZEN_${safeCode}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString('\uFEFF$csv', encoding: utf8); // BOM for Excel
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Rapor (Excel)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Seçenek A: Cihazdan paylaş (CSV). Excel ile açılabilir.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            final file = await _buildCsvFile();
                            await _log('REPORT_EXPORTED', meta: {'path': file.path});
                            await Share.shareXFiles([XFile(file.path)], text: 'GOZEN Boarding Report');
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  icon: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.table_view),
                  label: const Text('Excel Rapor Gönder'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Not: “Gerçek Excel (.xlsx)” istersen excel package ile bir sonraki adımda geçeriz. CSV çoğu operasyon için yeterli.',
                style: TextStyle(fontSize: 12),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// Minimal CSV converter (avoid extra dependency)
class ListToCsvConverter {
  const ListToCsvConverter();

  String convert(List<List<String>> rows) {
    final sb = StringBuffer();
    for (final row in rows) {
      sb.writeln(row.map(_escape).join(','));
    }
    return sb.toString();
  }

  String _escape(String v) {
    final needs = v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r');
    var out = v.replaceAll('"', '""');
    if (needs) out = '"$out"';
    return out;
  }
}
