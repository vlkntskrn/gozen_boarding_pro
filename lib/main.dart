
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

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class _AppPalette {
  static const Color midnight = Color(0xFF07111E);
  static const Color navy = Color(0xFF0D1B2A);
  static const Color slate = Color(0xFF14273C);
  static const Color steel = Color(0xFF23364B);
  static const Color cyan = Color(0xFF57D6FF);
  static const Color ice = Color(0xFFE9F7FF);
  static const Color gold = Color(0xFFFFD27A);
}

class _AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _AppPalette.cyan,
        brightness: Brightness.light,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF3F7FB),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF07111E),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.92),
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _AppPalette.cyan, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _AppPalette.cyan,
        brightness: Brightness.dark,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: _AppPalette.midnight,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xCC101D2D),
        elevation: 10,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      dividerColor: Colors.white.withOpacity(0.08),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _AppPalette.cyan, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _AppPalette.cyan,
          foregroundColor: _AppPalette.midnight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _AppPalette.cyan,
        foregroundColor: _AppPalette.midnight,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: Colors.white.withOpacity(0.90),
        textColor: Colors.white,
        tileColor: Colors.white.withOpacity(0.02),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }
}

class _GlobalBackdrop extends StatelessWidget {
  final Widget child;
  const _GlobalBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [_AppPalette.midnight, _AppPalette.navy, Color(0xFF06101A)]
                  : const [Color(0xFFF7FBFF), Color(0xFFEAF2FA), Color(0xFFF8FAFD)],
            ),
          ),
        ),
        Positioned(
          top: -60,
          right: -30,
          child: IgnorePointer(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (dark ? _AppPalette.cyan : Colors.white).withOpacity(dark ? 0.10 : 0.65),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          left: -80,
          child: IgnorePointer(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (dark ? _AppPalette.gold : _AppPalette.cyan).withOpacity(dark ? 0.06 : 0.08),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _GlassPanel({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: dark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.80),
        border: Border.all(
          color: dark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.35 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const GozenBoardingApp());
}

class GozenBoardingApp extends StatefulWidget {
  const GozenBoardingApp({super.key});

  @override
  State<GozenBoardingApp> createState() => _GozenBoardingAppState();
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const GozenBoardingApp();
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
      theme: _AppTheme.light(),
      darkTheme: _AppTheme.dark(),
      builder: (context, child) => _GlobalBackdrop(child: child ?? const SizedBox.shrink()),
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
    return Scaffold(
      body: Center(
        child: _GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.local_airport_rounded, size: 38),
              SizedBox(height: 10),
              Text(
                'GOZEN BOARDING PRO',
                style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .6),
              ),
              SizedBox(height: 12),
              SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      ),
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

  static DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      fs.collection('users').doc(uid);

  static CollectionReference<Map<String, dynamic>> invites() =>
      fs.collection('invites');
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
          'role': 'Agent', // Agent or Supervisor
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Ensure email updated
        await ref.set({'email': email}, SetOptions(merge: true));
      }
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GOZEN Crew Access'),
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
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _GlassPanel(
              padding: const EdgeInsets.all(18),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kurumsal Boarding Operasyonu',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Yetkili personel girişi • gerçek zamanlı boarding • offline queue sync',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Kullanıcı Adı (email)',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      decoration: const InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.45),
                      ),
                      child: const Text(
                        'Not: Demo akışta kullanıcı yoksa otomatik kayıt olur.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
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
            title: const Text('GOZEN Boarding Ops'),
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
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => CreateFlightScreen(uid: _uid)),
              );
              if (created == true && mounted) setState(() {});
            },
            icon: const Icon(Icons.add),
            label: const Text('Uçuş Oluştur'),
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: Column(
              children: [
                _PendingInvitesBar(uid: _uid),
                const SizedBox(height: 6),
                Expanded(
                  child: _GlassPanel(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: FlightsList(uid: _uid, role: role),
                  ),
                ),
              ],
            ),
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
        .where('inviteeEmail', isEqualTo: email)
        .where('status', isEqualTo: 'PENDING');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.mark_email_unread_outlined),
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
        .where('inviteeEmail', isEqualTo: email)
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
      return _MergedAgentFlights(uid: uid);
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

class _MergedAgentFlights extends StatelessWidget {
  final String uid;
  const _MergedAgentFlights({required this.uid});

