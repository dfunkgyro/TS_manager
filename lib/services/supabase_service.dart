// services/supabase_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/track_data.dart';
import '../models/enhanced_track_data.dart';
import 'app_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient? _client;
  User? _currentUser;

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
      // Get configuration from AppConfig
      final config = AppConfig();

      if (!config.hasSupabaseConfig) {
        debugPrint('Supabase configuration not found. App will run in offline mode.');
        return;
      }

      await Supabase.initialize(
        url: config.supabaseUrl!,
        anonKey: config.supabaseAnonKey!,
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
      debugPrint('App will continue in offline mode');
      // Don't rethrow - allow app to continue in offline mode
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

  // ============= BATCH OPERATIONS =============

  /// Create a new batch operation
  Future<String?> createBatchOperation({
    required int startTrackSection,
    required int endTrackSection,
    required double startChainage,
    required double endChainage,
    required String lcsCode,
    required String operatingLine,
    required String roadDirection,
    String? station,
    String? vcc,
  }) async {
    if (!isInitialized) return null;

    try {
      final response = await client
          .from('batch_operations')
          .insert({
            'operation_type': 'track_section_batch_insert',
            'status': 'pending',
            'start_track_section': startTrackSection,
            'end_track_section': endTrackSection,
            'start_chainage': startChainage,
            'end_chainage': endChainage,
            'lcs_code': lcsCode,
            'station': station,
            'operating_line': operatingLine,
            'road_direction': roadDirection,
            'vcc': vcc,
            'user_id': _currentUser?.id,
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      debugPrint('Error creating batch operation: $e');
      return null;
    }
  }

  /// Update batch operation status
  Future<bool> updateBatchOperationStatus(
    String batchId,
    String status, {
    int? totalItems,
    int? successfulItems,
    int? failedItems,
    int? conflictedItems,
    Map<String, dynamic>? conflictsData,
    String? errorLog,
  }) async {
    if (!isInitialized) return false;

    try {
      final updates = <String, dynamic>{'status': status};

      if (totalItems != null) updates['total_items'] = totalItems;
      if (successfulItems != null) updates['successful_items'] = successfulItems;
      if (failedItems != null) updates['failed_items'] = failedItems;
      if (conflictedItems != null) updates['conflicted_items'] = conflictedItems;
      if (conflictsData != null) updates['conflicts_data'] = conflictsData;
      if (errorLog != null) updates['error_log'] = errorLog;

      if (status == 'completed' || status == 'failed' || status == 'partial') {
        updates['completed_at'] = DateTime.now().toIso8601String();
      }

      await client
          .from('batch_operations')
          .update(updates)
          .eq('id', batchId);

      return true;
    } catch (e) {
      debugPrint('Error updating batch operation: $e');
      return false;
    }
  }

  /// Get batch operation by ID
  Future<Map<String, dynamic>?> getBatchOperation(String batchId) async {
    if (!isInitialized) return null;

    try {
      final response = await client
          .from('batch_operations')
          .select()
          .eq('id', batchId)
          .single();

      return response;
    } catch (e) {
      debugPrint('Error fetching batch operation: $e');
      return null;
    }
  }

  /// Get recent batch operations
  Future<List<Map<String, dynamic>>> getRecentBatchOperations({int limit = 20}) async {
    if (!isInitialized) return [];

    try {
      final response = await client
          .from('batch_operations')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching batch operations: $e');
      return [];
    }
  }

  /// Batch insert track sections
  Future<bool> batchInsertTrackSections(
    String batchId,
    List<Map<String, dynamic>> trackSections,
  ) async {
    if (!isInitialized) return false;

    try {
      // Add batch_operation_id to each track section
      final sectionsWithBatchId = trackSections.map((section) {
        return {...section, 'batch_operation_id': batchId, 'data_source': 'batch'};
      }).toList();

      await client.from('track_sections').insert(sectionsWithBatchId);

      return true;
    } catch (e) {
      debugPrint('Error batch inserting track sections: $e');
      return false;
    }
  }

  /// Check for track section conflicts
  Future<Map<String, dynamic>?> checkTrackSectionConflict(
    int trackSectionNumber,
    String operatingLine,
    String roadDirection,
  ) async {
    if (!isInitialized) return null;

    try {
      final response = await client
          .from('track_sections')
          .select()
          .eq('track_section_number', trackSectionNumber)
          .eq('operating_line', operatingLine)
          .eq('road_direction', roadDirection)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error checking conflict: $e');
      return null;
    }
  }

  // ============= TEMPORARY SPEED RESTRICTIONS (TSR) =============

  /// Create a new TSR
  Future<Map<String, dynamic>?> createTSR({
    required String tsrNumber,
    required String lcsCode,
    required double startMeterage,
    required double endMeterage,
    required String operatingLine,
    required int restrictedSpeedMph,
    required DateTime effectiveFrom,
    required String reason,
    String? tsrName,
    String? roadDirection,
    int? normalSpeedMph,
    DateTime? effectiveUntil,
    String? description,
    String? requestedBy,
    String? approvedBy,
    List<int>? affectedTrackSections,
  }) async {
    if (!isInitialized) return null;

    try {
      final response = await client
          .from('temporary_speed_restrictions')
          .insert({
            'tsr_number': tsrNumber,
            'tsr_name': tsrName,
            'lcs_code': lcsCode,
            'start_meterage': startMeterage,
            'end_meterage': endMeterage,
            'operating_line': operatingLine,
            'road_direction': roadDirection,
            'normal_speed_mph': normalSpeedMph,
            'restricted_speed_mph': restrictedSpeedMph,
            'effective_from': effectiveFrom.toIso8601String(),
            'effective_until': effectiveUntil?.toIso8601String(),
            'status': 'planned',
            'reason': reason,
            'description': description,
            'requested_by': requestedBy,
            'approved_by': approvedBy,
            'affected_track_sections': affectedTrackSections,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('Error creating TSR: $e');
      return null;
    }
  }

  /// Get TSRs by LCS code and meterage
  Future<List<Map<String, dynamic>>> getTSRsByLocation(
    String lcsCode,
    double meterage, {
    double tolerance = 100,
  }) async {
    if (!isInitialized) return [];

    try {
      final response = await client
          .from('temporary_speed_restrictions')
          .select()
          .eq('lcs_code', lcsCode)
          .gte('end_meterage', meterage - tolerance)
          .lte('start_meterage', meterage + tolerance)
          .order('start_meterage');

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching TSRs by location: $e');
      return [];
    }
  }

  /// Get active TSRs
  Future<List<Map<String, dynamic>>> getActiveTSRs({String? operatingLine}) async {
    if (!isInitialized) return [];

    try {
      var query = client
          .from('temporary_speed_restrictions')
          .select()
          .eq('status', 'active')
          .lte('effective_from', DateTime.now().toIso8601String());

      if (operatingLine != null) {
        query = query.eq('operating_line', operatingLine);
      }

      final response = await query.order('operating_line');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching active TSRs: $e');
      return [];
    }
  }

  /// Update TSR status
  Future<bool> updateTSRStatus(String tsrId, String status) async {
    if (!isInitialized) return false;

    try {
      await client
          .from('temporary_speed_restrictions')
          .update({'status': status})
          .eq('id', tsrId);

      return true;
    } catch (e) {
      debugPrint('Error updating TSR status: $e');
      return false;
    }
  }

  /// Delete TSR
  Future<bool> deleteTSR(String tsrId) async {
    if (!isInitialized) return false;

    try {
      await client
          .from('temporary_speed_restrictions')
          .delete()
          .eq('id', tsrId);

      return true;
    } catch (e) {
      debugPrint('Error deleting TSR: $e');
      return false;
    }
  }

  // ============= TRACK SECTION GROUPINGS =============

  /// Get or create a grouping
  Future<Map<String, dynamic>?> getOrCreateGrouping({
    required String lcsCode,
    required double meterage,
    required String operatingLine,
    String? roadDirection,
    double tolerance = 10,
  }) async {
    if (!isInitialized) return null;

    try {
      // Try to find existing grouping
      final existing = await client
          .from('track_section_groupings')
          .select()
          .eq('lcs_code', lcsCode)
          .eq('operating_line', operatingLine)
          .gte('meterage_from_lcs', meterage - tolerance)
          .lte('meterage_from_lcs', meterage + tolerance)
          .maybeSingle();

      if (existing != null) {
        return existing;
      }

      // Find track sections in this range
      final trackSections = await client
          .from('track_sections')
          .select('track_section_number')
          .eq('lcs_code', lcsCode)
          .eq('operating_line', operatingLine)
          .gte('lcs_meterage', meterage - tolerance)
          .lte('lcs_meterage', meterage + tolerance);

      final trackSectionNumbers = (trackSections as List)
          .map((ts) => ts['track_section_number'] as int)
          .toList();

      // Create new grouping
      final response = await client
          .from('track_section_groupings')
          .insert({
            'lcs_code': lcsCode,
            'meterage_from_lcs': meterage,
            'operating_line': operatingLine,
            'road_direction': roadDirection,
            'track_section_numbers': trackSectionNumbers,
            'track_section_count': trackSectionNumbers.length,
            'auto_generated': true,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('Error getting/creating grouping: $e');
      return null;
    }
  }

  /// Get groupings by LCS code
  Future<List<Map<String, dynamic>>> getGroupingsByLCS(String lcsCode) async {
    if (!isInitialized) return [];

    try {
      final response = await client
          .from('track_section_groupings')
          .select()
          .eq('lcs_code', lcsCode)
          .order('meterage_from_lcs');

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching groupings: $e');
      return [];
    }
  }

  /// Update grouping track sections
  Future<bool> updateGroupingTrackSections(
    String groupingId,
    List<int> trackSectionNumbers,
  ) async {
    if (!isInitialized) return false;

    try {
      await client
          .from('track_section_groupings')
          .update({
            'track_section_numbers': trackSectionNumbers,
            'track_section_count': trackSectionNumbers.length,
            'verified': true,
            'auto_generated': false,
          })
          .eq('id', groupingId);

      return true;
    } catch (e) {
      debugPrint('Error updating grouping: $e');
      return false;
    }
  }

  /// Add track section to grouping
  Future<bool> addTrackSectionToGrouping(
    String groupingId,
    int trackSectionNumber,
  ) async {
    if (!isInitialized) return false;

    try {
      // Get current grouping
      final grouping = await client
          .from('track_section_groupings')
          .select('track_section_numbers')
          .eq('id', groupingId)
          .single();

      final currentNumbers = (grouping['track_section_numbers'] as List).cast<int>();

      if (!currentNumbers.contains(trackSectionNumber)) {
        currentNumbers.add(trackSectionNumber);
        currentNumbers.sort();

        return await updateGroupingTrackSections(groupingId, currentNumbers);
      }

      return true;
    } catch (e) {
      debugPrint('Error adding track section to grouping: $e');
      return false;
    }
  }

  /// Remove track section from grouping
  Future<bool> removeTrackSectionFromGrouping(
    String groupingId,
    int trackSectionNumber,
  ) async {
    if (!isInitialized) return false;

    try {
      // Get current grouping
      final grouping = await client
          .from('track_section_groupings')
          .select('track_section_numbers')
          .eq('id', groupingId)
          .single();

      final currentNumbers = (grouping['track_section_numbers'] as List).cast<int>();

      if (currentNumbers.contains(trackSectionNumber)) {
        currentNumbers.remove(trackSectionNumber);

        return await updateGroupingTrackSections(groupingId, currentNumbers);
      }

      return true;
    } catch (e) {
      debugPrint('Error removing track section from grouping: $e');
      return false;
    }
  }

  /// Delete grouping
  Future<bool> deleteGrouping(String groupingId) async {
    if (!isInitialized) return false;

    try {
      await client
          .from('track_section_groupings')
          .delete()
          .eq('id', groupingId);

      return true;
    } catch (e) {
      debugPrint('Error deleting grouping: $e');
      return false;
    }
  }
}
