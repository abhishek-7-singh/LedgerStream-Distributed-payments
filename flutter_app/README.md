# LedgerStream Flutter Client

Flutter application that mirrors the LedgerStream web experience for the distributed payment gateway. The app provides the same payment submission form, status filtering, and transaction history views, powered by the existing Gateway API.

## Features

- Submit payments with transaction, merchant, customer, amount, currency, and reference fields
- Display live payment history with status badges and formatted amounts
- Filter payments by status (`all`, `pending`, `confirmed`, `declined`, `retry`)
- Automatic refresh every 15 seconds, plus manual refresh controls
- Snackbars for success and error feedback after submissions
- Responsive layout that adapts to tablets and desktops (Flutter web)

## Project Structure

```
flutter_app/
├── analysis_options.yaml
├── lib/
│   ├── app.dart                # MaterialApp and theme wiring
│   ├── main.dart               # Entrypoint with ProviderScope
│   ├── theme.dart              # Custom theming to match web UI
│   ├── core/
│   │   ├── config.dart         # API base URL + refresh cadence
│   │   ├── exceptions/         # Error types
│   │   └── http/               # REST client wrapper
│   └── features/
│       └── payments/
│           ├── data/           # Repository and API bindings
│           ├── models/         # DTOs mirroring backend schema
│           └── presentation/   # Dashboard, form, list UI & providers
├── pubspec.yaml
└── README.md
```

## Getting Started

1. **Install Flutter** (3.22+ recommended)

   ```bash
   flutter --version
   ```

2. **Fetch dependencies**

   ```bash
   cd flutter_app
   flutter pub get
   ```

3. **(Optional) Add platform folders** if you plan to target Android/iOS/Desktop

   ```bash
   flutter create .
   ```

4. **Run the application** (ensure the backend stack is running on `http://localhost:8000/api`)

   ```bash
   flutter run -d chrome   # Web
   # or
   flutter run             # First available device
   ```

   Override the API endpoint at build time if needed:

   ```bash
   flutter run --dart-define=LEDGERSTREAM_API_BASE_URL=https://your-host/api
   ```

## Configuration

- Default API base URL: `http://localhost:8000/api`
- Update via `--dart-define=LEDGERSTREAM_API_BASE_URL=<url>` when running or building.
- Auto-refresh interval: 15 seconds (`paymentsAutoRefreshInterval` in `lib/core/config.dart`).

## Testing

Add widget or integration tests under `flutter_app/test/` and run:

```bash
flutter test
```

## Notes

- The UI mirrors the React frontend styles and flows, including status chips, ledger cards, and form behavior.
- When connecting from a mobile device, ensure the API base URL is reachable (use LAN IP instead of `localhost`).
