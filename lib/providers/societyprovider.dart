import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/honorsociety.dart';
import '../models/hourrequirement.dart';
import '../data/supabase_client.dart';

/// Provider for managing honor society data and state throughout the app
class SocietyProvider extends ChangeNotifier {
  HonorSociety? _currentSociety;
  List<HonorSociety> _userSocieties = [];
  bool _isAdmin = false;

  /// The society [_isAdmin] was actually resolved for.
  ///
  /// The app is multi-tenant, so "am I an admin" is only meaningful together
  /// with "of what". Keeping the two in step is what lets [_checkAdminStatus]
  /// tell a transient failure re-checking the *same* society (where holding the
  /// last known value is right) apart from a failure while switching to a
  /// *different* one (where holding it would leak the previous society's
  /// privileges into the new one).
  int? _adminFlagSocietyId;

  bool _viewAsMember = false;
  bool _isLoading = true;
  String? _loadingError;

  /// Current selected society
  HonorSociety? get currentSociety => _currentSociety;

  /// All societies the user is a member of
  List<HonorSociety> get userSocieties => _userSocieties;

  /// Whether the user is an admin of the current society (database truth).
  /// Use this to decide whether admin-only controls (e.g. "Manage Admins",
  /// the view switcher) should be available — it is unaffected by the
  /// view-as-member preview toggle.
  bool get isAdmin => _isAdmin;

  /// Whether an admin has chosen to preview the current society as a member.
  /// Persisted per society in SharedPreferences.
  bool get viewAsMember => _viewAsMember;

  /// Whether the admin shell should be shown. True only when the user is an
  /// admin AND is not currently previewing the member view.
  bool get showAdminView => _isAdmin && !_viewAsMember;

  /// SharedPreferences key holding the view preference for a given society.
  String _viewModeKey(int societyId) => 'view_as_member_$societyId';

  /// Load the persisted view preference for the current society. Non-admins
  /// always see the member view, so the flag is forced off for them.
  Future<void> _loadViewMode() async {
    if (_currentSociety == null || !_isAdmin) {
      _viewAsMember = false;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _viewAsMember =
        prefs.getBool(_viewModeKey(_currentSociety!.id)) ?? false;
  }

  /// Toggle whether the current admin previews the society as a member. The
  /// choice is persisted per society so it is restored next time the society
  /// is opened.
  Future<void> setViewAsMember(bool value) async {
    if (!_isAdmin || _currentSociety == null) return;
    _viewAsMember = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_viewModeKey(_currentSociety!.id), value);
  }

  /// Whether data is currently loading
  bool get isLoading => _isLoading;

  /// Error message if loading failed
  String? get loadingError => _loadingError;

