# Environment Variables Setup

This project uses environment variables to securely store sensitive API keys and configuration.

## Setup Instructions

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Fill in your Firebase credentials** in the `.env` file:
   - Get these from your Firebase Console: https://console.firebase.google.com/
   - Project Settings → General → Your apps → Web app

3. **Never commit the `.env` file:**
   - The `.env` file is already in `.gitignore`
   - Only commit `.env.example` as a template

## Environment Variables

The following environment variables are required:

- `FIREBASE_API_KEY` - Your Firebase Web API Key
- `FIREBASE_APP_ID` - Your Firebase App ID
- `FIREBASE_MESSAGING_SENDER_ID` - Firebase Cloud Messaging Sender ID
- `FIREBASE_PROJECT_ID` - Your Firebase Project ID
- `FIREBASE_AUTH_DOMAIN` - Firebase Authentication Domain
- `FIREBASE_STORAGE_BUCKET` - Firebase Storage Bucket URL

## Security Notes

⚠️ **IMPORTANT:**
- Never commit the `.env` file to version control
- Never share your API keys publicly
- If you accidentally expose your keys, regenerate them immediately in Firebase Console
- The `.env.example` file should only contain placeholder values

## Troubleshooting

If you get errors about missing environment variables:
1. Make sure the `.env` file exists in the project root
2. Verify all required variables are set in `.env`
3. Run `flutter pub get` to ensure dependencies are installed
4. Restart your app (hot reload won't reload environment variables)
