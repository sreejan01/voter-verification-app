# Voter Verification App

[![Flutter](https://img.shields.io/badge/Flutter-3.11+-blue.svg?style=flat-square)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11.1+-00B4AB.svg?style=flat-square)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

A robust Flutter-based mobile application designed to streamline and secure voter verification processes using advanced machine learning and computer vision technologies.

## 📋 Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [Support](#support)

## ✨ Features

- **OCR Text Recognition**: Utilizes Google ML Kit for accurate optical character recognition from identity documents
- **Camera Integration**: Real-time camera access for document scanning and image capture
- **Image Processing**: Advanced image selection and manipulation capabilities
- **Cross-Platform Support**: Native support for iOS, Android, and web platforms
- **Material Design**: Professional UI built with Flutter's Material Design framework
- **Network Integration**: HTTP-based API communication for backend services

## 🛠️ Tech Stack

| Technology | Purpose | Version |
|---|---|---|
| **Dart** | Primary language | ^3.11.1 |
| **Flutter** | Cross-platform UI framework | Latest |
| **Google ML Kit** | Text recognition & ML capabilities | 0.14.0 |
| **Camera Plugin** | Device camera access | ^0.10.5+9 |
| **Image Picker** | Image selection from gallery/camera | ^1.0.7 |
| **HTTP** | Network requests | ^1.2.0 |

### Language Composition

- **Dart**: 51.9% - Core application logic
- **HTML**: 35.2% - Web assets and templates
- **C++**: 6.7% - Native performance-critical operations
- **CMake**: 5.2% - Build configuration
- **Swift**: 0.6% - iOS-specific implementations
- **C**: 0.4% - Low-level native code

## 📦 Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK**: ^3.11.1 or higher
- **Dart SDK**: ^3.11.1 or higher
- **Android SDK** (for Android development)
  - API Level 21 or higher
  - Build Tools version 33.0.0 or higher
- **Xcode** (for iOS development - macOS only)
  - iOS Deployment Target: 11.0 or higher
- **Git**: For version control

### System Requirements

- **RAM**: Minimum 4GB (8GB recommended)
- **Disk Space**: 5GB free space for SDK and dependencies
- **Internet Connection**: Required for downloading dependencies

## 🚀 Installation

### 1. Clone the Repository

```bash
git clone https://github.com/sreejan01/voter-verification-app.git
cd voter-verification-app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Platform-Specific Settings

#### Android Configuration

```bash
flutter config --android-sdk <path-to-android-sdk>
```

#### iOS Configuration

```bash
cd ios
pod install
cd ..
```

### 4. Verify Installation

```bash
flutter doctor
```

Ensure all required dependencies show a checkmark (✓).

## ⚙️ Configuration

### API Configuration

Update the backend API endpoint in your configuration file:

```dart
// lib/config/api_config.dart
const String API_BASE_URL = 'https://your-api-endpoint.com';
```

### ML Kit Configuration

The app uses Google ML Kit for text recognition. Ensure proper initialization:

```dart
await GoogleMlKit.vision.init();
```

### Camera Permissions

The app requires camera and storage permissions. These are automatically requested at runtime on both platforms.

## 📖 Usage

### Running the App

#### Development Mode

```bash
flutter run
```

#### Release Build

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

**Web:**
```bash
flutter build web --release
```

### Basic Workflow

1. **Launch Application**: Start the app on your device or emulator
2. **Capture Document**: Use the camera interface to photograph an identity document
3. **Text Recognition**: The ML Kit engine automatically extracts text data
4. **Verification**: Verify extracted information against backend records
5. **Confirmation**: Receive verification status and complete the process

## 📁 Project Structure

```
voter-verification-app/
├── lib/
│   ├── main.dart                 # Application entry point
│   ├── screens/                  # UI screens
│   ├── services/                 # Business logic & API services
│   ├── models/                   # Data models
│   ├── widgets/                  # Reusable UI components
│   └── config/                   # Configuration files
├── assets/
│   └── icon/                     # Application icons
├── ios/                          # iOS-specific code
├── android/                      # Android-specific code
├── web/                          # Web-specific code
├── pubspec.yaml                  # Project dependencies
├── analysis_options.yaml         # Lint configuration
└── README.md                     # This file
```

## 🔒 Security Considerations

- **Data Privacy**: All personal information is encrypted during transmission
- **Secure Storage**: Sensitive data is stored securely using platform-specific secure storage
- **API Security**: All API calls use HTTPS with certificate pinning
- **Permissions**: Camera and storage permissions are requested only when needed

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/AmazingFeature`)
3. **Commit** changes (`git commit -m 'Add AmazingFeature'`)
4. **Push** to the branch (`git push origin feature/AmazingFeature`)
5. **Open** a Pull Request

### Code Standards

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Ensure all tests pass: `flutter test`
- Run linter: `flutter analyze`
- Format code: `dart format .`

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support, please:

- **Report Issues**: [GitHub Issues](https://github.com/sreejan01/voter-verification-app/issues)
- **Discussions**: [GitHub Discussions](https://github.com/sreejan01/voter-verification-app/discussions)
- **Documentation**: Check the [Flutter Documentation](https://docs.flutter.dev)

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev)
- [Dart Language Documentation](https://dart.dev/guides)
- [Google ML Kit Documentation](https://developers.google.com/ml-kit)
- [Flutter Camera Plugin](https://pub.dev/packages/camera)
- [Google ML Kit Text Recognition](https://pub.dev/packages/google_mlkit_text_recognition)

---

**Last Updated**: June 20, 2026  
**Current Version**: 1.0.0  
**Maintained by**: [@sreejan01](https://github.com/sreejan01)
