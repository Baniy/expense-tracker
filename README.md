
Expense & Income Tracker (Flutter + Firebase)

Features
- Email/password authentication
- Add / edit / delete transactions (income & expense)
- Categories, budgets, and monthly summaries
- Offline-first with local sync queue
- Dashboard with monthly and category charts
- Dark mode, quick-add, CSV export

Quick start

1. Install Flutter SDK: https://flutter.dev/docs/get-started/install
2. Create Firebase project and enable Email/Password Auth and Firestore.
3. Install FlutterFire CLI and configure Firebase for your platforms:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

4. Place the generated Firebase config files for Android and iOS into the platform folders.
5. Run:

```bash
flutter pub get
flutter run
```

Run tests:

```bash
flutter test
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for design and implementation notes.

Continuous integration
- A GitHub Actions workflow is provided at `.github/workflows/flutter-ci.yml` to run `flutter analyze` and tests on push/PR.

Security rules
- Example Firestore rules are included in `firestore.rules`. Update and deploy them to your Firebase project.


