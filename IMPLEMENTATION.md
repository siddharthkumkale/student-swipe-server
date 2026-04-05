# Student Swipe - Implementation Guide

## Overview

Student Swipe is a Flutter Android app that lets students connect through skill-based swiping (Tinder-style). It uses Firebase for Auth, Firestore, and Storage.

## Folder Structure

```
lib/
├── main.dart                 # App entry, Firebase init
├── firebase_options.dart     # Generated Firebase config
├── models/
│   └── user_profile.dart     # User profile data model
├── screens/
│   ├── app_start.dart       # Flow: Splash → Onboarding → Auth
│   ├── splash_screen.dart
│   ├── onboarding_screen.dart
│   ├── profile_setup_screen.dart
│   ├── swipe_screen.dart
│   └── auth/
│       ├── auth_gate.dart   # Auth + profile routing
│       ├── login_screen.dart
│       └── signup_screen.dart
├── services/
│   ├── auth_service.dart    # Firebase Auth
│   └── profile_service.dart # Firestore profiles + swipes
├── utils/
│   └── app_theme.dart
└── widgets/
    └── auth_text_field.dart
```

## Flow

1. **Splash** → User taps "Get Started"
2. **Onboarding** → 3 pages, skip or "Get Started"
3. **AuthGate** → If not logged in → Login; if no profile → Profile Setup; else → Swipe
4. **Profile Setup** → Saves name, university, course, year, bio, skills to Firestore
5. **Swipe** → Tinder-style cards, swipe left (pass) / right (like), match when mutual like

## Firestore Structure

### `users/{uid}`
- `uid`, `name`, `email`, `university`, `course`, `year`, `bio`, `skills` (array), `photoUrl?`, `createdAt`

### `users/{uid}/swipes/{targetUid}`
- `action`: `"like"` | `"pass"`
- `timestamp`

## Setup Steps

1. **Firebase**
   - Create a project at [Firebase Console](https://console.firebase.google.com)
   - Enable Auth (Email/Password, Google)
   - Create Firestore database
   - Add Android app, download `google-services.json` to `android/app/`
   - Run `flutterfire configure` to regenerate `firebase_options.dart`

2. **Assets**
   - Add `assets/images/logo.png` for the splash screen (or it will show a placeholder icon)

3. **Run**
   ```bash
   flutter pub get
   flutter run
   ```

## Key Features

- **Auth**: Email/password, Google sign-in, email verification
- **Profile**: Name, university, course, year, bio, skills (chips)
- **Swipe**: Card stack, left = pass, right = like, match notification
- **Match**: Mutual like triggers "It's a match!" snackbar
