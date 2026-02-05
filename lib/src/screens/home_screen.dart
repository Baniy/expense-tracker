import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth/login_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'add_transaction_screen.dart';
import 'profile_screen.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Seed default categories when user signs in
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = ref.read(authServiceProvider);
      final uid = auth.currentUser?.uid;
      if (uid != null) {
        final svc = ref.read(firestoreServiceProvider);
        await svc.seedDefaultCategories(uid);
        // ensure sync service is initialized
        ref.read(syncServiceProvider);
      }
    });
  }

  void _onTap(int idx) async {
    if (idx == 2) {
      // Quick Add action: show bottom sheet presets
      await _openQuickAddSheet();
      return;
    }
    setState(() => _index = idx);
  }

  Future<void> _openQuickAddSheet() async {
    final auth = ref.read(authServiceProvider);
    final uid = auth.currentUser?.uid;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Quick Add', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final a in [50, 100, 200, 500, 1000])
                ActionChip(label: Text(a.toString()), onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddTransactionScreen(initialAmount: a.toDouble())));
                }),
            ]),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
              },
              icon: const Icon(Icons.add),
              label: const Text('More options'),
            )
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const DashboardScreen(),
      const HistoryScreen(),
      const SizedBox.shrink(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: tabs[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 40), label: 'Add'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
