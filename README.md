# Orbit - Couple Goals & Communication App

Orbit is a Flutter application designed to help couples track their goals, maintain streaks, and communicate effectively. The app features goal setting, progress tracking, and a messaging system to keep couples connected.

## Prerequisites

- Flutter SDK (version 3.19.0 or higher)
- Dart SDK (version 3.3.0 or higher)
- Android Studio / VS Code with Flutter extensions
- Firebase account
- Git

## Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/orbit.git
   cd orbit
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Enable Authentication (Email/Password)
   - Create a Firestore database
   - Download the Firebase configuration files:
     - For Android: `google-services.json` to `android/app/`
     - For iOS: `GoogleService-Info.plist` to `ios/Runner/`

4. **Configure Firebase**
   - Update the Firebase configuration in `lib/services/firebase_service.dart`
   - Ensure Firebase initialization is properly set up in `lib/main.dart`

5. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── models/           # Data models
│   ├── app_user.dart
│   ├── goal_model.dart
│   ├── message_model.dart
│   ├── partnership_model.dart
│   └── user_model.dart
├── screens/          # UI screens
│   ├── auth_screen.dart
│   ├── goals_screen.dart
│   ├── home_screen.dart
│   ├── main_layout.dart
│   └── messages_screen.dart
├── services/         # Business logic and services
│   ├── firebase_service.dart
│   └── storage_service.dart
└── main.dart         # App entry point
```

## Features

- **Authentication**
  - Email/Password login
  - User registration
  - Secure session management

- **Goals Management**
  - Create and track personal goals
  - Set daily goals
  - Track completion streaks
  - View goal history

- **Partnership Features**
  - Connect with partner
  - Share goals
  - Track combined progress
  - Maintain shared streaks

- **Messaging**
  - Real-time communication
  - Goal-related discussions
  - Progress updates

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  provider: ^6.1.1
  shared_preferences: ^2.2.2
  intl: ^0.19.0
```

## Development Setup

1. **IDE Setup**
   - Install Flutter and Dart plugins
   - Configure Flutter SDK path
   - Enable Flutter/Dart linting

2. **Code Style**
   - Follow Flutter style guide
   - Use proper indentation (2 spaces)
   - Follow naming conventions

3. **Testing**
   ```bash
   flutter test
   ```

## Building for Production

1. **Android**
   ```bash
   flutter build apk --release
   ```

2. **iOS**
   ```bash
   flutter build ios --release
   ```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, email support@orbitapp.com or create an issue in the repository.

## Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- All contributors who have helped shape this project
