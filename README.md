# Muzhir (مُزهِر)

### AI-Powered Plant Disease Detection System

**Faculty of Computing and Information Technology, King Abdulaziz University**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%26%20Auth-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![YOLO26N](https://img.shields.io/badge/Model-YOLO26N-EF2D5E)](https://docs.ultralytics.com)
[![Python](https://img.shields.io/badge/Python-3.12+-3776AB?logo=python&logoColor=white)](https://python.org)
[![Dart](https://img.shields.io/badge/Dart-3.6+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## Table of Contents

1. [About the Project](#1-about-the-project)
2. [System Architecture](#2-system-architecture)
3. [Features](#3-features)
4. [AI Model](#4-ai-model)
5. [Tech Stack](#5-tech-stack)
6. [Project Structure](#6-project-structure)
7. [Getting Started — Prerequisites](#7-getting-started--prerequisites)
8. [Getting Started — Installation](#8-getting-started--installation)
9. [User Manual — How to Use the App](#9-user-manual--how-to-use-the-app)
10. [Common Errors and Fixes](#10-common-errors-and-fixes)
11. [Environment Variables Reference](#11-environment-variables-reference)
12. [License](#12-license)
13. [Team](#13-team)

---

## 1. About the Project

Plant diseases are among the most destructive forces in global agriculture, causing crop losses estimated at 20 to 40 percent of total production each year. In Saudi Arabia, where the government has set ambitious food security and agricultural self-sufficiency targets under Vision 2030, the accurate and timely detection of plant diseases is a critical challenge. Traditional diagnosis relies heavily on the physical presence of trained agricultural experts, a resource that is scarce in remote farming regions and unavailable at the speed that disease progression demands.

Muzhir — an Arabic word meaning "blooming" or "flourishing" — is a cross-platform intelligent agricultural system built to address this gap. It delivers real-time AI-powered plant disease detection directly to a farmer's smartphone, requiring no prior technical expertise. By combining a state-of-the-art computer vision model with a large language model, Muzhir provides not only an instant diagnosis but also a complete, actionable treatment plan — all presented in both English and Arabic.

At its core, Muzhir uses a YOLO26N object detection model trained on the FieldPlant dataset to identify eight distinct disease classes across Corn and Tomato crops. The model operates in two modes simultaneously: an on-device inference path that runs locally on the smartphone for immediate, offline-capable results, and a cloud-assisted path that sends the image to a FastAPI backend for a richer diagnosis enriched by a Groq LLaMA large language model. The LLM generates bilingual treatment recommendations that are specific to the detected disease, the crop type, and the plant's growth stage.

Beyond diagnosis, Muzhir includes a geospatial disease mapping feature that plots every scan on an interactive OpenStreetMap, giving farmers and agronomists a live view of disease distribution across their fields or region. Scan history is persisted to Cloud Firestore, allowing users to track the progress of a disease over time. The system aligns directly with Saudi Vision 2030 goals for agricultural innovation, food security, and the adoption of digital technologies in traditional industries.

---

## 2. System Architecture

Muzhir is built on a three-tier architecture comprising a Flutter mobile client, a FastAPI cloud backend hosted on Render, and a Firebase data layer.

The Flutter mobile client handles image acquisition (camera or gallery), executes on-device inference using the `ultralytics_yolo` plugin, manages user authentication through Firebase Auth, stores and retrieves scan history from Cloud Firestore, and renders the geospatial disease map using `flutter_map` with OpenStreetMap tiles. State is managed reactively through Riverpod providers.

The FastAPI backend, deployed on Render via a `Procfile`, loads a YOLO26N ONNX model once at startup into `app.state` to avoid per-request re-loading. When the mobile client submits an image to the `/api/v1/diagnose` endpoint, the backend decodes the image with OpenCV, runs inference through ONNX Runtime, maps the detected class ID to a bilingual disease name, queries the Groq API to generate a treatment recommendation using LLaMA-3.1-8B-Instant, uploads the original image to Cloudinary, and persists the full diagnosis result to Cloud Firestore. All authenticated endpoints are protected by a Firebase JWT middleware that verifies the Bearer token on every request.

Muzhir implements a dual inference model for resilient operation. On-device inference uses TFLite FP16 and INT8 models on Android (via the GPU/NNAPI and CPU delegates respectively) and a CoreML `.mlpackage` on iOS, delivering immediate results without any network dependency. Cloud inference provides an enriched result including Groq-generated treatment text and Cloudinary image storage. When the device is offline, the scan is queued locally in `shared_preferences` by `PendingUploadStore` and automatically synchronised with the backend once connectivity is restored.

```mermaid
flowchart TD
    subgraph mobileClient [Mobile Client - Flutter]
        A[Image Picker\ncamera / gallery]
        B[On-Device Inference\nTFLite / CoreML]
        C[Offline Queue\nshared_preferences]
        D[ApiService - Dio\nFirebase Bearer token]
    end

    subgraph backendServer [Cloud Backend - FastAPI on Render]
        E[POST /api/v1/diagnose]
        F[ONNX Runtime\nYOLO26N inference]
        G[ClassMapper\nbilingual label]
        H[Groq API\nLLaMA-3.1-8B]
        I[Cloudinary\nimage upload]
    end

    subgraph firebaseLayer [Firebase]
        J[Firebase Auth\nJWT verification]
        K[Cloud Firestore\nscan + user data]
    end

    A --> B
    B --> D
    A --> C
    C -->|"connectivity restored"| D
    D -->|"Bearer token"| E
    E --> J
    J -->|"uid"| F
    F --> G
    G --> H
    H --> I
    I --> K
    K -->|"scan history / map markers"| D
```

---

## 3. Features

1. Real-time plant disease detection using an on-device YOLO26N model, delivering results in approximately 2 milliseconds per image with no network dependency.
2. Offline diagnosis with automatic cloud synchronisation: scans captured without an internet connection are queued locally and uploaded transparently when connectivity is restored.
3. Bilingual English and Arabic interface and results, including disease names, treatment recommendations, and all user-interface text, with runtime language switching.
4. Geospatial disease mapping with an interactive OpenStreetMap view showing colour-coded markers for every recorded scan, enabling regional disease monitoring.
5. Scan history management with confidence scores, timestamps, crop type metadata, and a delete action backed by soft-deletion in Firestore.
6. Groq-powered bilingual treatment recommendations generated by LLaMA-3.1-8B-Instant, tailored to the detected disease, crop type, and growth stage.
7. Image quality assessment integrated into the diagnosis workflow, prompting the user to retake the photo before submission if the captured image does not meet quality requirements.
8. User authentication via Firebase Auth with email and password registration, sign-in, and password reset.
9. Profile management with photo upload and removal, backed by Cloudinary for image storage and Firestore for profile data.

---

## 4. AI Model

The Muzhir AI model is a YOLO26N object detection network trained specifically for agricultural disease identification. Training was conducted on the FieldPlant dataset, curated and validated through Roboflow. The dataset contains 2,480 validated images distributed across eight disease classes covering two crop families — Corn and Tomato — with augmentation applied to improve generalisation across varying field lighting and leaf conditions.

Training ran for 145 epochs on Google Colab using an NVIDIA L4 GPU. On the held-out test set, the model achieved **91.0% precision** and **80.1% recall**, with a mean Average Precision at 50% IoU (mAP@50) of **77.2%**. Inference speed is **2.0 ms per image** on the test hardware. After training, the model was exported to three deployment formats: TFLite FP16 and INT8 for Android (GPU/NNAPI and CPU delegates), CoreML `.mlpackage` for iOS (Neural Engine), and ONNX for the cloud backend (CPU-optimised via ONNX Runtime).

### Disease Classes

| Class ID | English Name | Arabic Name |
|:---:|---|---|
| 0 | Corn Blight | لفحة الذرة |
| 1 | Corn Brown Spots | بقع الذرة البنية |
| 2 | Corn Streak | تخطط الذرة |
| 3 | Corn Stripe | توشح الذرة |
| 4 | Corn Yellowing | اصفرار الذرة |
| 5 | Tomato Brown Spots | بقع الطماطم البنية |
| 6 | Tomato Leaf Curling | تجعد أوراق الطماطم |
| 7 | Tomato Mildiou | البياض الزغبي |

---

## 5. Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| Mobile Client | Flutter 3 & Dart 3.6 | Cross-platform iOS and Android application |
| State Management | Riverpod 2.5 | Reactive, testable state across the app |
| Authentication | Firebase Auth 6.1 | Email/password sign-in and JWT token issuance |
| Database | Cloud Firestore 6.1 | Scan history, user profiles, and map marker persistence |
| AI Inference (On-Device) | `ultralytics_yolo` 0.3 with TFLite FP16/INT8 and CoreML | Offline-capable plant disease detection on Android and iOS |
| AI Inference (Cloud) | ONNX Runtime via Ultralytics | Server-side YOLO26N inference on the Render backend |
| Backend Framework | FastAPI 0.110 + Uvicorn | REST API, Firebase JWT middleware, lifespan model loading |
| LLM Recommendations | Groq LLaMA-3.1-8B-Instant | Bilingual agronomic treatment generation |
| Image Storage | Cloudinary | Scan and profile image upload, URL persistence |
| Maps | `flutter_map` 8.2 with OpenStreetMap | Interactive geospatial disease distribution map |
| CI/CD | GitHub Actions | Automated Flutter APK build on push to `master` |

---

## 6. Project Structure

```
Muzhir/
├── backend/                        # FastAPI application and ONNX inference engine
│   ├── main.py                     # Application entry point; all API routes
│   ├── assets/
│   │   └── best.onnx               # YOLO26N ONNX model weights
│   ├── config/
│   │   └── class_map.json          # Bilingual disease class map (server copy)
│   ├── core/                       # Cross-cutting services
│   │   ├── config.py               # Pydantic settings; reads .env
│   │   ├── firebase_config.py      # Firebase Admin SDK init and Firestore helpers
│   │   ├── cloudinary_uploader.py  # Image upload and deletion
│   │   ├── activity_logger.py      # Async Firestore activity logging
│   │   └── status_manager.py       # Scan status utilities
│   ├── inference/                  # AI inference pipeline
│   │   ├── model_loader.py         # YOLO lifespan loader into app.state
│   │   ├── runner.py               # ONNX inference execution
│   │   ├── preprocessor.py         # OpenCV image decoding
│   │   ├── class_mapper.py         # Class ID to bilingual label mapping
│   │   └── llm_caller.py           # Groq API treatment recommendation
│   ├── middleware/
│   │   └── auth.py                 # Firebase JWT Bearer token verification
│   ├── models/                     # Pydantic domain models
│   ├── schemas/
│   │   └── responses.py            # API response schemas
│   └── requirements.txt            # Python dependencies
│
├── mobile_app/                     # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart               # App bootstrap, Firebase init, AuthGate
│   │   ├── core/                   # API client, env config, utilities
│   │   ├── models/                 # Dart data models (scan, user, detection)
│   │   ├── providers/              # Riverpod state providers
│   │   ├── screens/farmer/         # All app screens (home, diagnose, map, etc.)
│   │   ├── services/               # Auth, inference, API, offline queue services
│   │   ├── widgets/                # Reusable UI components
│   │   ├── l10n/                   # Localisation strings (EN/AR .arb files)
│   │   └── theme/                  # App theme and typography
│   ├── assets/
│   │   ├── models/                 # TFLite, CoreML, and class_map.json
│   │   └── logos/                  # App logo assets
│   ├── android/                    # Android-specific configuration and native assets
│   ├── ios/                        # iOS-specific configuration and Xcode project
│   └── pubspec.yaml                # Flutter dependencies
│
├── functions/                      # Firebase Cloud Functions (Python 3.12)
│   ├── main.py                     # Cloud Functions entry point
│   └── requirements.txt
│
├── .github/workflows/
│   └── main.yml                    # GitHub Actions: Flutter APK build on master push
│
├── firebase.json                   # Firebase project configuration (Firestore + Functions)
├── firestore.rules                 # Firestore security rules
├── firestore.indexes.json          # Firestore composite index definitions
├── .firebaserc                     # Firebase project alias mapping
├── .env.example                    # Environment variable template
├── Procfile                        # Render deployment command for Uvicorn
└── requirements.txt                # Root requirements (delegates to backend/requirements.txt)
```

---

## 7. Getting Started — Prerequisites

Before setting up the project locally, ensure the following are installed and available:

1. **Flutter SDK** version 3.0 or above — [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
2. **Python** version 3.12 or above — [python.org/downloads](https://python.org/downloads)
3. **Firebase project** with Cloud Firestore and Firebase Authentication enabled — [console.firebase.google.com](https://console.firebase.google.com)
4. **Groq API key** — [console.groq.com](https://console.groq.com)
5. **Cloudinary account** with a configured cloud name — [cloudinary.com](https://cloudinary.com)
6. **Git** — [git-scm.com](https://git-scm.com)

---

## 8. Getting Started — Installation

### Backend Setup

1. Clone the repository:

```bash
git clone https://github.com/your-org/muzhir.git
cd muzhir
```

2. Navigate to the backend directory:

```bash
cd backend
```

3. Create a Python virtual environment:

```bash
python -m venv .venv
```

4. Activate the virtual environment:

```bash
# On Windows
.venv\Scripts\activate

# On macOS / Linux
source .venv/bin/activate
```

5. Install dependencies:

```bash
pip install -r requirements.txt
```

6. Create a `.env` file in the project root (next to `Procfile`) and add the required environment variables:

```bash
GROQ_API_KEY=your_groq_api_key_here
CLOUDINARY_URL=cloudinary://api_key:api_secret@cloud_name
FIREBASE_CREDENTIALS_JSON={"type":"service_account","project_id":"..."}
DEFAULT_YOLO_WEIGHTS_PATH=backend/assets/best.onnx
```

7. Start the development server from the project root:

```bash
uvicorn backend.main:app --reload
```

The API will be available at `http://127.0.0.1:8000`. Interactive documentation is available at `/docs` when `SHOW_DOCS=true` is set.

---

### Mobile App Setup

1. Navigate to the mobile app directory:

```bash
cd mobile_app
```

2. Install Flutter dependencies:

```bash
flutter pub get
```

3. Create a `.env` file in the `mobile_app` directory and add the backend base URL:

```bash
API_BASE_URL=http://127.0.0.1:8000/api/v1
```

> For a device on the same local network, replace `127.0.0.1` with your machine's local IP address. When connecting to the deployed Render backend, use the full HTTPS URL.

4. Connect a physical device or start an emulator.

5. Run the application:

```bash
flutter run
```

> **Note:** `firebase_options.dart` and `google-services.json` are not committed to the repository (they contain project credentials). You must generate them from your own Firebase project using the FlutterFire CLI (`flutterfire configure`) and place them in `mobile_app/lib/` and `mobile_app/android/app/` respectively before the app will build.

---

## 9. User Manual — How to Use the App

This section is written for farmers and non-technical users.

### How to Register and Log In

1. Open the Muzhir app on your phone.
2. On the welcome screen, tap **Sign Up** if you are a new user.
3. Enter your full name, email address, and a password of your choice.
4. Tap **Create Account**. The app will create your account and take you to the home screen.
5. The next time you open the app, enter your email and password and tap **Log In**.
6. If you forget your password, tap **Forgot Password**, enter your email address, and check your email for a reset link.

---

### How to Diagnose a Plant

1. From the home screen, tap the **Diagnose** button at the bottom of the screen.
2. You will be asked to choose a photo source. Tap **Camera** to take a new photo of the plant, or tap **Gallery** to choose an existing photo from your phone.
3. Take a clear, close-up photo of the affected leaf. Make sure the leaf fills most of the frame and the lighting is good.
4. If you know the crop type (for example, Corn or Tomato) or the growth stage of the plant, select them from the dropdown menus. This helps the system give more accurate treatment advice.
5. Tap **Analyze Plant**.
6. The app will immediately show you a result on your screen. The result includes:
   - The name of the detected disease in English and Arabic.
   - A confidence score showing how certain the system is.
   - A treatment recommendation explaining what steps to take.
7. If you are connected to the internet, the result will also be saved to your account history.

---

### How to Use the Disease Map

1. Tap the **Map** icon at the bottom of the screen.
2. The map will open and show markers at the locations where diagnoses have been recorded.
3. Each marker is colour-coded: red markers indicate a disease was detected, and green markers indicate a healthy plant.
4. Tap any marker on the map to see the full details: disease name, crop type, health status, and the date and time of the scan.
5. Use two fingers to zoom in or out on the map.

---

### How to View Scan History

1. Tap the **History** icon at the bottom of the screen.
2. Your past diagnoses will be listed from newest to oldest. Each entry shows the disease name, confidence level, and date.
3. You can search or scroll through your history to find a specific scan.
4. Tap any scan in the list to see its full details, including the original photo and the complete treatment recommendation.
5. To delete a scan, swipe the entry or use the delete button shown in the detail view.

---

### How to Use the App Offline

You do not need an internet connection to diagnose a plant. The Muzhir app will run the disease detection directly on your phone, even without Wi-Fi or mobile data. When you are offline:

1. Open the app and go to the **Diagnose** screen as normal.
2. Take or choose a photo and tap **Analyze Plant**.
3. The app will show you the diagnosis result immediately using the on-device AI model.
4. The scan will be saved on your phone. You will see a small icon indicating it is waiting to be uploaded.
5. As soon as your phone connects to the internet again, the app will automatically upload the scan to your account in the background. You do not need to do anything.

---

### How to Change Language

1. Tap the **Profile** icon at the bottom of the screen.
2. Find the language option in your profile settings.
3. Tap **English** to switch to English, or tap **العربية** to switch to Arabic.
4. The entire app will switch to the selected language immediately without restarting.

---

## 10. Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| App shows "No internet connection" but you are connected | The app's network check may not have refreshed after a connectivity change. | Turn Wi-Fi or mobile data off and back on, then restart the app. |
| Diagnosis takes a very long time (30+ seconds) | The cloud backend is hosted on Render's free tier, which puts the server to sleep after a period of inactivity. The first request wakes it up. | Wait up to 30 seconds for the server to wake up. Subsequent requests will be faster. |
| Image is rejected as low quality | The photo was too blurry, too dark, or the leaf was too far from the camera. | Retake the photo in good natural lighting and ensure the plant leaf fills most of the camera frame. |
| Login fails with "Invalid credentials" | The email or password entered does not match the registered account. | Double-check your email and password. Use the **Forgot Password** link on the login screen to reset your password via email. |
| Map shows no markers | No diagnoses have been saved with a location yet, or location permission was not granted. | Complete at least one diagnosis and make sure you have granted the app permission to access your location. Check your phone's location settings if the problem persists. |

---

## 11. Environment Variables Reference

### Backend (`.env` in project root)

| Variable Name | Where It Is Used | Description |
|---|---|---|
| `GROQ_API_KEY` | `backend/inference/llm_caller.py` | API key for authenticating requests to the Groq LLaMA service. |
| `CLOUDINARY_URL` | `backend/core/cloudinary_uploader.py` | Full Cloudinary connection URL in the format `cloudinary://api_key:api_secret@cloud_name`. |
| `FIREBASE_CREDENTIALS_JSON` | `backend/core/firebase_config.py` | Firebase service account credentials as a raw JSON string. Used to initialise the Firebase Admin SDK. |
| `DEFAULT_YOLO_WEIGHTS_PATH` | `backend/core/config.py` | File path to the YOLO26N ONNX model weights. Defaults to `backend/assets/best.onnx`. |
| `MIN_CONFIDENCE_THRESHOLD` | `backend/inference/runner.py` | Minimum detection confidence required to report a result. Defaults to `0.25`. Optional. |
| `APP_VERSION` | `backend/main.py` | Version string shown in the API docs and health endpoint. Optional. |
| `SHOW_DOCS` | `backend/main.py` | Set to `true` to enable the `/docs` and `/redoc` Swagger/ReDoc endpoints. Defaults to `false`. Optional. |

### Mobile App (`.env` in `mobile_app/`)

| Variable Name | Where It Is Used | Description |
|---|---|---|
| `API_BASE_URL` | `mobile_app/lib/core/config/env_config.dart` | Base URL for the FastAPI backend, e.g. `https://your-app.onrender.com/api/v1`. |

---

## 12. License

This project is licensed under the [MIT License](LICENSE).

---

## 13. Team

| Name | 
|---|
| Yazeed Saad AlOmari | 
| Bader Mujib Alzahrani | 
| Thamer Abdulghani Alruqi | 
| **Supervised by** Dr. Emad Albasam | 

---

*Graduation Project · CPCS499 · Faculty of Computing and Information Technology · King Abdulaziz University · 2026*
