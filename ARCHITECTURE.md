# Expense Tracker - Architecture

Overview
- Flutter client with Riverpod state management
- Firebase backend: Authentication + Cloud Firestore
- Offline-first: Firestore persistence + local Sync queue

Folder structure (lib/)
- `main.dart` - app entry
- `src/models` - data models (`transaction_model.dart`, `category_model.dart`, `budget_model.dart`)
- `src/services` - backend & utilities (`auth_service.dart`, `firestore_service.dart`, `sync_service.dart`, `export_service.dart`, `settings_service.dart`)
- `src/screens` - UI screens (auth, dashboard, history, add, profile)
- `src/widgets` - charts and reusable UI

Data model (Firestore)
- `users/{uid}/transactions/{tid}`: transaction documents
- `users/{uid}/categories/{cid}`: user categories
- `users/{uid}/budgets/{categoryId}`: per-category monthly budgets

Sync strategy
- Firestore offline persistence enabled.
- Local `SyncService` queues failed writes to a local JSON file and retries when connectivity is detected.
- Writes use `set` with `merge` where appropriate to avoid clobbering.

Security
- Use Firebase Authentication and Firestore security rules to ensure users can only access their own `users/{uid}` subtree.

Extensibility
- Cloud Functions can be added for heavy exports, scheduled summaries, or push notifications.
