# MobileProject

MobileProject is a waste classification and recycling assistance system. It
contains a Flutter application for scanning waste items and a backend service
for authentication, classification, scan history, and collection requests.

## Repository structure

```text
MobileProject/
├── GreenVision/    # Flutter mobile and desktop application
└── backend/        # Node.js REST API and model service
```

## Main components

### GreenVision

The Flutter application provides:

- Camera and gallery-based waste scanning.
- Classification results with confidence and disposal guidance.
- Local scan history and statistics.
- User profiles and authentication.
- Collection requests and an OpenStreetMap-based map.
- English, French, and Arabic localization.

See the [GreenVision README](GreenVision/README.md) for Flutter setup,
configuration, testing, and supported platforms.

### Backend

The Node.js backend provides:

- User registration, login, and password recovery.
- Authenticated waste classification.
- Scan history and statistics endpoints.
- Waste collection request management.
- SQLite persistence and integration with the model service.

See the [backend README](backend/README.md) for server setup, environment
configuration, database migration, and API endpoints.

## Quick start

### Start the backend

```powershell
Set-Location backend
npm install
Copy-Item .env.example .env
npm run db:migrate
npm run dev
```

### Run the Flutter application

In another terminal:

```powershell
Set-Location GreenVision
flutter pub get
flutter run
```

For an offline interface demo:

```powershell
flutter run -d windows --dart-define=CLASSIFIER_MODE=mock
```

## Testing

Flutter checks:

```powershell
Set-Location GreenVision
flutter analyze
flutter test
```

Backend syntax check:

```powershell
Set-Location backend
npm run check
```

## License

This project is licensed under the [GNU General Public License v3.0](GreenVision/LICENSE).
