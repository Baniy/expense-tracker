# Deliverables

This file summarizes the delivered app, how to run it, data schema, API examples, and next steps.

Contents
- Source code: `lib/` — Flutter app scaffold with screens, services, models, widgets.
- Architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- CI: `.github/workflows/flutter-ci.yml`
- Firestore rules: `firestore.rules`

Folder structure (key paths)
- `lib/main.dart` — app entry
- `lib/src/models` — `transaction_model.dart`, `category_model.dart`, `budget_model.dart`
- `lib/src/services` — `auth_service.dart`, `firestore_service.dart`, `sync_service.dart`, `export_service.dart`, `settings_service.dart`
- `lib/src/screens` — auth, dashboard, home, add, history, profile
- `lib/src/widgets` — charts

Database schema (Firestore)
- `users/{uid}/transactions/{tid}`:
  - id, type ("income"|"expense"), categoryId, amount, currency, note, date (timestamp), createdAt, updatedAt
- `users/{uid}/categories/{cid}`: id, name, type, color, icon
- `users/{uid}/budgets/{categoryId}`: categoryId, amount, updatedAt

Security
- Example rules in `firestore.rules` restrict access to `users/{uid}` documents to the authenticated owner. Deploy via `firebase deploy --only firestore:rules`.

Example API calls (Firestore client / Dart)
- Add transaction:
```dart
final doc = FirebaseFirestore.instance.collection('users').doc(uid).collection('transactions').doc();
await doc.set({
  'id': doc.id,
  'type': 'expense',
  'categoryId': 'food',
  'amount': 250.0,
  'currency': 'BDT',
  'note': 'Lunch',
  'date': Timestamp.fromDate(DateTime.now()),
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
});
```
- Query month summary (client-side aggregation): query `date` range and sum by `type`/`category`.

Screens
- Dashboard: totals, monthly income vs expense chart, category pie chart.
- Add: quick-add form (type, category, amount, date, note) with quick amount chips.
- History: searchable, filterable list, edit/delete actions.
- Profile: currency, budgets, export CSV, theme toggle, sign out.

Build & run
1. Configure Firebase for platforms with `flutterfire configure` and add platform config files.
2. Install deps and run:
```bash
flutter pub get
flutter run
```
3. Run tests:
```bash
flutter test
```

Notes on offline & sync
- Firestore persistence enabled in `main.dart`.
- `SyncService` queues failed writes to local JSON and retries on connectivity.
- Writes use `set` with `merge` for safer updates; timestamps help with conflict resolution.

Extras and next steps
- Add scheduled Cloud Functions to precompute monthly summaries and generate heavy exports (PDF/Excel).
- Improve conflict resolution (field-level merges) and add end-to-end tests.
- Add analytics, onboarding, and monetization (premium reports, cloud backup export).

If you want, I can:
- Push this repository to GitHub and run CI
- Deploy Firestore rules to your Firebase project
- Add Cloud Functions for exports or scheduled summaries
