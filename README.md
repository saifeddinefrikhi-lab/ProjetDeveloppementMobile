# Waste Classification ♻️

An intelligent, cross-platform Flutter application powered by multi-provider computer vision and machine learning models to detect, classify, and properly sort waste items. Built with Flutter, Riverpod, SQLite, and OpenStreetMap, the app combines camera-based real-time waste analysis with interactive community recycling collection logistics.

---

## 📌 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
  - [1. Multi-Provider AI Waste Classification](#1-multi-provider-ai-waste-classification)
  - [2. Precision Camera Scanning & Image Cropping](#2-precision-camera-scanning--image-cropping)
  - [3. Interactive Recycling & Collection Map](#3-interactive-recycling--collection-map)
  - [4. Waste Collection Requests & Logistics](#4-waste-collection-requests--logistics)
  - [5. Scan History & Environmental Analytics](#5-scan-history--environmental-analytics)
  - [6. User Authentication & Profile Management](#6-user-authentication--profile-management)
  - [7. Internationalization (i18n) & RTL Support](#7-internationalization-i18n--rtl-support)
- [Classification Pipeline & Model Architecture](#classification-pipeline--model-architecture)
  - [Supported AI Providers](#supported-ai-providers)
  - [Model Labels & Category Mapping](#model-labels--category-mapping)
- [System Architecture](#system-architecture)
- [Project Directory Structure](#project-directory-structure)
- [Getting Started & Installation](#getting-started--installation)
  - [Prerequisites](#prerequisites)
  - [Installation Steps](#installation-steps)
  - [Configuration Flags (`--dart-define`)](#configuration-flags---dart-define)
  - [Running on Supported Platforms](#running-on-supported-platforms)
- [Local Database Schema](#local-database-schema)
- [Testing & Quality Verification](#testing--quality-verification)
- [Data Privacy & Security](#data-privacy--security)
- [License](#license)

---

## 📖 Overview

Improper waste disposal and lack of accessible sorting guidance contribute heavily to environmental pollution and low recycling rates. **Waste Classification** bridges this gap by turning smartphones and computers into automated waste-sorting assistants.

By scanning an item through the camera or picking an image from the gallery, users instantly receive:
1. The detected **waste label** (e.g., Plastic, Cardboard, Food Organics).
2. The AI model's **confidence score**.
3. The broad **disposal category** (Recyclable, Organic, or General Waste).
4. Concrete, actionable **sorting and disposal instructions**.
5. The ability to request a **pickup** or find nearby **drop-off / collection points** on an interactive map.

---

## 🚀 Key Features

### 1. Multi-Provider AI Waste Classification
The application features a flexible, pluggable classifier architecture supporting five distinct execution modes:
- **Groq Vision API (Default)**: Ultra-fast vision inference using modern LLM vision models (e.g., Qwen 2.5 / 3.8B Vision).
- **Google Gemini API**: Multimodal inference with Google's Gemini models.
- **Hugging Face Inference API**: Direct access to hosted vision models on the Hugging Face Hub.
- **Custom FastAPI Backend**: Microservice hosting an optimized EfficientNet-B0 model exported to ONNX format.
- **Mock Classifier**: Instant, offline mock responses for UI development, testing, and CI/CD pipelines without internet connectivity.

Users can easily input and update their own API keys directly through the in-app **Settings** screen.

### 2. Precision Camera Scanning & Image Cropping
- **Target Guide Overlay**: An on-screen framing overlay guides the user to center the object.
- **Exact Crop Processing**: The app extracts and transmits *only* the bounding region visible within the reticle. This eliminates background distractions and drastically improves classification accuracy.
- **Gallery Upload**: Supports selecting and cropping existing photos from the device photo library.

### 3. Interactive Recycling & Collection Map
- **OpenStreetMap Integration**: Powered by `flutter_map` and OpenStreetMap tile layers, requiring no costly third-party map keys.
- **Live Geolocation**: Automatically centers on the user's current GPS position via `geolocator`.
- **Reverse Geocoding**: Automatically converts coordinates into human-readable street addresses.
- **Status & Type Filtering**: Filter map pins by request status (*Pending*, *Accepted*, *Completed*, *Cancelled*) or waste type (*Plastic*, *Glass*, *Paper*, *Batteries*, *Metal*, *Electronics*).

### 4. Waste Collection Requests & Logistics
- **Request Creation**: Users can schedule waste pickup requests by specifying waste types, pickup date, address (auto-filled via GPS or typed manually), and descriptive notes.
- **Community Acceptance**: Other certified collectors or community members can review open collection requests, view pickup locations on the map, and mark requests as accepted or completed.
- **My Requests Management**: Dedicated screen tracking status lifecycles of all placed and accepted requests.

### 5. Scan History & Environmental Analytics
- **Local Persistence**: Every completed scan is stored in a private SQLite database alongside its cropped image, timestamp, label, and confidence score.
- **Time-Frame Aggregation**: Interactive statistical charts break down historical waste distribution across daily, weekly, and monthly intervals.

### 6. User Authentication & Profile Management
- **Local SQLite Authentication**: Full user signup and login system stored securely in local database tables.
- **Password Security**: Passwords are protected using cryptographic SHA-256 hashing with salt before storage.
- **Session Management**: Persistent user authentication state handled with `SharedPreferences`.
- **Profile Dashboard**: Displays personal recycling metrics, total scans recorded, active collection requests, and account preferences.

### 7. Internationalization (i18n) & RTL Support
Powered by `easy_localization` with three fully supported languages:
- **English (`en`)**
- **French (`fr`)**
- **Arabic (`ar`)** (Full Right-to-Left / RTL layout support)

Language preferences persist across sessions and can be changed on the fly in the Settings screen.

---

## 🧠 Classification Pipeline & Model Architecture

```text
┌─────────────────┐       ┌──────────────────────┐       ┌─────────────────────┐
│  Camera Frame   │ ----> │ Exact Box Crop       │ ----> │ Active Classifier   │
│  or Photo Pick  │       │ (224x224 RGB / JPEG) │       │ (Groq / Gemini / HF)│
└─────────────────┘       └──────────────────────┘       └──────────┬──────────┘
                                                                    │
                                                                    ▼
┌──────────────────┐      ┌──────────────────────┐       ┌─────────────────────┐
│ SQLite Database  │ <─── │ Actionable Sorting   │ <──── │ Model Label Mapper  │
│  & Stats Engine  │      │ Advice Display       │       │ (9 labels -> 3 grp) │
└──────────────────┘      └──────────────────────┘       └─────────────────────┘
```

### Supported AI Providers

| Provider | Classifier Mode | Endpoint / Model | Configuration Key |
| :--- | :--- | :--- | :--- |
| **Groq** | `groq` | `qwen/qwen3.8-27b` (OpenAI-compatible Vision) | In-app Settings or `GROQ_API_KEY` |
| **Gemini** | `gemini` | `gemini-1.5-flash` / Multimodal Vision | In-app Settings or `GEMINI_API_KEY` |
| **Hugging Face** | `hfInference` | Hugging Face Serverless Inference API | `HF_TOKEN` / App Settings |
| **FastAPI / ONNX** | `api` | EfficientNet-B0 ONNX (`POST /predict`) | `WASTE_API_BASE_URL` |
| **Mock Engine** | `mock` | Local determinism / instant response | No credentials needed |

### Model Labels & Category Mapping

The core model classifies inputs into **9 specific labels**, which the application maps into **3 actionable waste management categories**:

| Model Label | Target Category | Color Code | Actionable Guidance |
| :--- | :--- | :--- | :--- |
| `Food Organics` | **Organic** | `#A9D8B4` | Compost or place in organic bin; discard plastic packaging. |
| `Vegetation` | **Organic** | `#A9D8B4` | Suitable for garden composting or green waste bins. |
| `Cardboard` | **Recyclable** | `#F2DDA4` | Flatten boxes, ensure dry and clean of food grease. |
| `Paper` | **Recyclable** | `#F2DDA4` | Keep dry, remove binding adhesives, place in paper bin. |
| `Plastic` | **Recyclable** | `#F2DDA4` | Empty liquids, rinse clean, squash bottles, recap. |
| `Glass` | **Recyclable** | `#F2DDA4` | Rinse clean, discard caps separately, avoid broken shards. |
| `Metal` | **Recyclable** | `#F2DDA4` | Rinse food cans and aluminum containers thoroughly. |
| `Textile Trash` | **Other / Special** | `#D6D9D5` | Donate if wearable; deposit at dedicated textile recycling stations. |
| `Miscellaneous Trash` | **Other / General** | `#D6D9D5` | Dispose in general household waste bin; hazardous items to specialized facilities. |

---

## 🏗️ System Architecture

The project adheres to Clean Architecture and Feature-First folder organization:

- **Core Layer**: Application-wide themes, color tokens (`AppColors`), design system primitives, and configuration constants (`AppConfig`).
- **Data Layer**:
  - `models/`: Immutable data objects (`ScanResult`, `WasteCategory`, `CollectionRequest`, `UserModel`).
  - `local/`: Local database provider (`DatabaseProvider`), repositories (`ScanRepository`, `UserRepository`, `CollectionRequestRepository`), and file system image storage (`LocalImageStore`).
  - `seed/`: Initial category definitions and localized descriptions.
- **Features Layer**: Self-contained feature modules:
  - `auth/`: Authentication flow (Login, Register, Session Provider, Auth Guards).
  - `scan/`: Live camera preview, targeting guide, image cropping engine.
  - `result/`: Classification outcome presentation, disposal advice, saving pipeline.
  - `collection/`: OpenStreetMap view, geolocation, collection request creation, and status management.
  - `history/`: Scan history timeline, item details view, and aggregate statistics charts.
  - `profile/`: User profile, credentials, and environmental impact summary.
  - `settings/`: Language switching, AI provider selection, and API key management.
- **Services Layer**: Abstractions and implementations for external integrations:
  - `classifier/`: Riverpod-managed classifier providers (`Groq`, `Gemini`, `HfInference`, `Api`, `Mock`).
  - `geocoding/`: Reverse geocoding service converting coordinates to street addresses.
  - `permission/`: Android and desktop runtime permission handler.

---

## 📁 Project Directory Structure

```text
lib/
├── app.dart                                # Root MaterialApp widget & theme configuration
├── main.dart                               # App entry point, FFI initialization, easy_localization setup
├── core/
│   ├── config/                             # AppConfig and environment variable bindings
│   ├── theme/                              # Color palettes, typography, and Material 3 theme
│   └── widgets/                            # Reusable UI components and category iconography
├── data/
│   ├── local/                              # SQLite database helper, SharedPreferences, image store
│   ├── models/                             # Domain models (Scan, User, Request, Category)
│   └── seed/                               # Static seed data and localized category instructions
├── features/
│   ├── auth/                               # Login, register, auth provider, session guards
│   ├── collection/                         # Interactive map, request forms, request status tracking
│   ├── history/                            # Scan records, detail view, daily/weekly/monthly stats
│   ├── home/                               # Dashboard, quick actions, category encyclopedia
│   ├── navigation/                         # Bottom navigation bar and app shell layout
│   ├── profile/                            # User profile details and activity counters
│   ├── result/                             # Classification results, confidence cards, disposal steps
│   ├── scan/                               # Camera preview, bounding box guides, photo picker
│   └── settings/                           # API keys, model configuration, language picker
└── services/
    ├── classifier/                         # Groq, Gemini, HF, FastAPI, and Mock services
    ├── geocoding/                          # Geocoding and reverse geocoding integrations
    ├── image/                              # Image file manipulation and cropping helpers
    └── permission/                         # Camera and location runtime permission helpers

assets/
├── fonts/                                  # Bundled typography (Be Vietnam Pro)
└── translations/                           # Localization dictionaries (ar.json, en.json, fr.json)

huggingface-space/                          # FastAPI microservice with ONNX model & Dockerfile
tool/                                       # PowerShell automated verification and release scripts
```

---

## 🛠️ Getting Started & Installation

### Prerequisites

Ensure the following tools are installed on your machine:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.12.0` or higher)
- [Dart SDK](https://dart.dev/get-dart) (`^3.12.2` or higher)
- [Android Studio](https://developer.android.com/studio) with Android SDK (API level 24 / Android 7.0+ minimum)
- Visual Studio with "Desktop development with C++" workload (if targeting Windows Desktop)
- Git

### Installation Steps

1. **Clone the repository**:
   ```bash
   git clone https://github.com/saifeddinefrikhi-lab/ProjetDeveloppementMobile.git
   cd ProjetDeveloppementMobile
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify Flutter setup**:
   ```bash
   flutter doctor
   ```

### Configuration Flags (`--dart-define`)

The app supports custom build-time flags to configure endpoints and API keys without modifying source code:

| Define Flag | Allowed Values | Default | Description |
| :--- | :--- | :--- | :--- |
| `CLASSIFIER_MODE` | `groq`, `gemini`, `hfInference`, `api`, `mock` | `groq` | Active classification engine |
| `GROQ_API_KEY` | *string* | `""` | Default Groq Vision API key |
| `GEMINI_API_KEY` | *string* | `""` | Default Google Gemini API key |
| `WASTE_API_BASE_URL` | *URL string* | `""` | Custom FastAPI server base URL |

> **Note:** API keys can also be entered or updated directly within the application's **Settings** screen at runtime.

### Running on Supported Platforms

#### Run on Android Device or Emulator
```bash
flutter run
```

#### Run with Groq Vision Engine
```bash
flutter run \
  --dart-define=CLASSIFIER_MODE=groq \
  --dart-define=GROQ_API_KEY=gsk_your_groq_api_key_here
```

#### Run with Gemini Engine
```bash
flutter run \
  --dart-define=CLASSIFIER_MODE=gemini \
  --dart-define=GEMINI_API_KEY=AIzaSy_your_gemini_key_here
```

#### Run in Mock Mode (Offline UI Demo / Testing)
```bash
flutter run --dart-define=CLASSIFIER_MODE=mock
```

#### Run on Windows Desktop
The project includes `sqflite_common_ffi` and `camera_windows` support for desktop execution:
```bash
flutter run -d windows --dart-define=CLASSIFIER_MODE=mock
```

#### Run on Chrome (Web)
```bash
flutter run -d chrome --dart-define=CLASSIFIER_MODE=mock
```

---

## 🗄️ Local Database Schema

The app uses a local SQLite database (`waste_classification.db`) managed via `DatabaseProvider`:

### 1. `scan_results` Table
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `TEXT PRIMARY KEY` | Unique scan UUID |
| `image_path` | `TEXT NOT NULL` | Absolute local path to saved cropped image |
| `scanned_at` | `TEXT NOT NULL` | ISO-8601 formatted timestamp |
| `category_id` | `TEXT NOT NULL` | Mapped category ID (`organic`, `recyclable`, `other`) |
| `model_label` | `TEXT NOT NULL` | Exact label predicted by the AI model |
| `confidence` | `REAL NOT NULL` | Prediction probability score (0.0 to 1.0) |
| `user_id` | `INTEGER` | Optional foreign key linking scan to authenticated user |

### 2. `users` Table
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `INTEGER PRIMARY KEY AUTOINCREMENT` | Unique user ID |
| `email` | `TEXT UNIQUE NOT NULL` | User email address |
| `password_hash` | `TEXT NOT NULL` | Cryptographic SHA-256 hash |
| `name` | `TEXT NOT NULL` | Full user display name |
| `phone` | `TEXT` | Optional contact telephone number |
| `created_at` | `TEXT NOT NULL` | Account registration timestamp |

### 3. `collection_requests` Table
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `TEXT PRIMARY KEY` | Unique request UUID |
| `creator_id` | `INTEGER` | ID of user who created the request |
| `creator_name` | `TEXT` | Name of user who created the request |
| `waste_types` | `TEXT NOT NULL` | Comma-separated list of selected waste categories |
| `pickup_date` | `TEXT NOT NULL` | Requested collection date (ISO-8601) |
| `address` | `TEXT NOT NULL` | Pickup street address |
| `latitude` | `REAL` | GPS latitude coordinate for map plotting |
| `longitude` | `REAL` | GPS longitude coordinate for map plotting |
| `notes` | `TEXT` | Additional instructions from requestor |
| `status` | `TEXT NOT NULL` | `pending`, `accepted`, `completed`, `cancelled` |
| `accepted_by_user_id` | `INTEGER` | ID of collector who accepted the pickup |
| `created_at` | `TEXT NOT NULL` | Submission timestamp |

---

## 🧪 Testing & Quality Verification

Run standard code formatting, static analysis, and unit test suites:

```bash
# Verify formatting
dart format --output=none --set-exit-if-changed lib test

# Run static analyzer
flutter analyze

# Execute automated tests
flutter test

# Build production release APK
flutter build apk --release
```

### Windows Automated Release Script
For automated end-to-end cleaning, linting, translation validation, and APK compilation on Windows:
```powershell
.\tool\build_release.ps1
```

---

## 🔒 Data Privacy & Security

- **Local Storage Priority**: All scan photos, historical records, user accounts, and collection requests reside locally on the user's device in SQLite and private storage directories.
- **Encrypted Credentials**: Passwords stored locally are secured using salted SHA-256 hashing.
- **Inference Ephemerality**: In cloud AI modes (Groq, Gemini, Hugging Face, or Custom API), cropped images are transmitted strictly for classification inference over HTTPS and are never retained as cloud-hosted assets.
- **Device Permission Transparency**: Camera and GPS permissions are requested on-demand only when initiating a scan or centering the recycling map.

---

## 📄 License

This project is licensed under the [GNU General Public License v3.0 (GPL-3.0)](LICENSE).
