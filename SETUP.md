# Track Sections Manager - Setup Guide

## Overview
Railway Track Sections Management System with LCS Code & Station Mapping, powered by Flutter and Supabase.

## Features
- ✅ Track section search by meterage and LCS code
- ✅ Station lookup with enhanced data
- ✅ Network visualization and interchange mapping
- ✅ Real-time data synchronization with Supabase
- ✅ User authentication (Email, Google Sign-In)
- ✅ Export functionality (CSV, PDF, Excel)
- ✅ Search history and favorites
- ✅ Maintenance tracking
- ✅ Beautiful Material Design 3 UI
- ✅ Dark mode support
- ✅ Cross-platform (iOS, Android, Web, Desktop)

## Prerequisites
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Supabase account (free tier available at https://supabase.com)
- Google Maps API key (optional, for map features)

## Installation

### 1. Clone the Repository
```bash
git clone <repository-url>
cd TS_manager
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Set Up Supabase

#### Create a Supabase Project
1. Go to https://supabase.com and sign up/login
2. Create a new project
3. Note down your project URL and anon key

#### Run the SQL Schema
1. Open your Supabase project dashboard
2. Go to SQL Editor
3. Open the `supabase_schema.sql` file from the project root
4. Copy and paste the entire SQL script
5. Run the script to create all tables, policies, and functions

#### Configure Supabase in the App
1. Open `lib/services/supabase_service.dart`
2. Replace the placeholder values:
```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL'; // e.g., https://xxxxx.supabase.co
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

3. Uncomment the Supabase initialization in `lib/main.dart`:
```dart
await Future.wait([
  DataService().initialize(),
  EnhancedDataService().initialize(),
  SupabaseService().initialize(), // UNCOMMENT THIS LINE
]);
```

### 4. Configure Authentication

#### Email Authentication
Email authentication is enabled by default in Supabase. No additional configuration needed.

#### Google Sign-In (Optional)
1. In Supabase Dashboard, go to Authentication > Providers
2. Enable Google provider
3. Follow Supabase's instructions to set up Google OAuth
4. Update your OAuth redirect URLs:
   - For Android: `io.supabase.tracksectionsmanager://login-callback/`
   - For iOS: `io.supabase.tracksectionsmanager://login-callback/`
   - For Web: `https://your-domain.com/auth/callback`

### 5. Configure Google Maps (Optional)
If you want to enable map features:

1. Get a Google Maps API key from https://console.cloud.google.com
2. For Android: Update `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ANDROID_GOOGLE_MAPS_API_KEY"/>
```

3. For iOS: Update `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_IOS_GOOGLE_MAPS_API_KEY")
```

### 6. Platform-Specific Setup

#### Android
1. Update `android/app/build.gradle`:
   - Ensure `minSdkVersion` is at least 23
   - Ensure `compileSdkVersion` is at least 34

2. Add permissions to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

#### iOS
1. Update `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location to show your position on track maps.</string>
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan QR codes.</string>
```

2. Set minimum iOS version in `ios/Podfile`:
```ruby
platform :ios, '13.0'
```

#### Web
No additional configuration needed. The app is ready for web deployment.

## Running the App

### Development Mode
```bash
# Run on connected device/emulator
flutter run

# Run on specific device
flutter devices
flutter run -d <device-id>

# Run on web
flutter run -d chrome
```

### Build for Production

#### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### Android App Bundle
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

#### iOS
```bash
flutter build ios --release
# Then open in Xcode to archive and upload
```

#### Web
```bash
flutter build web --release
# Output: build/web/
```

## Database Management

### Adding Sample Data
Sample data is automatically inserted when you run the SQL schema. To add more data:

1. Use Supabase Table Editor in the dashboard
2. Or insert via SQL:
```sql
INSERT INTO public.track_sections (...)
VALUES (...);
```

### Backup and Restore
Use Supabase's built-in backup features or export data using the app's export functionality.

## Environment Variables (Recommended)
For production apps, use environment variables instead of hardcoding credentials:

1. Create `.env` file:
```
SUPABASE_URL=your_url_here
SUPABASE_ANON_KEY=your_key_here
```

2. Use packages like `flutter_dotenv` to load them

## Testing

### Run Tests
```bash
flutter test
```

### Run Integration Tests
```bash
flutter test integration_test
```

## Troubleshooting

### Common Issues

1. **Supabase connection failed**
   - Check your internet connection
   - Verify Supabase URL and anon key
   - Check Supabase project status

2. **Authentication not working**
   - Verify email confirmation is disabled or check email
   - Check OAuth redirect URLs
   - Verify authentication providers are enabled in Supabase

3. **Export not working**
   - Check storage permissions on Android
   - Ensure path_provider is properly configured

4. **Maps not showing**
   - Verify Google Maps API key
   - Check billing is enabled on Google Cloud
   - Verify API restrictions

## Project Structure
```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── track_data.dart
│   └── enhanced_track_data.dart
├── screens/                  # UI screens
│   ├── splash_screen.dart
│   ├── auth_screen.dart
│   ├── home_screen.dart
│   ├── query_screen.dart
│   └── ...
├── services/                 # Business logic
│   ├── data_service.dart
│   ├── enhanced_data_service.dart
│   ├── supabase_service.dart
│   └── export_service.dart
└── widgets/                  # Reusable widgets
    ├── navigation_card.dart
    ├── result_card.dart
    └── ...
```

## Features Guide

### Search Functionality
- **Meterage Search**: Enter meterage value to find nearest sections
- **LCS Code Search**: Search by LCS code for exact matches
- **Station Search**: Search stations by name or code

### Export Options
- **CSV**: Spreadsheet-compatible format
- **Excel**: Full-featured Excel workbook
- **PDF**: Print-ready document format

### User Features
- **Search History**: Automatic tracking of recent searches
- **Favorites**: Save frequently accessed sections/stations
- **Offline Mode**: Works with cached data when offline

## Contributing
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License
[Your License Here]

## Support
For issues and questions:
- GitHub Issues: [Your Repo URL]
- Email: [Your Email]

## Acknowledgments
- Flutter team for the amazing framework
- Supabase for the backend infrastructure
- Railway operators for domain expertise
