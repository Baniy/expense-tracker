import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/screens/auth/login_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/services/settings_service.dart';
import 'src/services/auth_service.dart';
import 'src/themes/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
    firebaseReady = true;
  } catch (_) {}

  runApp(ProviderScope(
    child: firebaseReady ? const ExpenseApp() : const _SetupScreen(),
  ));
}

class ExpenseApp extends ConsumerWidget {
  const ExpenseApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final settings = ref.watch(settingsNotifierProvider);

    return MaterialApp(
      title: 'Expense Tracker',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.isDark ? ThemeMode.dark : ThemeMode.light,
      home: StreamBuilder(
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) return const HomeScreen();
          return const LoginScreen();
        },
      ),
    );
  }
}

class _SetupScreen extends StatelessWidget {
  const _SetupScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_balance_wallet,
                      size: 56, color: Colors.indigo),
                  const SizedBox(height: 16),
                  Text('Expense Tracker',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Firebase not configured',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.orange[700])),
                  const SizedBox(height: 24),
                  const Text(
                      'This app needs a Firebase project for authentication '
                      'and data storage. Follow these steps to connect it:'),
                  const SizedBox(height: 20),
                  _Step(
                    n: '1',
                    title: 'Create a Firebase project',
                    body:
                        'Go to console.firebase.google.com → Add project → '
                        'enable Email/Password auth and Cloud Firestore.',
                  ),
                  _Step(
                    n: '2',
                    title: 'Generate credentials',
                    body: 'In your terminal:\n'
                        'dart pub global activate flutterfire_cli\n'
                        'flutterfire configure --project=YOUR_PROJECT_ID\n\n'
                        'This creates lib/firebase_options.dart.',
                  ),
                  _Step(
                    n: '3',
                    title: 'Update main.dart (one line)',
                    body:
                        "Change the initializeApp() call to:\nawait Firebase.initializeApp(\n  options: DefaultFirebaseOptions.currentPlatform);",
                  ),
                  _Step(
                    n: '4',
                    title: 'Rebuild & redeploy',
                    body:
                        'flutter build web --release --base-href /expense-tracker/\n'
                        'Then push build/web to the gh-pages branch.',
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

class _Step extends StatelessWidget {
  final String n;
  final String title;
  final String body;
  const _Step(
      {Key? key, required this.n, required this.title, required this.body})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.indigo,
            child: Text(n,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(body,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
