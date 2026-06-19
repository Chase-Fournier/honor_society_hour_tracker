import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../models/honorsociety.dart';
import '../models/hourrequirement.dart';

/// Provider for managing honor society data and state throughout the app
class SocietyProvider extends ChangeNotifier {
  HonorSociety? _currentSociety;
  List<HonorSociety> _userSocieties = [];
  bool _isAdmin = false;
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
    final currentUser = Supabase.instance.client.auth.currentUser;
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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _isLoading = false;
        _userSocieties = [];
        _currentSociety = null;
        _isAdmin = false;
        _isInitialized = true;
        notifyListeners();
        return;
      }

      // Debug print
      debugPrint('SocietyProvider: Loading societies for user $userId');

      final societies = await Supabase.instance.client
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

      _userSocieties = [];
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

        // If this is the first society or we don't have a current society, set it as default
        if (_currentSociety == null) {
          _currentSociety = society;
          _isAdmin = membership['is_admin'] ?? false;
        }
      }

      if (_currentSociety == null && _userSocieties.isNotEmpty) {
        // Set the first society as default if we still don't have one
        debugPrint('SocietyProvider: Setting first society as default');
        _currentSociety = _userSocieties.first;

        // Find admin status for this society
        final currentSocietyMembership = societies.firstWhere(
          (membership) =>
              membership['honor_societies']['id'] == _currentSociety!.id,
          orElse: () => {'is_admin': false},
        );
        _isAdmin = currentSocietyMembership['is_admin'] ?? false;
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
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
          _isLoading = false;
          notifyListeners();
          return;
        }

        debugPrint('SocietyProvider: Fetching society details from database');
        final response = await Supabase.instance.client
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
          await Supabase.instance.client.from('honor_societies').select('''
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

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      debugPrint(
          'SocietyProvider: Checking admin status for society ${_currentSociety?.id}');

      final response = await Supabase.instance.client
          .from('user_society_memberships')
          .select('is_admin')
          .eq('user_id', userId)
          .eq('society_id', _currentSociety!.id)
          .single();

      _isAdmin = response['is_admin'] ?? false;
      debugPrint('SocietyProvider: Admin status is $_isAdmin');
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      _isAdmin = false;
    }
  }

  /// Request to join a society
  Future<bool> requestJoinSociety(HonorSociety society) async {
    try {
      debugPrint('SocietyProvider: Requesting to join society ${society.name}');
      final result = await Supabase.instance.client.rpc(
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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;

      debugPrint('SocietyProvider: Creating new society "$name"');

      final newSocietyId =
          await Supabase.instance.client.rpc('create_society', params: {
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
      final response = await Supabase.instance.client
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
      await Supabase.instance.client.from('hour_requirements').update({
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
