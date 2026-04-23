# muzhir

Flutter client for Muzhir.

## Backend URL for Profile Image APIs

Profile image upload/delete now call backend endpoints:

- `POST /api/v1/profile-photo`
- `DELETE /api/v1/profile-photo`

Set backend URL at build/run time (overrides platform defaults and `.env`):

```bash
# Android emulator (optional; this is already the default)
flutter run --dart-define=MUZHIR_BACKEND_URL=http://10.0.2.2:8000

# iOS Simulator (optional; default is http://127.0.0.1:8000)
flutter run --dart-define=MUZHIR_BACKEND_URL=http://127.0.0.1:8000
```

If omitted, the app picks a default from the platform: **Android** uses `http://10.0.2.2:8000`; **iOS** uses `http://127.0.0.1:8000` (simulator → Mac). On a **physical iPhone**, set `MUZHIR_BACKEND_URL` in `.env` to your Mac’s LAN IP (e.g. `http://192.168.1.10:8000`).

## Cloudinary Environment Variables (Backend)

Copy `.env.example` to `.env` in the repository root and fill:

- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

Optional (recommendation service):

- `GROQ_API_KEY`
