# GreenVision

GreenVision is a cross-platform Flutter application for identifying household
waste and helping users choose the right disposal method. Users can scan an
item with the camera or select an image, review the predicted label and
confidence, save the result locally, and request waste collection.

## Features

- Camera scanning with a framing guide and precise image cropping.
- Image selection from the device gallery.
- Waste classification through a configurable backend or supported hosted
  inference services.
- Offline mock classification mode for UI development and automated tests.
- Disposal guidance grouped into organic, recyclable, and other waste.
- Local scan history with daily, weekly, and monthly statistics.
- User registration, login, sessions, and profile management.
- Collection requests with waste types, pickup dates, notes, status tracking,
  and map locations.
- OpenStreetMap-based map view with geolocation and reverse geocoding.
- English, French, and Arabic localization, including RTL support.

## Classification labels

The application maps model labels to the following waste groups:

| Model label | Group |
| --- | --- |
| Food Organics | Organic |
| Vegetation | Organic |
| Cardboard | Recyclable |
| Paper | Recyclable |
| Plastic | Recyclable |
| Glass | Recyclable |
| Metal | Recyclable |
| Textile Trash | Other |
| Miscellaneous Trash | Other |

## Project structure

```text
GreenVision/
├── lib/
│   ├── core/                 # Configuration, theme, and shared widgets
│   ├── data/                 # Models, SQLite storage, and repositories
│   ├── features/             # Authentication, scanning, history, maps, and UI
│   └── services/             # Classification, geocoding, images, and permissions
├── assets/
│   ├── fonts/
│   └── translations/
├── test/                     # Unit and widget tests
└── tool/                     # Windows release and verification scripts

backend/
├── src/                      # Express API
├── data/                     # SQLite database files
├── ml-service/               # Model service
└── package.json
```

## Requirements

### Flutter application

- Flutter SDK with Dart 3.12.2 or newer.
- Android Studio and Android SDK for Android builds.
- Visual Studio with Desktop development with C++ for Windows builds.
- A physical device or emulator for camera and location features.

### Backend

- Node.js 22.5 or newer.
- npm.
- The model service dependencies described in `backend/ml-service`.

## Run the Flutter app

From the `GreenVision` directory:

```bash
flutter pub get
flutter run
```

For a UI-only demo that does not require a classification service:

```bash
flutter run -d windows --dart-define=CLASSIFIER_MODE=mock
```

The app also supports Windows, Android, and Chrome targets. Because local
SQLite is used by the application, Windows or Android is recommended for
complete functionality.

## Configuration

Configuration is supplied at build time with `--dart-define` or through the
in-app settings screen.

| Define | Default | Description |
| --- | --- | --- |
| `CLASSIFIER_MODE` | `api` | Classification mode: `api`, `gemini`, `hfInference`, or `mock` |
| `WASTE_API_BASE_URL` | `http://localhost:3000/api/v1` | Backend API base URL |
| `GEMINI_API_KEY` | Empty | Optional default key for the Gemini mode |

Example using the local backend:

```bash
flutter run \
  --dart-define=CLASSIFIER_MODE=api \
  --dart-define=WASTE_API_BASE_URL=http://localhost:3000/api/v1
```

For an Android emulator, replace `localhost` with `10.0.2.2`. For a physical
device, use the development machine's LAN address.

## Run the backend

From the `backend` directory:

```bash
npm install
Copy-Item .env.example .env
npm run db:migrate
npm run dev
```

Configure a strong `JWT_SECRET` in `.env`. The API listens on port `3000` by
default, and its health endpoint is available at `/health`.

The backend exposes authentication, collection, scan history, statistics, and
classification endpoints under `/api/v1`. The classification endpoint accepts
an image upload at `POST /api/v1/classify` and forwards it to the configured
model service.

## Testing and quality checks

From the `GreenVision` directory:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release
```

On Windows, the release script runs the project verification and APK build:

```powershell
.\tool\build_release.ps1
```

For backend syntax checks:

```bash
cd backend
npm run check
```

## Data and privacy

Scan history, user profile data, collection requests, and cropped images are
stored locally by the Flutter application unless a configured remote service
is used for classification. When remote classification is enabled, the cropped
image is uploaded only to obtain a prediction. Camera and location permissions
are requested when the related feature is used.

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
