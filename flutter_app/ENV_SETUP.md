# Environment setup

1. Copy the example file:
   ```bash
   cp .env.example .env
   ```

2. Fill in your **Firebase** values in `.env` (required for web):
   - [Firebase Console](https://console.firebase.google.com) → your project → **Project settings** → **General** → Your apps → **Web app**.

3. **Optional – Unsplash:** To use Unsplash images on swipe cards, add `UNSPLASH_ACCESS_KEY` from [Unsplash for Developers](https://unsplash.com/developers). If you leave it empty, the app uses a fallback image service.

4. Do **not** commit `.env` (it’s in `.gitignore`).

## Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `FIREBASE_API_KEY` | Yes (web) | Firebase Web API key |
| `FIREBASE_APP_ID` | Yes (web) | Firebase Web App ID |
| `FIREBASE_MESSAGING_SENDER_ID` | Yes (web) | Cloud Messaging sender ID |
| `FIREBASE_PROJECT_ID` | Yes (web) | Firebase project ID |
| `FIREBASE_AUTH_DOMAIN` | Yes (web) | Auth domain |
| `FIREBASE_STORAGE_BUCKET` | Yes (web) | Storage bucket URL |
| `UNSPLASH_ACCESS_KEY` | No | Unsplash API key; omit to use fallback images |

## Firestore rules

Deploy `firestore.rules` so partner codes and preferences work: Firebase Console → Firestore → Rules, or `firebase deploy --only firestore:rules` if using Firebase CLI.