  @override
  Widget build(BuildContext context) {
    final ownedQ = Db.flights()
        .where('ownerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50);

    final partQ = Db.flights()
        .where('participants', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ownedQ.snapshots(),
      builder: (context, snapOwned) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: partQ.snapshots(),
          builder: (context, snapPart) {
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
                            forceAllow: false,
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
  const CreateFlightScreen({super.key, required this.uid});

  @override
  State<CreateFlightScreen> createState() => _CreateFlightScreenState();
}

class _CreateFlightScreenState extends State<CreateFlightScreen> {
  final _flightCode = TextEditingController();
  final _bookedPax = TextEditingController(text: '0');

  final List<_PaxDraft> _paxDrafts = [];
  final List<String> _watchlistNames = [];

  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _flightCode.dispose();
    _bookedPax.dispose();
    super.dispose();
  }

  bool _isValidFlightCode(String v) {
    // Examples: LS976, BA2245
    // Examples: LS976, BA2245, TOM857, XQ0688
    final re = RegExp(r'^[A-Z]{2,3}\d{1,4}$');
    return re.hasMatch(v.toUpperCase());
  }

  Future<void> _addPaxDialog() async {
    final name = TextEditingController();
    final seat = TextEditingController();
    final pnr = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yolcu Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'İsim Soyisim')),
              TextField(controller: seat, decoration: const InputDecoration(labelText: 'Seat')),
              TextField(controller: pnr, decoration: const InputDecoration(labelText: 'PNR (opsiyonel)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
          ],
        );
      },
    );

    if (ok == true) {
      setState(() {
        _paxDrafts.add(_PaxDraft(
          fullName: name.text.trim(),
          seat: seat.text.trim(),
          pnr: pnr.text.trim(),
        ));
      });
    }
  }

  Future<void> _addWatchlistDialog() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WatchList Yolcu Ekle'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'İsim Soyisim'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
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
      final code = _flightCode.text.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (!_isValidFlightCode(code)) {
        throw Exception('Uçuş kodu formatı hatalı. Örn: LS976 / BA2245');
      }

      final booked = int.tryParse(_bookedPax.text.trim()) ?? 0;

      final flightRef = Db.flights().doc();
      final now = FieldValue.serverTimestamp();

      await Db.fs.runTransaction((tx) async {
        tx.set(flightRef, {
          'flightCode': code,
          'bookedPax': booked,
          'ownerUid': widget.uid,
          'participants': <String>[],
          'createdAt': now,
          'offlineMode': false,
          'opTimes': <String, dynamic>{},
        });

        // Create subcollections
        final paxCol = flightRef.collection('pax');
        for (final p in _paxDrafts) {
          tx.set(paxCol.doc(), {
            'fullName': p.fullName,
            'seat': p.seat,
            'pnr': p.pnr,
            'status': 'NONE',
            'boardedAt': null,
            'boardedByUid': null,
            'boardedByEmail': null,
            'offloadedAt': null,
            'offloadedByUid': null,
            'offloadedByEmail': null,
            'createdAt': now,
          });
        }

        final wlCol = flightRef.collection('watchlist');
        for (final n in _watchlistNames) {
          tx.set(wlCol.doc(), {
            'fullName': n,
            'createdAt': now,
          });
        }

        final logCol = flightRef.collection('logs');
        tx.set(logCol.doc(), {
          'type': 'FLIGHT_CREATED',
          'byUid': widget.uid,
          'at': now,
          'meta': {'paxCount': _paxDrafts.length, 'watchlistCount': _watchlistNames.length},
        });
      });

      if (mounted) Navigator.pop(context, true);
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addWatchlistDialog,
                          icon: const Icon(Icons.person_add),
                          label: const Text('WatchList Veri Ekle'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ChipsWrap(
                    items: _watchlistNames,
                    onRemove: (i) => setState(() => _watchlistNames.removeAt(i)),
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addPaxDialog,
                          icon: const Icon(Icons.group_add),
                          label: const Text('Yolcu Ekle'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Yolcu sayısı: ${_paxDrafts.length}'),
                  const SizedBox(height: 8),
                  ..._paxDrafts.map((p) => ListTile(
                        title: Text(p.fullName.isEmpty ? '—' : p.fullName),
                        subtitle: Text('Seat: ${p.seat}  •  PNR: ${p.pnr.isEmpty ? "—" : p.pnr}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => setState(() => _paxDrafts.remove(p)),
                        ),
                      )),
                ],
              ),
            ),
          ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _err!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Uçuşu Kaydet'),
          ),
        ],
      ),
    );
  }
}

class _PaxDraft {
  final String fullName;
  final String seat;
  final String pnr;
  _PaxDraft({required this.fullName, required this.seat, required this.pnr});
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

