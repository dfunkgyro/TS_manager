// services/supabase_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/track_data.dart';
import '../models/enhanced_track_data.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient? _client;
  User? _currentUser;

  // Configuration - These should be stored in environment variables
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  bool get isInitialized => _client != null;
  bool get isAuthenticated => _currentUser != null;
  User? get currentUser => _currentUser;
  SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase not initialized. Call initialize() first.');
    }
    return _client!;
  }

  /// Initialize Supabase connection
  Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          logLevel: RealtimeLogLevel.info,
        ),
      );

      _client = Supabase.instance.client;

      // Listen to auth state changes
      _client!.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        if (event == AuthChangeEvent.signedIn) {
          _currentUser = session?.user;
          debugPrint('User signed in: ${_currentUser?.email}');
        } else if (event == AuthChangeEvent.signedOut) {
          _currentUser = null;
          debugPrint('User signed out');
        }
      });

      // Check if user is already logged in
      final session = _client!.auth.currentSession;
      if (session != null) {
        _currentUser = session.user;
      }

      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
      rethrow;
    }
  }

  // ============= AUTHENTICATION =============

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? userData,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: userData,
      );

      if (response.user != null) {
        _currentUser = response.user;
      }

      return response;
    } catch (e) {
      debugPrint('Error signing up: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _currentUser = response.user;
      }

      return response;
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      final response = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.tracksectionsmanager://login-callback/',
      );

      return response;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
      _currentUser = null;
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('Error resetting password: $e');
      rethrow;
    }
  }

  /// Update user profile
  Future<UserResponse> updateProfile({
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? data,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (data != null) updates.addAll(data);

      final response = await client.auth.updateUser(
        UserAttributes(data: updates),
      );

      if (response.user != null) {
        _currentUser = response.user;
      }

      return response;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  // ============= TRACK SECTIONS DATABASE =============

  /// Fetch all track sections from Supabase
  Future<List<TrackSection>> fetchTrackSections() async {
    try {
      final response = await client
          .from('track_sections')
          .select()
          .order('lcs_meterage_start');

      return (response as List)
          .map((json) => TrackSection.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching track sections: $e');
      return [];
    }
  }

  /// Fetch track sections by line
  Future<List<TrackSection>> fetchTrackSectionsByLine(String line) async {
    try {
      final response = await client
          .from('track_sections')
          .select()
          .eq('operating_line', line)
          .order('lcs_meterage_start');

      return (response as List)
          .map((json) => TrackSection.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching track sections by line: $e');
      return [];
    }
  }

  /// Search track sections by meterage
  Future<List<TrackSection>> searchTrackSectionsByMeterage(
    double meterage, {
    double radius = 100,
  }) async {
    try {
      final response = await client
          .from('track_sections')
          .select()
          .gte('lcs_meterage_end', meterage - radius)
          .lte('lcs_meterage_start', meterage + radius)
          .order('lcs_meterage_start');

      return (response as List)
          .map((json) => TrackSection.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error searching track sections by meterage: $e');
      return [];
    }
  }

  /// Search track section by LCS code
  Future<TrackSection?> searchTrackSectionByLcsCode(String lcsCode) async {
    try {
      final response = await client
          .from('track_sections')
          .select()
          .or('lcs_code.eq.$lcsCode,legacy_lcs_code.eq.$lcsCode,legacy_jnp_lcs_code.eq.$lcsCode')
          .maybeSingle();

      if (response != null) {
        return TrackSection.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error searching track section by LCS code: $e');
      return null;
    }
  }

  /// Insert a new track section
  Future<TrackSection?> insertTrackSection(TrackSection section) async {
    try {
      final response = await client
          .from('track_sections')
          .insert(section.toJson())
          .select()
          .single();

      return TrackSection.fromJson(response);
    } catch (e) {
      debugPrint('Error inserting track section: $e');
      return null;
    }
  }

  /// Update a track section
  Future<TrackSection?> updateTrackSection(
    String lcsCode,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await client
          .from('track_sections')
          .update(updates)
          .eq('lcs_code', lcsCode)
          .select()
          .single();

      return TrackSection.fromJson(response);
    } catch (e) {
      debugPrint('Error updating track section: $e');
      return null;
    }
  }

  /// Delete a track section
  Future<bool> deleteTrackSection(String lcsCode) async {
    try {
      await client
          .from('track_sections')
          .delete()
          .eq('lcs_code', lcsCode);

      return true;
    } catch (e) {
      debugPrint('Error deleting track section: $e');
      return false;
    }
  }

  // ============= STATIONS/LOCATIONS DATABASE =============

  /// Fetch all stations
  Future<List<LCSStationMapping>> fetchStations() async {
    try {
      final response = await client
          .from('stations')
          .select()
          .order('station');

      return (response as List)
          .map((json) => LCSStationMapping.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching stations: $e');
      return [];
    }
  }

  /// Search stations by name or LCS code
  Future<List<LCSStationMapping>> searchStations(String query) async {
    try {
      final response = await client
          .from('stations')
          .select()
          .or('station.ilike.%$query%,lcs_code.ilike.%$query%,line.ilike.%$query%')
          .order('station');

      return (response as List)
          .map((json) => LCSStationMapping.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error searching stations: $e');
      return [];
    }
  }

  /// Get stations by line
  Future<List<LCSStationMapping>> fetchStationsByLine(String line) async {
    try {
      final response = await client
          .from('stations')
          .select()
          .eq('line', line)
          .order('station');

      return (response as List)
          .map((json) => LCSStationMapping.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching stations by line: $e');
      return [];
    }
  }

  /// Insert a new station
  Future<LCSStationMapping?> insertStation(LCSStationMapping station) async {
    try {
      final response = await client
          .from('stations')
          .insert(station.toJson())
          .select()
          .single();

      return LCSStationMapping.fromJson(response);
    } catch (e) {
      debugPrint('Error inserting station: $e');
      return null;
    }
  }

  // ============= USER DATA & PREFERENCES =============

  /// Save user search history
  Future<void> saveSearchHistory({
    required String searchType,
    required String searchValue,
    Map<String, dynamic>? result,
  }) async {
    if (!isAuthenticated) return;

    try {
      await client.from('search_history').insert({
        'user_id': _currentUser!.id,
        'search_type': searchType,
        'search_value': searchValue,
        'result_data': result,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving search history: $e');
    }
  }

  /// Get user search history
  Future<List<Map<String, dynamic>>> getSearchHistory({int limit = 20}) async {
    if (!isAuthenticated) return [];

    try {
      final response = await client
          .from('search_history')
          .select()
          .eq('user_id', _currentUser!.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching search history: $e');
      return [];
    }
  }

  /// Save user favorites
  Future<void> saveFavorite({
    required String itemType,
    required String itemId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isAuthenticated) return;

    try {
      await client.from('favorites').insert({
        'user_id': _currentUser!.id,
        'item_type': itemType,
        'item_id': itemId,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving favorite: $e');
    }
  }

  /// Get user favorites
  Future<List<Map<String, dynamic>>> getFavorites() async {
    if (!isAuthenticated) return [];

    try {
      final response = await client
          .from('favorites')
          .select()
          .eq('user_id', _currentUser!.id)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
      return [];
    }
  }

  /// Remove favorite
  Future<void> removeFavorite(String itemId) async {
    if (!isAuthenticated) return;

    try {
      await client
          .from('favorites')
          .delete()
          .eq('user_id', _currentUser!.id)
          .eq('item_id', itemId);
    } catch (e) {
      debugPrint('Error removing favorite: $e');
    }
  }

  // ============= REALTIME SUBSCRIPTIONS =============

  /// Subscribe to track sections updates
  RealtimeChannel subscribeToTrackSections({
    required void Function(PostgresChangePayload) onInsert,
    required void Function(PostgresChangePayload) onUpdate,
    required void Function(PostgresChangePayload) onDelete,
  }) {
    final channel = client
        .channel('track_sections_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'track_sections',
          callback: onInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'track_sections',
          callback: onUpdate,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'track_sections',
          callback: onDelete,
        )
        .subscribe();

    return channel;
  }

  /// Unsubscribe from a channel
  Future<void> unsubscribeChannel(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }
}