  /// Debugging indicator for initialization state
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the provider
  SocietyProvider() {
    // Automatically load societies if user is logged in
    final currentUser = supabase.auth.currentUser;
    if (currentUser != null) {
      loadUserSocieties();
    } else {
      // If no user, we're not loading, just empty
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Load all societies the user is a member of
  Future<void> loadUserSocieties() async {
    _isLoading = true;
    _loadingError = null;
    notifyListeners();

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _isLoading = false;
        _userSocieties = [];
        _currentSociety = null;
        _isAdmin = false;
        _adminFlagSocietyId = null;
        _isInitialized = true;
        notifyListeners();
        return;
      }

      // Debug print
      debugPrint('SocietyProvider: Loading societies for user $userId');

      final societies = await supabase
          .from('user_society_memberships')
          .select('''
            honor_societies!inner(
              id,
              name,
              description,
              image_url,
              meeting_requirement,
              created_at,
              error_form_url,
              hour_requirements(
                id,
                type,
                description,
                hours_needed,
                is_active,
                icon_name
              )
            ),
            is_admin
          ''').eq('user_id', userId);

      debugPrint('SocietyProvider: Found ${societies.length} societies');

      // Remember which society was selected so a reload keeps the user where
      // they were instead of snapping back to the first one.
      final previousSocietyId = _currentSociety?.id;

      _userSocieties = [];
      final adminBySocietyId = <int, bool>{};

      for (var membership in societies) {
        final societyData = membership['honor_societies'];
        final hourRequirements = (societyData['hour_requirements'] as List)
            .map((req) => HourRequirement.fromJson(req))
            .toList();

        final society = HonorSociety(
          id: societyData['id'],
          name: societyData['name'],
          description: societyData['description'],
          imageUrl: societyData['image_url'],
          hourRequirements: hourRequirements,
          meetingRequirement: societyData['meeting_requirement'],
          errorFormUrl: societyData['error_form_url'],
          createdAt: DateTime.parse(societyData['created_at']),
        );

        _userSocieties.add(society);
        adminBySocietyId[society.id] = membership['is_admin'] ?? false;
      }

      // Always re-resolve the current society against the rows just fetched.
      //
      // Previously both the society and the admin flag were only assigned when
      // `_currentSociety == null`, so any reload after the user had picked a
      // society left `_isAdmin` at its old value and left `_currentSociety`
      // pointing at a stale object holding stale hour requirements. Promoting
      // or demoting an admin therefore did not take effect until a full
      // restart.
      if (_userSocieties.isEmpty) {
        _currentSociety = null;
        _isAdmin = false;
        _adminFlagSocietyId = null;
      } else {
        _currentSociety = _userSocieties.firstWhere(
          (society) => society.id == previousSocietyId,
          orElse: () => _userSocieties.first,
        );
        _isAdmin = adminBySocietyId[_currentSociety!.id] ?? false;
        _adminFlagSocietyId = _currentSociety!.id;
      }

      debugPrint('SocietyProvider: Current society: ${_currentSociety?.name}');

      await _loadViewMode();

      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user societies: $e');
      _loadingError = e.toString();
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Set the current society by ID
  Future<void> setCurrentSociety(int societyId) async {
    _isLoading = true;
    _loadingError = null;
    notifyListeners();

    try {
      debugPrint('SocietyProvider: Setting current society to ID $societyId');

      // First check if the society is in our existing list
      final existingSociety = _userSocieties.firstWhere(
        (s) => s.id == societyId,
        orElse: () => HonorSociety(
            id: -1,
            name: '',
            description: '',
            hourRequirements: [],
            meetingRequirement: 0,
            createdAt: DateTime.now()),
      );

      if (existingSociety.id != -1) {
        debugPrint(
            'SocietyProvider: Found society in existing list: ${existingSociety.name}');
        _currentSociety = existingSociety;
        await _checkAdminStatus();
      } else {
        // If not in our list, fetch it from the database
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          _isLoading = false;
          notifyListeners();
          return;
        }

        debugPrint('SocietyProvider: Fetching society details from database');
        final response = await supabase
            .from('user_society_memberships')
            .select('''
            honor_societies!inner(
              id,
              name,
              description,
              image_url,
              meeting_requirement,
              created_at,
              error_form_url,
              hour_requirements(
                id,
                type,
                description,
                hours_needed,
                is_active,
                icon_name
              )
            ),
            is_admin
          ''')
            .eq('user_id', userId)
            .eq('society_id', societyId)
            .single();

        final societyData = response['honor_societies'];
        final hourRequirements = (societyData['hour_requirements'] as List)
            .map((req) => HourRequirement.fromJson(req))
            .toList();

        _currentSociety = HonorSociety(
          id: societyData['id'],
          name: societyData['name'],
          description: societyData['description'],
          imageUrl: societyData['image_url'],
          hourRequirements: hourRequirements,
          meetingRequirement: societyData['meeting_requirement'],
          errorFormUrl: societyData['error_form_url'],
          createdAt: DateTime.parse(societyData['created_at']),
        );

        debugPrint(
            'SocietyProvider: Set current society to: ${_currentSociety?.name}');

        _isAdmin = response['is_admin'] ?? false;
        _adminFlagSocietyId = _currentSociety!.id;
      }

      await _loadViewMode();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting current society: $e');
      _loadingError = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh the current society data
  Future<void> refreshCurrentSociety() async {
    if (_currentSociety == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint(
          'SocietyProvider: Refreshing current society: ${_currentSociety?.name}');
      final societyId = _currentSociety!.id;
      final response =
          await supabase.from('honor_societies').select('''
          id,
          name,
          description,
          image_url,
          meeting_requirement,
          created_at,
          error_form_url,
          hour_requirements(
            id,
            type,
            description,
            hours_needed,
            is_active,
            icon_name
          )
        ''').eq('id', societyId).single();

      final hourRequirements = (response['hour_requirements'] as List)
          .map((req) => HourRequirement.fromJson(req))
          .toList();

      _currentSociety = HonorSociety(
        id: response['id'],
        name: response['name'],
        description: response['description'],
        imageUrl: response['image_url'],
        hourRequirements: hourRequirements,
        meetingRequirement: response['meeting_requirement'],
        errorFormUrl: response['error_form_url'],
        createdAt: DateTime.parse(response['created_at']),
      );

      // Update this society in the user's society list
      final index = _userSocieties.indexWhere((s) => s.id == societyId);
      if (index != -1) {
        _userSocieties[index] = _currentSociety!;
      }

      debugPrint('SocietyProvider: Successfully refreshed society data');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing current society: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if the user is an admin of the current society
  Future<void> _checkAdminStatus() async {
    if (_currentSociety == null) return;

    final societyId = _currentSociety!.id;

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        // No signed-in user is not a transient failure — there is nobody to be
        // an admin. Fail closed rather than leaving the previous user's flag in
        // place for whoever signs in next.
        _isAdmin = false;
        _adminFlagSocietyId = null;
        return;
      }

      debugPrint(
          'SocietyProvider: Checking admin status for society $societyId');

      final response = await supabase
          .from('user_society_memberships')
          .select('is_admin')
          .eq('user_id', userId)
          .eq('society_id', societyId)
          .single();

      _isAdmin = response['is_admin'] ?? false;
      _adminFlagSocietyId = societyId;
      debugPrint('SocietyProvider: Admin status is $_isAdmin');
    } catch (e) {
      _loadingError = e.toString();

      // Only hold the previous value when it belongs to the society we were
      // re-checking. That is the case this leniency exists for: a network blip
      // or a momentary RLS hiccup used to set `_isAdmin = false` and silently
      // demote an admin into the member shell until they restarted.
      //
      // When the flag belongs to a *different* society we are mid-switch, and
      // holding it would carry one society's admin rights into another — an
      // admin of society A who fails this check while opening society B would
      // get B's admin shell. Fail closed there; the user can retry the switch.
      if (_adminFlagSocietyId == societyId) {
        debugPrint('Error checking admin status (keeping previous value): $e');
        return;
      }

      debugPrint(
          'Error checking admin status while switching to society $societyId '
          '(failing closed): $e');
      _isAdmin = false;
      _adminFlagSocietyId = null;
    }
  }

  /// Request to join a society
  Future<bool> requestJoinSociety(HonorSociety society) async {
    try {
      debugPrint('SocietyProvider: Requesting to join society ${society.name}');
      final result = await supabase.rpc(
          'request_society_membership',
          params: {'society_id_param': society.id});

      if (result == true) {
        await loadUserSocieties();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error requesting to join society: $e');
      return false;
    }
  }

  /// Create a new society (for testing)
  Future<bool> createSociety(
      String name, String description, int meetingRequirement) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      debugPrint('SocietyProvider: Creating new society "$name"');

      final newSocietyId =
          await supabase.rpc('create_society', params: {
        'name_param': name,
        'description_param': description,
        'meeting_requirement_param': meetingRequirement,
        'creator_user_id': userId
      });

      debugPrint('SocietyProvider: New society created with ID $newSocietyId');

      if (newSocietyId != null) {
        await loadUserSocieties();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error creating society: $e');
      return false;
    }
  }

  /// Create a new hour requirement with icon
  Future<bool> createHourRequirement(String type, String description,
      double hoursNeeded, String iconName) async {
    if (_currentSociety == null) return false;

    try {
      final response = await supabase
          .from('hour_requirements')
          .insert({
            'society_id': _currentSociety!.id,
            'type': type,
            'description': description,
            'hours_needed': hoursNeeded,
            'is_active': true,
            'icon_name': iconName,
          })
          .select()
          .single();

      if (response != null) {
        // Add to local data
        final newRequirement = HourRequirement.fromJson(response);
        _currentSociety!.hourRequirements.add(newRequirement);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error creating hour requirement: $e');
      return false;
    }
  }

  /// Update an hour requirement including its icon
  Future<bool> updateHourRequirement(
      int requirementId,
      String type,
      String description,
      double hoursNeeded,
      bool isActive,
      String iconName) async {
    if (_currentSociety == null) return false;

    try {
      await supabase.from('hour_requirements').update({
        'type': type,
        'description': description,
        'hours_needed': hoursNeeded,
        'is_active': isActive,
        'icon_name': iconName,
      }).eq('id', requirementId);

      // Update local data
      if (_currentSociety != null) {
        final index = _currentSociety!.hourRequirements
            .indexWhere((r) => r.id == requirementId);
        if (index != -1) {
          _currentSociety!.hourRequirements[index] = HourRequirement(
            id: requirementId,
            type: type,
            description: description,
            hoursNeeded: hoursNeeded,
            isActive: isActive,
            iconName: iconName,
          );
          notifyListeners();
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error updating hour requirement: $e');
      return false;
    }
  }

  /// Handle user logout - reset state
  void handleLogout() {
    _currentSociety = null;
    _userSocieties = [];
    _isAdmin = false;
    _viewAsMember = false;
    _isLoading = false;
    _loadingError = null;
    notifyListeners();
  }

  void cancelLoading() {
    _isLoading = false;
    notifyListeners();
  }
}
