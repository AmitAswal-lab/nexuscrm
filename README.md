# Nexus CRM

Nexus CRM is a mobile customer relationship management application built with
Flutter for Android and iOS. It is designed to give administrators and sales
representatives a focused workflow for managing leads, clients, tasks, and
follow-ups.

## Project status

The project is currently in its foundation phase. The Flutter application
shell, shared Material 3 themes, lint rules, and an initial widget smoke test
are in place.

## MVP scope

- Authentication with role-based routing
- Sales representative management for administrators
- Sales representative dashboard
- Lead and client management
- Tasks and follow-ups
- Native phone dialer launch
- Manual post-call follow-up notes
- Basic administrator activity view

Advanced calendar features, push notifications, document management,
WhatsApp and email integrations, and detailed reporting are planned for later
iterations.

## Requirements

- Flutter SDK with Dart `^3.12.0`
- Android Studio and an Android SDK for Android development
- Xcode and CocoaPods for iOS development

Confirm the local toolchain before running the project:

```sh
flutter doctor
```

## Getting started

Install dependencies:

```sh
flutter pub get
```

Run the application on a connected device or simulator:

```sh
flutter run
```

## Quality checks

Run static analysis:

```sh
flutter analyze
```

Run the test suite:

```sh
flutter test
```

## Branching strategy

- `main` contains stable, release-ready work.
- `dev` is the integration branch for completed features.
- `feature/*` branches are created from `dev` for focused changes.

## Project structure

```text
lib/
├── app/
│   ├── app.dart
│   └── theme/
│       └── app_theme.dart
└── main.dart
test/
└── app_test.dart
```

Application identifier: `com.amitaswal.nexuscrm`
