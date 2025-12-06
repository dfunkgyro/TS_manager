# Track Sections Manager

<div align="center">
  <img src="assets/icons/icon.png" alt="Track Sections Manager" width="120" height="120">

  ### Railway Track Sections Management System
  **LCS Code & Meterage Management with Supabase Backend**

  [![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue.svg)](https://flutter.dev/)
  [![Supabase](https://img.shields.io/badge/Supabase-Powered-green.svg)](https://supabase.com/)
  [![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
</div>

---

## 📋 Overview

Track Sections Manager is a comprehensive Flutter application designed for managing railway track sections, LCS codes, and station mappings. Built with modern technologies including **Supabase** for backend services, this app provides real-time data synchronization, user authentication, and powerful search capabilities.

## ✨ Features

### Core Functionality
- 🔍 **Advanced Search**
  - Search by meterage value
  - Search by LCS code
  - Station name search
  - Network path finding

- 📊 **Data Management**
  - Real-time synchronization with Supabase
  - Offline support with local caching
  - Search history tracking
  - Favorites management

- 📤 **Export Capabilities**
  - CSV export
  - Excel spreadsheet export
  - PDF generation
  - Direct sharing

- 🔐 **Authentication**
  - Email/Password authentication
  - Google Sign-In
  - User profiles
  - Secure storage

- 🎨 **User Interface**
  - Material Design 3
  - Dark mode support
  - Smooth animations
  - Responsive layouts
  - Cross-platform (iOS, Android, Web, Desktop)

### Additional Features
- 📍 Geographic visualization
- 🚇 Interchange mapping
- 🔧 Maintenance tracking
- 📈 Analytics and reporting
- 🌐 Multi-line support

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher
- Supabase account (free tier available)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd TS_manager
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Supabase**
   - Create a Supabase project at https://supabase.com
   - Run the `supabase_schema.sql` script in your Supabase SQL Editor
   - Update credentials in `lib/services/supabase_service.dart`

4. **Run the app**
   ```bash
   flutter run
   ```

📖 **For detailed setup instructions, see [SETUP.md](SETUP.md)**

## 📱 Screenshots

| Home Screen | Search | Results | Export |
|------------|---------|---------|---------|
| ![Home](screenshots/home.png) | ![Search](screenshots/search.png) | ![Results](screenshots/results.png) | ![Export](screenshots/export.png) |

## 🏗️ Architecture

```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models
│   ├── track_data.dart         # Core track section models
│   └── enhanced_track_data.dart # Enhanced models with mapping
├── screens/                     # UI screens
│   ├── splash_screen.dart      # Animated splash screen
│   ├── auth_screen.dart        # Authentication UI
│   ├── home_screen.dart        # Main dashboard
│   ├── query_screen.dart       # Advanced search
│   └── ...
├── services/                    # Business logic
│   ├── data_service.dart       # Local data management
│   ├── supabase_service.dart   # Backend integration
│   └── export_service.dart     # Export functionality
└── widgets/                     # Reusable components
```

## 🛠️ Technologies

- **Frontend**: Flutter 3.0+
- **Backend**: Supabase
- **Database**: PostgreSQL (via Supabase)
- **Authentication**: Supabase Auth
- **Real-time**: Supabase Realtime
- **Storage**: Supabase Storage
- **State Management**: Provider + StatefulWidget
- **Export**: CSV, Excel, PDF libraries

## 📦 Key Dependencies

```yaml
# Backend & Database
supabase_flutter: ^2.8.0

# UI & Design
google_fonts: ^6.3.3
lottie: ^3.3.2
animations: ^2.1.1

# Data Export
csv: ^6.0.6
excel: ^4.0.6
pdf: ^3.13.4
printing: ^5.14.2

# Maps & Location
google_maps_flutter: ^2.14.0
geolocator: ^14.0.2

# Charts & Visualization
fl_chart: ^1.1.1
syncfusion_flutter_charts: ^31.2.16
```

## 📄 Database Schema

The application uses a comprehensive PostgreSQL schema with:
- `track_sections` - Railway track section data
- `stations` - Station information and coordinates
- `user_profiles` - User account data
- `search_history` - User search tracking
- `favorites` - Saved items
- `maintenance_records` - Maintenance tracking
- `exports` - Export history

See `supabase_schema.sql` for the complete schema.

## 🔧 Configuration

### Supabase Setup
```dart
// lib/services/supabase_service.dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### Google Maps (Optional)
Add your API keys in:
- Android: `android/app/src/main/AndroidManifest.xml`
- iOS: `ios/Runner/AppDelegate.swift`

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test
```

## 📦 Building for Production

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release

# Desktop (Windows/macOS/Linux)
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- Your Name - Initial work

## 🙏 Acknowledgments

- Flutter team for the incredible framework
- Supabase for the excellent backend platform
- Railway operators for domain expertise
- All contributors who help improve this project

## 📧 Contact

For questions and support:
- GitHub Issues: [Create an issue](../../issues)
- Email: your.email@example.com

## 🗺️ Roadmap

- [ ] Enhanced offline capabilities
- [ ] Real-time collaborative editing
- [ ] Mobile app notifications
- [ ] Advanced analytics dashboard
- [ ] Integration with external railway systems
- [ ] Multi-language support

---

<div align="center">
  Made with ❤️ using Flutter and Supabase
</div>
