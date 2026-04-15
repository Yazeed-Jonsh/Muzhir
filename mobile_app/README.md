# muzhir

Flutter client for Muzhir.

## Backend URL for Profile Image APIs

Profile image upload/delete now call backend endpoints:

- `POST /api/v1/profile-photo`
- `DELETE /api/v1/profile-photo`

Set backend URL at build/run time:

```bash
flutter run --dart-define=MUZHIR_BACKEND_URL=http://10.0.2.2:8000
```

If omitted, the app defaults to `http://10.0.2.2:8000`.

## Cloudinary Environment Variables (Backend)

Copy `.env.example` to `.env` in the repository root and fill:

- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

Optional (recommendation service):

- `GROQ_API_KEY`