  Future<_Access> _checkAccess() async {
    final doc = await flightRef.get();
    if (!doc.exists) return _Access(allowed: false, reason: 'Uçuş bulunamadı.');

    final data = doc.data()!;
    final owner = (data['ownerUid'] ?? '').toString();
    final participants = List<String>.from(data['participants'] ?? []);

    if (widget.forceAllow) return _Access(allowed: true, reason: null);

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
                  toolbarHeight: 86,
                  titleSpacing: 12,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'GOZEN BOARDING PRO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Uçuş • $code',
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  actions: const [
                    Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Center(child: _FlightBadge(icon: Icons.verified_user_rounded, text: 'Crew Ops')),
                    ),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(58),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white.withOpacity(0.82),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.10)
                                : Colors.white.withOpacity(0.90),
                          ),
                        ),
                        child: const TabBar(
                          isScrollable: true,
                          dividerColor: Colors.transparent,
                          tabAlignment: TabAlignment.start,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            gradient: LinearGradient(
                              colors: [_AppPalette.cyan, Color(0xFF8BE6FF)],
                            ),
                          ),
                          labelColor: _AppPalette.midnight,
                          labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
                    ),
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


class _FlightBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FlightBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: (dark ? Colors.white : _AppPalette.navy).withOpacity(dark ? 0.06 : 0.05),
        border: Border.all(
          color: (dark ? Colors.white : _AppPalette.navy).withOpacity(0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: dark ? _AppPalette.cyan : _AppPalette.navy),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
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

  // Camera scanner (MobileScanner)
  bool _cameraOn = true;
  String? _lastParsedPreview;
  DateTime? _lastCamHitAt;
  String? _lastCamRaw;

  late final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.pdf417,
      BarcodeFormat.aztec,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
    ],
  );

  bool _torchOn = false;


  
  // --- Flight code normalization & matching (IATA/ICAO tolerant) ---
  static const Map<String, String> _icaoToIata = {
    // Jet2
    'EXS': 'LS',
    // British Airways
    'BAW': 'BA',
    // TUI group / partners
    'TFL': 'OR', // TUI fly Netherlands
    'TUI': 'X3', // TUIfly (Germany)
    'TOM': 'BY', // TUI Airways (historical; many boarding passes show TOM)
    // SunExpress
    'SXS': 'XQ',
    // Freebird Airlines
    'FHY': 'FH',
  };

  static const Map<String, String> _iataToIcao = {
    'LS': 'EXS',
    'BA': 'BAW',
    'OR': 'TFL',
    'X3': 'TUI',
    'BY': 'TOM',
    'XQ': 'SXS',
    'FH': 'FHY',
    'TI': 'TWI', // Tailwind Airlines
  };

  String _normalizeFlightCode(String input) {
    final s = input.trim().toUpperCase();
    if (s.isEmpty) return '';
    // Remove everything except letters/digits.
    final cleaned = s.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    // Accept 1-3 alnum prefix + 1-5 digits + optional suffix letter.
    final m = RegExp(r'^([A-Z0-9]{1,3})(0*)([0-9]{1,5})([A-Z]?)$').firstMatch(cleaned);
    if (m == null) return cleaned;

    final prefix = m.group(1)!;
    final digits = m.group(3)!;
    final suffix = (m.group(4) ?? '').trim();
    final digitsNoLeading = digits.replaceFirst(RegExp(r'^0+'), '');
    final numPart = digitsNoLeading.isEmpty ? '0' : digitsNoLeading;
    return '$prefix$numPart$suffix';
  }

  Set<String> _flightCodeAlternatives(String code) {
    final n = _normalizeFlightCode(code);
    if (n.isEmpty) return <String>{};

    final m = RegExp(r'^([A-Z0-9]{1,3})([0-9]{1,5})([A-Z]?)$').firstMatch(n);
    if (m == null) return <String>{n};

    final pref = m.group(1)!;
    final num = m.group(2)!;
    final suf = (m.group(3) ?? '').trim();

    final out = <String>{n};

    // Many printed boarding passes show booking class right after the flight number (e.g. "LS 1850 Y").
    // Treat trailing single letter as optional by adding a no-suffix variant.
    if (suf.isNotEmpty) {
      out.add('$pref$num');
    }

    // If given as ICAO (3), add IATA alt.
    if (pref.length == 3 && _icaoToIata.containsKey(pref)) {
      out.add('${_icaoToIata[pref]}$num$suf');
      if (suf.isNotEmpty) out.add('${_icaoToIata[pref]}$num');
    }

    // If given as IATA, add ICAO alt.
    if (_iataToIcao.containsKey(pref)) {
      out.add('${_iataToIcao[pref]}$num$suf');
      if (suf.isNotEmpty) out.add('${_iataToIcao[pref]}$num');
    }

    return out;
  }


  bool _flightCodeMatches(String expected, String scanned) {
    final a = _flightCodeAlternatives(expected);
    final b = _flightCodeAlternatives(scanned);
    return a.intersection(b).isNotEmpty;
  }

  Map<String, String> _parseScanPayload(String raw, {String? expectedFlightCode}) {
    final rFixed = _sanitizeScanRawPreserve(raw);
    final r = rFixed.trim();
    if (r.isEmpty) return {};

    if (r.contains('|')) {
      final parts = r.split('|').map((e) => e.trim()).toList();
      return {
        'flightCode': parts.isNotEmpty ? parts[0] : '',
        'fullName': parts.length > 1 ? parts[1] : '',
        'seat': parts.length > 2 ? parts[2] : '',
        'pnr': parts.length > 3 ? parts[3] : '',
      };
    }

    final up = rFixed.toUpperCase();
    if (up.length >= 40 && (up.startsWith('M') || up.startsWith('S'))) {
      try {
        final nameRaw = up.length >= 22 ? up.substring(2, 22).trim() : '';
        final pnrRaw = up.length >= 30 ? up.substring(23, 30).trim() : '';
        final name = _normalizeBcbpName(nameRaw);
        final pnr = pnrRaw.replaceAll(RegExp(r'[^A-Z0-9]'), '');

        String flightCode = '';
        String flightCodeRaw = '';
        String seat = '';

        if (up.length >= 52) {
          final carrier3 = up.substring(36, 39).trim().replaceAll(RegExp(r'[^A-Z0-9]'), '');
          final flight5 = up.substring(39, 44).trim();
          final seat4 = up.substring(48, 52).trim();
          final flightNum = flight5.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0+'), '');
          seat = seat4.replaceAll(' ', '').replaceAll('-', '').replaceFirst(RegExp(r'^0+'), '');
          if (carrier3.isNotEmpty && flightNum.isNotEmpty) {
            final carrier2 = _icaoToIata[carrier3] ?? carrier3;
            flightCode = '$carrier2$flightNum';
            flightCodeRaw = '$carrier3$flightNum';
          }
        }

        final regexFlight = _extractFlightCodeLoose(_sanitizeScanRaw(raw), expectedFlightCode: expectedFlightCode);
        if (regexFlight.isNotEmpty) {
          final fixedHits = flightCode.isNotEmpty && (expectedFlightCode ?? '').isNotEmpty && _flightCodeMatches(expectedFlightCode!, flightCode);
          final regexHits = (expectedFlightCode ?? '').isNotEmpty && _flightCodeMatches(expectedFlightCode!, regexFlight);
          if (flightCode.isEmpty || (!fixedHits && regexHits)) {
            flightCode = regexFlight;
            if (flightCodeRaw.isEmpty) flightCodeRaw = regexFlight;
          }
        }

        if (seat.isEmpty) seat = _extractSeatLoose(up);

        if (flightCode.isNotEmpty || name.isNotEmpty || seat.isNotEmpty || pnr.isNotEmpty) {
          return {
            'flightCode': flightCode,
            'fullName': name,
            'seat': seat,
            'pnr': pnr,
            'flightCodeRaw': flightCodeRaw,
          };
        }
      } catch (_) {}
    }

    return {
      'flightCode': _extractFlightCodeLoose(r, expectedFlightCode: expectedFlightCode),
      'fullName': _normalizeBcbpName(r),
      'seat': _extractSeatLoose(r),
      'pnr': '',
    };
  }

  String _sanitizeScanRawPreserve(String raw) {
    final sb = StringBuffer();
    for (final c in raw.runes) {
      if (c == 9 || c == 10 || c == 13) {
        sb.write(' ');
      } else if (c >= 32 && c <= 126) {
        sb.writeCharCode(c);
      } else {
        sb.write(' ');
      }
    }
    return sb.toString();
  }

  String _sanitizeScanRaw(String raw) {
    return _sanitizeScanRawPreserve(raw).replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeBcbpName(String rawName) {
    var up = rawName.toUpperCase().trim();
    if (up.isEmpty) return '';
    final m = RegExp(r'([A-Z]+)\/([A-Z]+)').firstMatch(up);
    if (m != null) {
      final last = m.group(1) ?? '';
      var first = m.group(2) ?? '';
      first = first.replaceAll(RegExp(r'(MR|MRS|MS|MISS|MSTR|MASTER|CHD|INF|INFT|MI)$'), '');
      return ('$last $first').trim();
    }
    up = up.replaceAll('/', ' ').replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ');
    return up.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _extractFlightCodeLoose(String raw, {String? expectedFlightCode}) {
    final up = raw.toUpperCase();
    final expected = (expectedFlightCode ?? '').trim();

    // BCBP-friendly extraction: FROM(3) + TO(3) + CARRIER(2/3) + FLIGHT(1-4)
    // Examples: DLMMANLS 1730, BRSDLMTOM0836, DLMEDIXQ 0688
    final bcbpLeg = RegExp(r'\b([A-Z]{3})([A-Z]{3})([A-Z0-9]{2,3})\s*0*([0-9]{1,4})\b');
    for (final m in bcbpLeg.allMatches(up)) {
      final carrier = (m.group(3) ?? '').trim();
      final num = (m.group(4) ?? '').trim();
      final n = _normalizeFlightCode('$carrier$num');
      if (n.isEmpty) continue;
      if (expected.isNotEmpty && _flightCodeMatches(expected, n)) return n;
    }

    final re1 = RegExp(r'\b([A-Z0-9]{1,3})\s*0*([0-9]{1,5})(?:\s*[A-Z])?\b');
    final matches = re1.allMatches(up).toList();

    String best = '';
    int bestScore = -999;

    for (final m in matches) {
      final code = (m.group(1) ?? '').trim();
      final num = (m.group(2) ?? '').trim();
      if (code.isEmpty || num.isEmpty) continue;
      final n = _normalizeFlightCode('$code$num');
      if (n.isEmpty) continue;

      int score = 0;
      if (_iataToIcao.containsKey(code) || _icaoToIata.containsKey(code)) score += 5;
      if (num.length >= 2 && num.length <= 4) score += 2;
      if (expected.isNotEmpty && _flightCodeMatches(expected, n)) score += 100;
      if (score > bestScore) {
        bestScore = score;
        best = n;
      }
    }

    if (best.isNotEmpty) return best;

    final cleaned = up.replaceAll(RegExp(r'[^A-Z0-9]'), ' ');
    final tokens = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    for (final t in tokens) {
      final n = _normalizeFlightCode(t);
      if (RegExp(r'^[A-Z0-9]{1,3}[0-9]{1,5}[A-Z]?$').hasMatch(n)) {
        if (expected.isEmpty || _flightCodeMatches(expected, n)) return n;
        if (best.isEmpty) best = n;
      }
    }
    return best;
  }

  String _extractSeatLoose(String text) {
    final up = text.toUpperCase();
    // 03-C / 32F / 11E
    final m = RegExp(r'\b([0-9]{1,2})\s*[-]?\s*([A-Z])\b').firstMatch(up);
    if (m == null) return '';
    return '${m.group(1)}${m.group(2)}';
  }

@override
  void initState() {
    super.initState();
    _loadOffline();
  }

  Future<void> _loadOffline() async {
    final snap = await widget.flightRef.get();
    final data = snap.data() ?? {};
    setState(() => _offline = (data['offlineMode'] ?? false) == true);
  }

  Future<void> _toggleOffline(bool v) async {
    setState(() => _offline = v);
    await widget.flightRef.set({'offlineMode': v}, SetOptions(merge: true));
    await _log('OFFLINE_MODE_TOGGLED', meta: {'value': v});
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
    final scannedKeys = _nameKeyVariants(fullName);
    if (scannedKeys.isEmpty) return false;

    final snap = await widget.flightRef.collection('watchlist').limit(500).get();
    for (final d in snap.docs) {
      final data = d.data();
      final wlName = (data['fullName'] ?? '').toString();
      if (wlName.trim().isEmpty) continue;

      // Prefer precomputed keys if present
      final List<dynamic>? stored = data['nameKeys'] is List ? (data['nameKeys'] as List) : null;
      final wlKeys = <String>{};
      if (stored != null) {
        for (final v in stored) {
          if (v is String && v.trim().isNotEmpty) wlKeys.add(v.trim().toUpperCase());
        }
      } else {
        wlKeys.addAll(_nameKeyVariants(wlName));
      }

      if (wlKeys.intersection(scannedKeys).isNotEmpty) return true;
    }
    return false;
  }

  Set<String> _nameKeyVariants(String s) {
    var up = s.toUpperCase();

    // Common titles / prefixes / suffixes found on boarding passes
    const titles = [
      'MR', 'MRS', 'MS', 'MISS', 'MSTR', 'MASTER',
      'DR', 'PROF', 'SIR', 'MADAM',
      'INF', 'INFT', 'INFANT', 'CHD', 'CHILD'
    ];

    // Replace separators with space, keep only A-Z0-9 and spaces
    up = up.replaceAll('/', ' ').replaceAll('.', ' ').replaceAll('-', ' ');
    up = up.replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ');
    up = up.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (up.isEmpty) return <String>{};

    var tokens = up.split(' ').where((t) => t.isNotEmpty).toList();

    // Strip titles from start/end (can repeat like "MR MR")
    while (tokens.isNotEmpty && titles.contains(tokens.first)) tokens.removeAt(0);
    while (tokens.isNotEmpty && titles.contains(tokens.last)) tokens.removeLast();

    if (tokens.isEmpty) return <String>{};

    final joined = tokens.join('');
    final reversedJoined = tokens.reversed.join('');

    final keys = <String>{};
    keys.add(joined);
    keys.add(reversedJoined);

    // Also add bi-grams for robustness (e.g. LASTFIRSTMR glued)
    if (tokens.length >= 2) {
      keys.add(tokens[0] + tokens[1]);
      keys.add(tokens[1] + tokens[0]);
    }

    // Add each token itself (handles single token watchlist entries)
    for (final t in tokens) {
      if (t.length >= 3) keys.add(t);
    }

    return keys;
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
  Future<void> _processScanString(String raw) async {
    final fSnap0 = await widget.flightRef.get();
    final expectedCode = (fSnap0.data()?['flightCode'] ?? '').toString();
    final parsed = _parseScanPayload(raw, expectedFlightCode: expectedCode);
    if (parsed.isEmpty) {
      throw Exception('Scan verisi boş / anlaşılamadı.');
    }

    final flightCode = (parsed['flightCode'] ?? '').toString().trim().toUpperCase();
    final flightCodeRaw = (parsed['flightCodeRaw'] ?? '').toString().trim().toUpperCase();
    final fullName = (parsed['fullName'] ?? '').toString().trim();
    final seat = (parsed['seat'] ?? '').toString().trim().toUpperCase();
    final pnr = (parsed['pnr'] ?? '').toString().trim().toUpperCase();

    if (flightCode.isEmpty && flightCodeRaw.isEmpty) {
      throw Exception('Uçuş kodu okunamadı.');
    }

    final fSnap = await widget.flightRef.get();
    final fCode = (fSnap.data()?['flightCode'] ?? '').toString();

    final ok = _flightCodeMatches(fCode, flightCode) ||
        (flightCodeRaw.isNotEmpty && _flightCodeMatches(fCode, flightCodeRaw));

    if (!ok) {
      final exp = _normalizeFlightCode(fCode);
      final got = _normalizeFlightCode(flightCode.isNotEmpty ? flightCode : flightCodeRaw);
      throw Exception('Uçuş kodu eşleşmedi. Beklenen: $exp / Okunan: $got');
    }

// Offer Pre-BOARD vs DFT Random
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

    // Find existing pax by (fullName + seat) or create if missing.
    final paxCol = widget.flightRef.collection('pax');
    final q = await paxCol
        .where('fullName', isEqualTo: fullName)
        .where('seat', isEqualTo: seat)
        .limit(1)
        .get();

    DocumentReference<Map<String, dynamic>> paxRef;
    if (q.docs.isNotEmpty) {
      paxRef = q.docs.first.reference;
    } else {
      paxRef = paxCol.doc();
      await paxRef.set({
        'fullName': fullName,
        'seat': seat,
        'pnr': pnr,
        'status': 'NONE',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final byEmail = await _emailOf(widget.currentUid);
    final now = FieldValue.serverTimestamp();

    if (choice == 'PRE') {
      await paxRef.set({
        'status': 'PREBOARDED',
        'boardedAt': now,
        'boardedByUid': widget.currentUid,
        'boardedByEmail': byEmail,
      }, SetOptions(merge: true));

      await _log('PAX_PREBOARDED', meta: {'fullName': fullName, 'seat': seat});

      await _showResultScreen(
        bg: Colors.green,
        title: 'PRE-BOARD SUCCESSFULL',
      );
    } else {
      await paxRef.set({
        'status': 'DFT_BOARDED',
        'boardedAt': now,
        'boardedByUid': widget.currentUid,
        'boardedByEmail': byEmail,
      }, SetOptions(merge: true));

      await _log('PAX_RANDOM_SELECTED', meta: {'fullName': fullName, 'seat': seat, 'watchlistMatch': isWl});

      if (isWl) {
        await _showResultScreen(
          bg: Colors.red,
          title: 'FLY PASSANGER ATTANTION!!!',
          subtitle: 'RANDOM SELECTION SUCCESSFULL',
        );
      } else {
        await _showResultScreen(
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
      await selected.reference.set({
        'status': 'OFFLOADED',
        'offloadedAt': FieldValue.serverTimestamp(),
        'offloadedByUid': widget.currentUid,
        'offloadedByEmail': byEmail,
      }, SetOptions(merge: true));
      await _log('PAX_OFFLOADED_MANUAL', meta: {'paxId': selected.id});
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
    final meRoleSnap = await Db.userDoc(widget.currentUid).get();
    final myRole = (meRoleSnap.data()?['role'] ?? 'Agent').toString();

    final fSnap = await widget.flightRef.get();
    final ownerUid = (fSnap.data()?['ownerUid'] ?? '').toString();

    final canInvite = myRole == 'Supervisor' || ownerUid == widget.currentUid;

    if (!canInvite) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sadece uçuş sahibi veya Supervisor davet gönderebilir.')),
      );
      return;
    }

    final emailC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kullanıcı Davet Et (Agent)'),
        content: TextField(
          controller: emailC,
          decoration: const InputDecoration(labelText: 'Kullanıcı email'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Davet Gönder')),
        ],
      ),
    );

    if (ok != true) return;

    final inviteeEmail = emailC.text.trim();
    if (inviteeEmail.isEmpty) return;

    final fData = fSnap.data() ?? {};
    final flightCode = (fData['flightCode'] ?? '').toString();

    await Db.invites().add({
      'flightId': widget.flightRef.id,
      'flightCode': flightCode,
      'inviteeEmail': inviteeEmail,
      'status': 'PENDING',
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': widget.currentUid,
    });

    await _log('INVITE_SENT', meta: {'inviteeEmail': inviteeEmail});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Davet gönderildi.')),
      );
    }
  }


  String _truncate(String s, [int max = 140]) {
    if (s.length <= max) return s;
    return s.substring(0, max) + '…';
  }

  String _previewFromParsed(Map<String, String?> p, String raw) {
    final fc = (p['flightCode'] ?? '').trim();
    final nm = (p['fullName'] ?? '').trim();
    final st = (p['seat'] ?? '').trim();
    final pn = (p['pnr'] ?? '').trim();
    return 'RAW: ${_truncate(raw)}\nFLIGHT: $fc  SEAT: $st  PNR: $pn\nNAME: $nm';
  }

  Future<void> _onCameraDetect(BarcodeCapture capture) async {
    if (!_cameraOn) return;
    String raw = '';
    for (final b in capture.barcodes) {
      final v = (b.rawValue ?? b.displayValue ?? '').trim();
      if (v.isNotEmpty) {
        raw = v;
        break;
      }
    }
    if (raw.trim().isEmpty) return;

    final now = DateTime.now();
    if (_lastCamRaw == raw && _lastCamHitAt != null && now.difference(_lastCamHitAt!).inMilliseconds < 1200) {
      return;
    }
    _lastCamRaw = raw;
    _lastCamHitAt = now;

    try {
      final fSnap0 = await widget.flightRef.get();
      final expectedCode = (fSnap0.data()?['flightCode'] ?? '').toString();
      final parsed = _parseScanPayload(raw, expectedFlightCode: expectedCode);
      if (mounted) {
        setState(() => _lastParsedPreview = _previewFromParsed(parsed, raw));
      }
      await _processScanString(raw);
    } catch (e) {
      if (mounted) {
        setState(() => _lastParsedPreview = 'SCAN ERROR: $e\nRAW: ${_truncate(raw)}');
      }
    }
  }

  @override
  void dispose() {
    _manualScan.dispose();
    _scannerController.dispose();
    super.dispose();
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
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        value: _cameraOn,
                        onChanged: (v) => setState(() => _cameraOn = v),
                        title: const Text('Kamera (Scan)'),
                        subtitle: const Text('Varsayılan açık. İstersen kapatıp manuel giriş yapabilirsin.'),
                      ),
                      if (_cameraOn) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                MobileScanner(
                                  controller: _scannerController,
                                  onDetect: _onCameraDetect,
                                ),
                                Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Torch',
                                          onPressed: () async {
                                            await _scannerController.toggleTorch();
                                            if (mounted) setState(() => _torchOn = !_torchOn);
                                          },
                                          icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_lastParsedPreview != null) ...[
                        Text(
                          _lastParsedPreview!,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
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
                      ),
                    ],
                  ),
                ),
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
      subtitle: Text('Seat: $seat  •  PNR: ${pnr.isEmpty ? "—" : pnr}\n'
          'Status: $status\n'
          'Boarded: ${timeStr(boardedAt)}  •  By: ${boardedBy.isEmpty ? "—" : boardedBy}\n'
          'Offload: ${timeStr(offAt)}  •  By: ${offBy.isEmpty ? "—" : offBy}'),
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
    final scannedKeys = _nameKeyVariants(fullName);
    if (scannedKeys.isEmpty) return false;

    final snap = await widget.flightRef.collection('watchlist').limit(500).get();
    for (final d in snap.docs) {
      final data = d.data();
      final wlName = (data['fullName'] ?? '').toString();
      if (wlName.trim().isEmpty) continue;

      // Prefer precomputed keys if present
      final List<dynamic>? stored = data['nameKeys'] is List ? (data['nameKeys'] as List) : null;
      final wlKeys = <String>{};
      if (stored != null) {
        for (final v in stored) {
          if (v is String && v.trim().isNotEmpty) wlKeys.add(v.trim().toUpperCase());
        }
      } else {
        wlKeys.addAll(_nameKeyVariants(wlName));
      }

      if (wlKeys.intersection(scannedKeys).isNotEmpty) return true;
    }
    return false;
  }

  Set<String> _nameKeyVariants(String s) {
    var up = s.toUpperCase();

    // Common titles / prefixes / suffixes found on boarding passes
    const titles = [
      'MR', 'MRS', 'MS', 'MISS', 'MSTR', 'MASTER',
      'DR', 'PROF', 'SIR', 'MADAM',
      'INF', 'INFT', 'INFANT', 'CHD', 'CHILD'
    ];

    // Replace separators with space, keep only A-Z0-9 and spaces
    up = up.replaceAll('/', ' ').replaceAll('.', ' ').replaceAll('-', ' ');
    up = up.replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ');
    up = up.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (up.isEmpty) return <String>{};

    var tokens = up.split(' ').where((t) => t.isNotEmpty).toList();

    // Strip titles from start/end (can repeat like "MR MR")
    while (tokens.isNotEmpty && titles.contains(tokens.first)) tokens.removeAt(0);
    while (tokens.isNotEmpty && titles.contains(tokens.last)) tokens.removeLast();

    if (tokens.isEmpty) return <String>{};

    final joined = tokens.join('');
    final reversedJoined = tokens.reversed.join('');

    final keys = <String>{};
    keys.add(joined);
    keys.add(reversedJoined);

    // Also add bi-grams for robustness (e.g. LASTFIRSTMR glued)
    if (tokens.length >= 2) {
      keys.add(tokens[0] + tokens[1]);
      keys.add(tokens[1] + tokens[0]);
    }

    // Add each token itself (handles single token watchlist entries)
    for (final t in tokens) {
      if (t.length >= 3) keys.add(t);
    }

    return keys;
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
      }, SetOptions(merge: true));
      await _log('PAX_PREBOARDED_MANUAL', meta: {'fullName': name, 'seat': seat});
    } else {
      await paxDoc.reference.set({
        'status': 'DFT_BOARDED',
        'boardedAt': FieldValue.serverTimestamp(),
        'boardedByUid': widget.currentUid,
        'boardedByEmail': byEmail,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: dark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.75),
        border: Border.all(
          color: dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          initiallyExpanded: title != 'Diğer',
          leading: Icon(
            Icons.groups_2_rounded,
            color: dark ? _AppPalette.cyan : _AppPalette.navy,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: (dark ? _AppPalette.cyan : _AppPalette.navy).withOpacity(0.10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          children: children.isEmpty
              ? const [Padding(padding: EdgeInsets.all(12), child: Text('Boş.'))]
              : children,
        ),
      ),
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

  static List<String> _buildNameKeys(String s) {
    var up = s.toUpperCase();
    const titles = [
      'MR', 'MRS', 'MS', 'MISS', 'MSTR', 'MASTER',
      'DR', 'PROF', 'SIR', 'MADAM',
      'INF', 'INFT', 'INFANT', 'CHD', 'CHILD'
    ];
    up = up.replaceAll('/', ' ').replaceAll('.', ' ').replaceAll('-', ' ');
    up = up.replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ');
    up = up.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (up.isEmpty) return const [];
    var tokens = up.split(' ').where((t) => t.isNotEmpty).toList();
    while (tokens.isNotEmpty && titles.contains(tokens.first)) tokens.removeAt(0);
    while (tokens.isNotEmpty && titles.contains(tokens.last)) tokens.removeLast();
    if (tokens.isEmpty) return const [];
    final keys = <String>{};
    keys.add(tokens.join(''));
    keys.add(tokens.reversed.join(''));
    if (tokens.length >= 2) {
      keys.add(tokens[0] + tokens[1]);
      keys.add(tokens[1] + tokens[0]);
    }
    for (final t in tokens) {
      if (t.length >= 3) keys.add(t);
    }
    return keys.toList();
  }


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
      'nameKeys': WatchlistTab._buildNameKeys(name),
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


// Full-screen camera scanner for boarding pass barcodes (PDF417 / QR / Aztec).
class BoardingPassScannerPage extends StatefulWidget {
  final String title;
  const BoardingPassScannerPage({super.key, this.title = 'Biniş Kartı Tara'});

  @override
  State<BoardingPassScannerPage> createState() => _BoardingPassScannerPageState();
}

class _BoardingPassScannerPageState extends State<BoardingPassScannerPage> {
  late final MobileScannerController _controller;

  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_popped) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _popped = true;
        try {
          await _controller.stop();
        } catch (_) {}
        if (mounted) Navigator.of(context).pop(raw.trim());
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Flaş',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            tooltip: 'Kamera değiştir',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Kamera açılamadı: ${error.errorDetails?.message ?? error.toString()}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.82,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(.95), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _AppPalette.cyan.withOpacity(.20),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), color: _AppPalette.cyan),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), color: _AppPalette.cyan.withOpacity(.7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 18,
            child: _GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kamera varsayılan açık • Biniş kartını çerçeve içine hizalayın',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
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
