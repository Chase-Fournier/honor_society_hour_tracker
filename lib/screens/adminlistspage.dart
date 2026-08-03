import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/societyprovider.dart';
import '../common/app_design.dart';
import '../common/app_widgets.dart';
import '../common/app_form.dart';
import '../common/nhsformatutils.dart';
import '../models/completeduserhour.dart';
import '../models/userprofile.dart';
import '../bulkediteventspage.dart';
import 'customeventformpage.dart';
import '../models/logactivity.dart';
import '../exporttoexcel.dart';
import '../common/normalizetype.dart';
import 'package:flutter/services.dart';
import '../common/iconutils.dart';
import '../providers/hapticsprovider.dart';
import '../data/supabase_client.dart';
import '../logic/user_filtering.dart';



class ColoringRule {
  final String name;
  final String colorType; // Instead of storing Color directly
  final String description;
  final bool Function(UserProfile user, Map<String, double> hoursByType)
      condition;

  ColoringRule({
    required this.name,
    required this.colorType,
    required this.description,
    required this.condition,
  });

  Color getColor(BuildContext context) {
    switch (colorType) {
      case 'error':
        return Theme.of(context).colorScheme.errorContainer.withOpacity(0.3);
      case 'tertiary':
        return Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3);
      case 'secondary':
        return Theme.of(context)
            .colorScheme
            .secondaryContainer
            .withOpacity(0.3);
      case 'warning':
        return Theme.of(context)
            .colorScheme
            .tertiaryContainer
            .withValues(alpha: 0.3);
      default:
        return Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3);
    }
  }
}

class AdminListPage extends StatefulWidget {
  const AdminListPage({super.key});

  @override
  _AdminListPageState createState() => _AdminListPageState();
}

class _AdminListPageState extends State<AdminListPage> {
  final List<UserProfile> _users = [];
  String _searchQuery = '';
  SortField _sortField = SortField.name;
  SortOrder _sortOrder = SortOrder.ascending;
  String? _selectedHourType;
  bool _isLoading = false;
  bool _isExporting = false;

  // Multi-select functionality
  bool _isMultiSelectMode = false;
  Set<String> _selectedUserIds = {};

  // Conditional filtering
  bool _useAdvancedFiltering = false;

  Map<String, double> _minimumHoursByType = {};
  Map<String, double> _maximumHoursByType = {};
  Map<String, String> _hoursConditionByType = {};

  // Hour filtering options
  double _minimumTotalHours = 0;
  double _maximumTotalHours = 50;
  String _totalHoursCondition = 'atLeast'; // 'atLeast', 'atMost', 'between'

  // Graduation year filtering
  String _filterGraduationYear = '';
  String _graduationYearCondition = 'equals'; // 'equals', 'before', 'after'

  // Dues filtering
  bool _filterByDues = false;
  bool _showPaidDues = true;

  // Customizable coloring rules
  bool _enableCustomColoring = true;
  Map<String, ColoringRule> _coloringRules = {};

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  void _initializeDynamicFiltering() {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return;

    // Initialize filtering maps for each requirement type
    _minimumHoursByType.clear();
    _maximumHoursByType.clear();
    _hoursConditionByType.clear();

    // Add Meeting requirement
    _minimumHoursByType['Meeting'] = 0;
    _maximumHoursByType['Meeting'] = society.meetingRequirement.toDouble();
    _hoursConditionByType['Meeting'] = 'atLeast';

    // Add all active hour requirements
    for (final req in society.hourRequirements) {
      if (req.isActive) {
        _minimumHoursByType[req.type] = 0;
        _maximumHoursByType[req.type] = req.hoursNeeded;
        _hoursConditionByType[req.type] = 'atLeast';
      }
    }
    // Initialize default coloring rules
  }

  void _initializeColoringRules() {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return;

    _coloringRules.clear();

    // Current year graduates with low total hours
    _coloringRules['currentYearLowHours'] = ColoringRule(
      name: 'Current Year Graduates - Low Hours',
      colorType: 'error',
      description:
          'Students graduating this year with less than 10 total hours',
      condition: (user, hoursByType) {
        final totalHours =
            hoursByType.values.fold(0.0, (sum, hours) => sum + hours);
        return user.graduationYear == DateTime.now().year.toString() &&
            totalHours < 10;
      },
    );

    // Students not meeting any requirement
    for (final req in society.hourRequirements) {
      if (req.isActive) {
        _coloringRules['low${req.type}Hours'] = ColoringRule(
          name: 'Low ${req.type} Hours',
          colorType: 'tertiary',
          description:
              'Students with less than half the required ${req.type.toLowerCase()} hours',
          condition: (user, hoursByType) {
            final hours = hoursByType[req.type] ?? 0.0;
            return hours < (req.hoursNeeded / 2);
          },
        );
      }
    }

    // Meeting requirement not met
    _coloringRules['lowMeetingAttendance'] = ColoringRule(
      name: 'Low Meeting Attendance',
      colorType: 'secondary',
      description:
          'Students with less than half the required meeting attendance',
      condition: (user, hoursByType) {
        final meetingHours = hoursByType['Meeting'] ?? 0.0;
        return meetingHours < (society.meetingRequirement / 2);
      },
    );
  }

  // Helper method to get available requirement types from current society
  List<String> get _availableHourTypes {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return ['All'];

    final types = ['All', 'Meeting']; // Always include these

    // Add all active requirements from the society
    for (final req in society.hourRequirements) {
      if (req.isActive && !types.contains(req.type)) {
        types.add(req.type);
      }
    }

    return types;
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _users.clear();
      _isLoading = true;
    });

    try {
      // Get current society
      final societyId = Provider.of<SocietyProvider>(context, listen: false)
          .currentSociety
          ?.id;
      if (societyId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      _initializeDynamicFiltering();

      _initializeColoringRules();

      // Get all the data we need in just two queries run in parallel
      final results = await Future.wait([
        // 1. Get members with their profiles and dues status in a single query
        supabase.from('user_society_memberships').select('''
            user_id, 
            has_paid_dues,
            profiles:user_id(name, email, graduation_year)
          ''').eq('society_id', societyId),

        // 2. Get all service hours for this society at once
        supabase
            .from('Service hours')
            .select('id, user_id, event_name, hours, type')
            .eq('society_id', societyId)
      ]);

      final memberships = results[0] as List;
      final hoursData = results[1] as List;

      // Process hours data into a map for quick lookup
      Map<String, List<CompletedUserHour>> userHoursMap = {};
      for (final hourData in hoursData) {
        final userId = hourData['user_id'] as String;
        final hour = CompletedUserHour.fromJson(hourData);
        userHoursMap.putIfAbsent(userId, () => []).add(hour);
      }

      // Build the user profiles from the combined data
      final List<UserProfile> users = [];
      for (final membership in memberships) {
        final userId = membership['user_id'] as String;
        final profileData = membership['profiles'];

        if (profileData != null) {
          users.add(UserProfile(
            name: profileData['name'] as String,
            id: userId,
            completedHours: userHoursMap[userId] ?? [],
            hasPaidDues: membership['has_paid_dues'] as bool? ?? false,
            graduationYear: profileData['graduation_year']?.toString() ?? '',
          ));
        }
      }

      // Sort users by name
      users.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _users.addAll(users);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching users: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  List<UserProfile> _getFilteredAndSortedUsers() {
    return filterAndSortUsers(
      _users,
      filter: UserFilter(
        searchQuery: _searchQuery,
        hourType: _selectedHourType,
        useAdvancedFiltering: _useAdvancedFiltering,
        totalHours: HourTypeFilter(
          condition: rangeConditionFromString(_totalHoursCondition),
          min: _minimumTotalHours,
          max: _maximumTotalHours,
        ),
        hoursByType: {
          for (final type in _minimumHoursByType.keys)
            type: HourTypeFilter(
              condition: rangeConditionFromString(_hoursConditionByType[type]),
              min: _minimumHoursByType[type] ?? 0,
              max: _maximumHoursByType[type] ?? 50,
            ),
        },
        graduationYear: _filterGraduationYear,
        graduationYearCondition:
            graduationYearConditionFromString(_graduationYearCondition),
        filterByDues: _filterByDues,
        showPaidDues: _showPaidDues,
      ),
      sortField: _sortField,
      sortOrder: _sortOrder,
    );
  }

  double _getTotalHours(UserProfile user) => totalHoursFor(user);

  double _getHoursByType(UserProfile user, String type) =>
      hoursByTypeFor(user, type);

  // Determine row color based on conditions
  Color _getRowColor(UserProfile user, int index, BuildContext context) {
    final isEvenRow = index % 2 == 0;
    final baseColor = isEvenRow
        ? Theme.of(context).colorScheme.surface
        : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2);

    // For multi-select mode
    if (_isMultiSelectMode && _selectedUserIds.contains(user.id)) {
      return Theme.of(context).colorScheme.primaryContainer;
    }

    // Check for conditional coloring
    if (_useAdvancedFiltering && _enableCustomColoring) {
      // Calculate hours by type for this user
      Map<String, double> hoursByType = {};

      // Initialize with all requirement types
      for (final type in _minimumHoursByType.keys) {
        hoursByType[type] = _getHoursByType(user, type);
      }

      // Check each coloring rule
      for (final rule in _coloringRules.values) {
        if (rule.condition(user, hoursByType)) {
          return rule.getColor(context);
        }
      }
    }

    return baseColor;
  }

  // Helper to build hour summary card in user details dialog
  Widget _buildHourTypeCards(UserProfile user) {
    final List<Widget> cards = [];
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;

    // Total hours card (always show)
    cards.add(Expanded(
      child: _buildHourSummaryCard(
        'Total',
        _getTotalHours(user).toStringAsFixed(1),
        Icons.watch_later,
        Theme.of(context).colorScheme.primary,
      ),
    ));

    // Meeting hours (always include)
    cards.add(Expanded(
      child: _buildHourSummaryCard(
        'Meeting',
        _getHoursByType(user, 'Meeting').toStringAsFixed(1),
        Icons.groups,
        Theme.of(context).colorScheme.tertiary,
      ),
    ));

    // Add cards for each active requirement type
    if (society != null) {
      for (final req in society.hourRequirements) {
        if (req.isActive && req.type != 'Meeting') {
          cards.add(Expanded(
            child: _buildHourSummaryCard(
              req.type,
              _getHoursByType(user, req.type).toStringAsFixed(1),
              getIconForType(req.type, context),
              _getColorForHourType(req.type, context),
            ),
          ));
        }
      }
    }

    return Row(
      children: cards,
    );
  }

  // Helper to generate hour breakdown text based on society requirements
  String _generateHoursBreakdownText(UserProfile user) {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return '';

    // If filtered by specific type
    if (_selectedHourType != null && _selectedHourType != 'All') {
      final selectedHours = _getHoursByType(user, _selectedHourType!);
      return '${selectedHours.toStringAsFixed(1)} ${_selectedHourType} hrs';
    }

    // Type abbreviations
    final StringBuffer text = StringBuffer();

    // Always include Meeting (special case)
    final meetingHours = _getHoursByType(user, 'Meeting');
    text.write('M: ${meetingHours.toStringAsFixed(1)}');

    // Add each active requirement type
    for (final req in society.hourRequirements) {
      if (req.isActive && req.type != 'Meeting') {
        // Create abbreviation from first letter or first two letters
        String abbr;
        if (req.type.isEmpty) {
          abbr = '?';
        } else if (req.type.length == 1) {
          abbr = req.type;
        } else {
          abbr = req.type.substring(0, 1);
        }

        final hours = _getHoursByType(user, req.type);
        text.write(', $abbr: ${hours.toStringAsFixed(1)}');
      }
    }

    return text.toString();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredAndSortedUsers();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: _isMultiSelectMode
          ? _buildSelectionAppBar(filteredUsers)
          : _buildBrowseAppBar(filteredUsers),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Side panel for filters on wide screens
                if (isWideScreen)
                  Container(
                    width: 260,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Scrollable content area
                        Expanded(
                          child: SingleChildScrollView(
                            padding: AppDesign.paddingMedium,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Search field
                                TextField(
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Search',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: AppDesign.borderMedium,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Sort options
                                Text(
                                  'Sort By',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildSortOptionsList(),

                                const SizedBox(height: 24),

                                // Sort order
                                Text(
                                  'Sort Order',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(spacing: 8, runSpacing: 4, children: [
                                  _buildOrderChip(SortOrder.ascending,
                                      '↑ Ascending', (setState) {}),
                                  _buildOrderChip(SortOrder.descending,
                                      '↓ Descending', (setState) {}),
                                ]),

                                const SizedBox(height: 16),

                                // Filter by hour type
                                Text(
                                  'Filter by Hour Type',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: _availableHourTypes.map((type) {
                                    return FilterChip(
                                      selected: _selectedHourType == type,
                                      label: Text(type),
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedHourType =
                                              selected ? type : null;
                                        });
                                      },
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                      selectedColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      checkmarkColor: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                    );
                                  }).toList(),
                                ),

                                const SizedBox(height: 16),

                                // Advanced filtering UI
                                ExpansionTile(
                                  title: Text(
                                    'Advanced Filtering',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  children: [
                                    SwitchListTile(
                                      title: const Text(
                                          'Enable Advanced Filtering'),
                                      value: _useAdvancedFiltering,
                                      onChanged: (value) {
                                        setState(() {
                                          _useAdvancedFiltering = value;
                                        });
                                      },
                                    ),
                                    if (_useAdvancedFiltering) ...[
                                      const SizedBox(height: 8),

                                      _buildHourFilterCard(
                                          'Total Hours', 'total'),

                                      // Dynamic hour type filters
                                      ..._buildDynamicHourFilters(),

                                      // Graduation Year Filter Card
                                      _buildGraduationYearFilterCard(),

                                      // Dues Status Filter
                                      _buildDuesStatusFilterCard(),

                                      // Coloring Rules Section
                                      _buildColoringRulesSection(),

                                      const SizedBox(height: 16),

                                      // Reset filters button
                                      // Reset filters button
                                      Center(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.clear),
                                          label: const Text('Reset Filters'),
                                          onPressed: () {
                                            final hapticsProvider =
                                                Provider.of<HapticsProvider>(
                                                    context,
                                                    listen: false);
                                            hapticsProvider.selection();
                                            _resetAllFilters;
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                // Add some padding at the bottom for better scrolling
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),

                // Main content area
                Expanded(
                  child: Column(
                    children: [
                      // Mobile top controls
                      if (!isWideScreen)
                        Padding(
                          padding: AppDesign.paddingMedium,
                          child: Column(
                            children: [
                              // Search field with filter button beside it
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      onChanged: (value) {
                                        setState(() {
                                          _searchQuery = value;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Search',
                                        prefixIcon: const Icon(Icons.search),
                                        border: OutlineInputBorder(
                                          borderRadius: AppDesign.borderMedium,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Filter button that shows bottom sheet
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      final hapticsProvider =
                                          Provider.of<HapticsProvider>(context,
                                              listen: false);
                                      hapticsProvider.selection();
                                      _showFilterOptions(context);
                                    },
                                    icon: const Icon(Icons.filter_list),
                                    label: const Text('Filter'),
                                  ),
                                ],
                              ),

                              // Show selected filter if any
                              if (_selectedHourType != null &&
                                  _selectedHourType != 'All')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Filtered by: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                      Chip(
                                        label: Text(_selectedHourType!),
                                        deleteIcon:
                                            const Icon(Icons.clear, size: 18),
                                        onDeleted: () {
                                          setState(() {
                                            _selectedHourType = null;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                      // User count info and active filter indicators
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${filteredUsers.length} ${filteredUsers.length == 1 ? 'member' : 'members'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty)
                                  Text(
                                    ' matching "${_searchQuery}"',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),

                                const Spacer(),

                                // Show summary of advanced filters if active
                                if (_useAdvancedFiltering)
                                  Chip(
                                    label: Text('Advanced Filters'),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    deleteIcon:
                                        const Icon(Icons.clear, size: 16),
                                    onDeleted: () {
                                      setState(() {
                                        _useAdvancedFiltering = false;
                                      });
                                    },
                                  ),

                                if (_isMultiSelectMode)
                                  Chip(
                                    label: Text(
                                        '${_selectedUserIds.length} selected'),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                  ),
                              ],
                            ),

                            // Show summary of active advanced filters
                            if (_useAdvancedFiltering)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    // Total hours indicators
                                    if (_totalHoursCondition == 'atLeast' &&
                                        _minimumTotalHours > 0)
                                      _buildFilterIndicator(
                                          'Total ≥ ${_minimumTotalHours.toStringAsFixed(1)}'),
                                    if (_totalHoursCondition == 'atMost' &&
                                        _maximumTotalHours < 50)
                                      _buildFilterIndicator(
                                          'Total ≤ ${_maximumTotalHours.toStringAsFixed(1)}'),
                                    if (_totalHoursCondition == 'between' &&
                                        (_minimumTotalHours > 0 ||
                                            _maximumTotalHours < 50))
                                      _buildFilterIndicator(
                                          '${_minimumTotalHours.toStringAsFixed(1)} ≤ Total ≤ ${_maximumTotalHours.toStringAsFixed(1)}'),

                                    // Service hours indicators
                                    ..._buildDynamicFilterIndicators(),

                                    // Graduation year indicators
                                    if (_filterGraduationYear.isNotEmpty)
                                      _buildFilterIndicator(_graduationYearCondition ==
                                              'equals'
                                          ? 'Year: $_filterGraduationYear'
                                          : _graduationYearCondition == 'before'
                                              ? 'Year < $_filterGraduationYear'
                                              : 'Year > $_filterGraduationYear'),

                                    // Dues status indicator
                                    if (_filterByDues)
                                      _buildFilterIndicator(
                                          'Dues: ${_showPaidDues ? 'Paid' : 'Unpaid'}'),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // User list
                      Expanded(
                        child: filteredUsers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_search,
                                      size: 64,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No members match your search'
                                          : 'No members to display',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _fetchUsers,
                                child: isWideScreen
                                    ? _buildUserTable(
                                        filteredUsers) // Table view for wide screens
                                    : _buildUserCardList(
                                        filteredUsers) // Card list for mobile
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ---- Members app bar ----
  // Default ("browse") bar: enter selection mode + a grouped tools menu.
  PreferredSizeWidget _buildBrowseAppBar(List<UserProfile> filteredUsers) {
    final haptics = Provider.of<HapticsProvider>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
      title: Text(
        'Members',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24.0,
          color: scheme.onSurface,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: 'Select members',
          onPressed: () {
            haptics.selection();
            setState(() => _isMultiSelectMode = true);
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'Tools',
          onSelected: (value) => _onToolSelected(value, filteredUsers),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'export_excel',
              child: const Row(children: [
                Icon(Icons.file_download),
                SizedBox(width: 12),
                Text('Export to Excel'),
              ]),
            ),
            PopupMenuItem(
              value: 'edit_events',
              child: const Row(children: [
                Icon(Icons.event_note),
                SizedBox(width: 12),
                Text('Edit logged events'),
              ]),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete_by_date',
              child: Row(children: [
                Icon(Icons.delete_sweep, color: scheme.error),
                const SizedBox(width: 12),
                Text('Delete hours by entry date',
                    style: TextStyle(color: scheme.error)),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  void _onToolSelected(String value, List<UserProfile> filteredUsers) {
    Provider.of<HapticsProvider>(context, listen: false).selection();
    switch (value) {
      case 'export_excel':
        if (_isExporting) return;
        setState(() => _isExporting = true);
        exportToExcel(context, filteredUsers).then((_) {
          if (mounted) setState(() => _isExporting = false);
        });
        break;
      case 'edit_events':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BulkEditEventsPage()),
        );
        break;
      case 'delete_by_date':
        _deleteHoursAfterDate();
        break;
    }
  }

  // Contextual bar shown while selecting members; hosts the bulk actions.
  PreferredSizeWidget _buildSelectionAppBar(List<UserProfile> filteredUsers) {
    final haptics = Provider.of<HapticsProvider>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;
    final hasSelection = _selectedUserIds.isNotEmpty;
    final allSelected = filteredUsers.isNotEmpty &&
        filteredUsers.every((u) => _selectedUserIds.contains(u.id));
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel',
        onPressed: () {
          haptics.selection();
          setState(() {
            _isMultiSelectMode = false;
            _selectedUserIds.clear();
          });
        },
      ),
      title: Text(
        hasSelection ? '${_selectedUserIds.length} selected' : 'Select members',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20.0,
          color: scheme.onSurface,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          tooltip: allSelected ? 'Clear selection' : 'Select all',
          onPressed: () {
            haptics.selection();
            setState(() {
              if (allSelected) {
                _selectedUserIds.clear();
              } else {
                _selectedUserIds = filteredUsers.map((u) => u.id).toSet();
              }
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add hours to selected',
          onPressed: hasSelection
              ? () {
                  haptics.selection();
                  final selected = _users
                      .where((u) => _selectedUserIds.contains(u.id))
                      .toList();
                  _openBulkCustomEventForm(context, users: selected);
                }
              : null,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'Actions for selected',
          enabled: hasSelection,
          onSelected: (value) {
            haptics.selection();
            switch (value) {
              case 'copy_names':
                _copySelectedUserInfo(false);
                break;
              case 'copy_emails':
                _copySelectedUserInfo(true);
                break;
              case 'export_selected':
                _exportSelectedUsers();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'copy_names',
              child: const Row(children: [
                Icon(Icons.badge_outlined),
                SizedBox(width: 12),
                Text('Copy names'),
              ]),
            ),
            PopupMenuItem(
              value: 'copy_emails',
              child: const Row(children: [
                Icon(Icons.alternate_email),
                SizedBox(width: 12),
                Text('Copy emails'),
              ]),
            ),
            PopupMenuItem(
              value: 'export_selected',
              child: const Row(children: [
                Icon(Icons.file_download),
                SizedBox(width: 12),
                Text('Export selected'),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHourFilterCard(String title, String type) {
    final isTotal = type == 'total';

    // Clean up the title to prevent duplication
    String cleanTitle = title;
    if (!isTotal) {
      // Remove any existing "Hours" and add it once
      cleanTitle = title
          .replaceAll(RegExp(r'\s*hours?\s*', caseSensitive: false), '')
          .trim();
      cleanTitle = '$cleanTitle Hours';
    }

    return StatefulBuilder(
      builder: (context, setCardState) {
        final condition = isTotal
            ? _totalHoursCondition
            : (_hoursConditionByType[type] ?? 'atLeast');
        final minValue =
            isTotal ? _minimumTotalHours : (_minimumHoursByType[type] ?? 0);
        final maxValue =
            isTotal ? _maximumTotalHours : (_maximumHoursByType[type] ?? 50);
        final maxLimit = isTotal ? 50.0 : (_maximumHoursByType[type] ?? 50);

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            elevation: 0,
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!isTotal)
                        Icon(
                          getIconForType(
                              type, context), // Use 'type' instead of 'title'
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      if (!isTotal) const SizedBox(width: 8),
                      Text(
                        cleanTitle, // Use the cleaned title
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  // ... rest of the card content remains the same
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: condition,
                    decoration: const InputDecoration(
                      labelText: 'Condition',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'atLeast', child: Text('At least')),
                      DropdownMenuItem(value: 'atMost', child: Text('At most')),
                      DropdownMenuItem(
                          value: 'between', child: Text('Between')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        if (isTotal) {
                          _totalHoursCondition = value!;
                        } else {
                          _hoursConditionByType[type] =
                              value!; // Use 'type' instead of 'title'
                        }
                      });
                      setCardState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  if (condition == 'atLeast')
                    _buildRealtimeFilterInput(
                      'Minimum Value',
                      minValue,
                      0,
                      maxLimit,
                      (value) {
                        setState(() {
                          if (isTotal) {
                            _minimumTotalHours = value;
                          } else {
                            _minimumHoursByType[type] =
                                value; // Use 'type' instead of 'title'
                          }
                        });
                        setCardState(() {});
                      },
                    )
                  else if (condition == 'atMost')
                    _buildRealtimeFilterInput(
                      'Maximum Value',
                      maxValue,
                      0,
                      maxLimit,
                      (value) {
                        setState(() {
                          if (isTotal) {
                            _maximumTotalHours = value;
                          } else {
                            _maximumHoursByType[type] =
                                value; // Use 'type' instead of 'title'
                          }
                        });
                        setCardState(() {});
                      },
                    )
                  else if (condition == 'between')
                    Column(
                      children: [
                        _buildRealtimeFilterInput(
                          'Minimum Value',
                          minValue,
                          0,
                          maxLimit,
                          (value) {
                            setState(() {
                              if (isTotal) {
                                _minimumTotalHours = value;
                                if (_maximumTotalHours < _minimumTotalHours) {
                                  _maximumTotalHours = _minimumTotalHours;
                                }
                              } else {
                                _minimumHoursByType[type] =
                                    value; // Use 'type' instead of 'title'
                                if ((_maximumHoursByType[type] ?? 0) < value) {
                                  _maximumHoursByType[type] = value;
                                }
                              }
                            });
                            setCardState(() {});
                          },
                        ),
                        _buildRealtimeFilterInput(
                          'Maximum Value',
                          maxValue,
                          0,
                          maxLimit,
                          (value) {
                            setState(() {
                              if (isTotal) {
                                _maximumTotalHours = value;
                                if (_minimumTotalHours > _maximumTotalHours) {
                                  _minimumTotalHours = _maximumTotalHours;
                                }
                              } else {
                                _maximumHoursByType[type] =
                                    value; // Use 'type' instead of 'title'
                                if ((_minimumHoursByType[type] ?? 0) > value) {
                                  _minimumHoursByType[type] = value;
                                }
                              }
                            });
                            setCardState(() {});
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRealtimeFilterInput(String label, double value, double min,
      double max, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('${label}_${value.toStringAsFixed(1)}'),
            initialValue: value.toStringAsFixed(1),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: AppDesign.borderSmall,
              ),
              isDense: true,
              suffixText: 'hrs',
              hintText: '${min.toStringAsFixed(1)} - ${max.toStringAsFixed(1)}',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (text) {
              // Real-time update as user types
              final newValue = double.tryParse(text);
              if (newValue != null && newValue >= min && newValue <= max) {
                onChanged(newValue);
              }
            },
            validator: (text) {
              final newValue = double.tryParse(text ?? '');
              if (newValue == null)
                return null; // Don't show error while typing
              if (newValue < min || newValue > max) {
                return 'Must be between ${min.toStringAsFixed(1)} and ${max.toStringAsFixed(1)}';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicHourFilters() {
    return _minimumHoursByType.keys.map((hourType) {
      // Don't add "Hours" if it's already there, and handle the title properly
      String displayTitle;
      if (hourType.toLowerCase().contains('hour')) {
        displayTitle = hourType; // Use as-is if it already contains "hour"
      } else {
        displayTitle =
            '$hourType Hours'; // Add "Hours" if it doesn't contain it
      }

      return _buildHourFilterCard(displayTitle, hourType);
    }).toList();
  }

  Widget _buildGraduationYearFilterCard() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.school,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Graduation Year',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _graduationYearCondition,
                decoration: const InputDecoration(
                  labelText: 'Condition',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'equals', child: Text('Equals')),
                  DropdownMenuItem(value: 'before', child: Text('Before')),
                  DropdownMenuItem(value: 'after', child: Text('After')),
                ],
                onChanged: (value) {
                  setState(() {
                    _graduationYearCondition = value!;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Year',
                  hintText: 'e.g. 2025',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _filterGraduationYear = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDuesStatusFilterCard() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payment,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Dues Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                title: const Text('Filter by dues status'),
                value: _filterByDues,
                onChanged: (value) {
                  setState(() {
                    _filterByDues = value;
                  });
                },
              ),
              if (_filterByDues) ...[
                RadioListTile<bool>(
                  title: const Text('Dues Paid'),
                  value: true,
                  groupValue: _showPaidDues,
                  onChanged: (value) {
                    setState(() {
                      _showPaidDues = value!;
                    });
                  },
                ),
                RadioListTile<bool>(
                  title: const Text('Dues Unpaid'),
                  value: false,
                  groupValue: _showPaidDues,
                  onChanged: (value) {
                    setState(() {
                      _showPaidDues = value!;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColoringRulesSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.palette,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Row Coloring',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                title: const Text('Enable custom row coloring'),
                value: _enableCustomColoring,
                onChanged: (value) {
                  setState(() {
                    _enableCustomColoring = value;
                  });
                },
              ),
              if (_enableCustomColoring) ...[
                const SizedBox(height: 8),
                Text(
                  'Active Coloring Rules:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ..._coloringRules.values.map((rule) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: rule.getColor(context),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                                width: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rule.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _resetAllFilters() {
    setState(() {
      // Reset total hours
      _minimumTotalHours = 0;
      _maximumTotalHours = 50;
      _totalHoursCondition = 'atLeast';

      // Reset dynamic hour filters
      for (final type in _minimumHoursByType.keys) {
        _minimumHoursByType[type] = 0;
        _hoursConditionByType[type] = 'atLeast';
      }

      // Reset other filters
      _filterGraduationYear = '';
      _graduationYearCondition = 'equals';
      _filterByDues = false;
      _showPaidDues = true;
      _enableCustomColoring = true;
    });
  }

  List<Widget> _buildDynamicFilterIndicators() {
    List<Widget> indicators = [];

    for (final hourType in _minimumHoursByType.keys) {
      final condition = _hoursConditionByType[hourType] ?? 'atLeast';
      final minValue = _minimumHoursByType[hourType] ?? 0;
      final maxValue = _maximumHoursByType[hourType] ?? 50;
      final maxLimit = _maximumHoursByType[hourType] ?? 50;

      if (condition == 'atLeast' && minValue > 0) {
        indicators.add(_buildFilterIndicator(
            '$hourType ≥ ${minValue.toStringAsFixed(1)}'));
      } else if (condition == 'atMost' && maxValue < maxLimit) {
        indicators.add(_buildFilterIndicator(
            '$hourType ≤ ${maxValue.toStringAsFixed(1)}'));
      } else if (condition == 'between' &&
          (minValue > 0 || maxValue < maxLimit)) {
        indicators.add(_buildFilterIndicator(
            '${minValue.toStringAsFixed(1)} ≤ $hourType ≤ ${maxValue.toStringAsFixed(1)}'));
      }
    }

    return indicators;
  }

  Widget _buildFilterIndicator(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: AppDesign.borderSmall,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildFilterInput(String label, double value, double min, double max,
      Function(double) onChanged) {
    // Create a controller with the current value
    final controller = TextEditingController(text: value.toStringAsFixed(1));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: AppDesign.borderSmall,
              ),
              isDense: true,
              suffixText: 'hrs',
              hintText: '${min.toStringAsFixed(1)} - ${max.toStringAsFixed(1)}',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (text) {
              final newValue = double.tryParse(text);
              if (newValue != null && newValue >= min && newValue <= max) {
                onChanged(newValue);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserTable(List<UserProfile> users) {
    // Enhanced table for wide screens with fixed header
    return Column(
      children: [
        // Table header
        Container(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              // Selection column for multi-select mode
              if (_isMultiSelectMode)
                SizedBox(
                  width: 48,
                  child: Checkbox(
                    value: _selectedUserIds.length == users.length &&
                        users.isNotEmpty,
                    tristate: _selectedUserIds.isNotEmpty &&
                        _selectedUserIds.length < users.length,
                    onChanged: (checked) {
                      setState(() {
                        if (checked ?? false) {
                          // Select all
                          _selectedUserIds = users.map((u) => u.id).toSet();
                        } else {
                          // Deselect all
                          _selectedUserIds.clear();
                        }
                      });
                    },
                  ),
                ),

              // Name column (wider)
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    setState(() {
                      if (_sortField == SortField.name) {
                        _sortOrder = _sortOrder == SortOrder.ascending
                            ? SortOrder.descending
                            : SortOrder.ascending;
                      } else {
                        _sortField = SortField.name;
                        _sortOrder = SortOrder.ascending;
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        'Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _sortField == SortField.name
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      if (_sortField == SortField.name)
                        Icon(
                          _sortOrder == SortOrder.ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),

              // Graduation year column
              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: () {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    setState(() {
                      if (_sortField == SortField.graduationYear) {
                        _sortOrder = _sortOrder == SortOrder.ascending
                            ? SortOrder.descending
                            : SortOrder.ascending;
                      } else {
                        _sortField = SortField.graduationYear;
                        _sortOrder = SortOrder.ascending;
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        'Graduation Year',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _sortField == SortField.graduationYear
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      if (_sortField == SortField.graduationYear)
                        Icon(
                          _sortOrder == SortOrder.ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),

              // Total hours column
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    setState(() {
                      if (_sortField == SortField.totalHours) {
                        _sortOrder = _sortOrder == SortOrder.ascending
                            ? SortOrder.descending
                            : SortOrder.ascending;
                      } else {
                        _sortField = SortField.totalHours;
                        _sortOrder = SortOrder.descending;
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        'Total Hours',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _sortField == SortField.totalHours
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      if (_sortField == SortField.totalHours)
                        Icon(
                          _sortOrder == SortOrder.ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),

              // Dues paid column
              Expanded(
                child: Text(
                  'Dues Paid',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

              // Actions column
              const SizedBox(
                width: 100,
                child: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // Table body with scrolling
        Expanded(
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final totalHours = _getTotalHours(user);

              // Generate hour breakdown text
              final hoursText = _generateHoursBreakdownText(user);

              return Container(
                color: _getRowColor(user, index, context),
                child: InkWell(
                  onTap: () {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    if (_isMultiSelectMode) {
                      setState(() {
                        if (_selectedUserIds.contains(user.id)) {
                          _selectedUserIds.remove(user.id);
                        } else {
                          _selectedUserIds.add(user.id);
                        }
                      });
                    } else {
                      _showUserDetailsDialog(user);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        // Checkbox for multi-select mode
                        if (_isMultiSelectMode)
                          SizedBox(
                            width: 48,
                            child: Checkbox(
                              value: _selectedUserIds.contains(user.id),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked ?? false) {
                                    _selectedUserIds.add(user.id);
                                  } else {
                                    _selectedUserIds.remove(user.id);
                                  }
                                });
                              },
                            ),
                          ),

                        // Name column
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2),
                                child: Text(
                                  user.name.isNotEmpty ? user.name[0] : '?',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  user.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Graduation Year column
                        Expanded(
                          flex: 1,
                          child: Text(
                            user.graduationYear,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        // Total hours column
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${totalHours.toStringAsFixed(1)} hrs',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                hoursText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: Center(
                            child: IconButton(
                              icon: Icon(
                                user.hasPaidDues
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: user.hasPaidDues
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () {
                                final hapticsProvider =
                                    Provider.of<HapticsProvider>(context,
                                        listen: false);
                                hapticsProvider.selection();
                                _toggleDuesStatus(user);
                              },
                            ),
                          ),
                        ),

                        // Actions column
                        SizedBox(
                          width: 120,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add),
                                tooltip: 'Add Hours',
                                onPressed: () {
                                  final hapticsProvider =
                                      Provider.of<HapticsProvider>(context,
                                          listen: false);
                                  hapticsProvider.selection();
                                  _openCustomEventForm(context, user.id);
                                },
                                constraints: const BoxConstraints(),
                                padding: AppDesign.paddingSmall,
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Edit Hours',
                                onPressed: () {
                                  final hapticsProvider =
                                      Provider.of<HapticsProvider>(context,
                                          listen: false);
                                  hapticsProvider.selection();
                                  _showUserHoursEditDialog(user);
                                },
                                constraints: const BoxConstraints(),
                                padding: AppDesign.paddingSmall,
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_vert),
                                tooltip: 'More Options',
                                onPressed: () {
                                  final hapticsProvider =
                                      Provider.of<HapticsProvider>(context,
                                          listen: false);
                                  hapticsProvider.selection();
                                  _showUserActionsMenu(context, user);
                                },
                                constraints: const BoxConstraints(),
                                padding: AppDesign.paddingSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showUserHoursEditDialog(UserProfile user) {
    if (user.completedHours.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} has no hours to edit')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: AppDesign.paddingMedium,
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Edit Hours for ${user.name}',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Hours list
                Expanded(
                  child: ListView.builder(
                    padding: AppDesign.paddingMedium,
                    itemCount: user.completedHours.length,
                    itemBuilder: (context, index) {
                      final hour = user.completedHours[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.3),
                          borderRadius: AppDesign.borderMedium,
                        ),
                        child: ListTile(
                          title: Text(
                            hour.eventName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text('${hour.hours} hours - ${hour.type}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: () {
                                  final hapticsProvider =
                                      Provider.of<HapticsProvider>(context,
                                          listen: false);
                                  hapticsProvider.selection();
                                  Navigator.pop(context); // Close hours dialog
                                  _showEditHourDialog(context, user, hour);
                                },
                                tooltip: 'Edit This Hour',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  final hapticsProvider =
                                      Provider.of<HapticsProvider>(context,
                                          listen: false);
                                  hapticsProvider.selection();
                                  Navigator.pop(context); // Close hours dialog
                                  _deleteServiceHour(hour, user.id);
                                },
                                tooltip: 'Delete This Hour',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Footer
                Padding(
                  padding: AppDesign.paddingMedium,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          Navigator.pop(context);
                        },
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          Navigator.pop(context);
                          _openCustomEventForm(context, user.id);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Hours'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Export only selected users to Excel
  void _exportSelectedUsers() {
    if (_selectedUserIds.isEmpty) return;

    setState(() => _isExporting = true);

    final selectedUsers =
        _users.where((u) => _selectedUserIds.contains(u.id)).toList();
    exportToExcel(context, selectedUsers).then((_) {
      setState(() => _isExporting = false);
    });
  }

  Widget _buildUserCardList(List<UserProfile> users) {
    // Card-based list for mobile screens
    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(UserProfile user) {
    // Get society requirements from provider
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return const SizedBox();

    // Generate abbreviations for requirement types
    Map<String, String> typeAbbreviations = {};
    Set<String> usedFirstLetters = {};

    // Add Meeting first (special requirement)
    typeAbbreviations['Meeting'] = 'M';
    usedFirstLetters.add('M');

    // Add other requirements with adaptive abbreviations
    for (final req in society.hourRequirements) {
      if (req.isActive) {
        final type = req.type;
        final firstLetter = type.isEmpty ? 'X' : type[0].toUpperCase();

        if (!usedFirstLetters.contains(firstLetter)) {
          // If first letter isn't used yet, use it
          typeAbbreviations[type] = firstLetter;
          usedFirstLetters.add(firstLetter);
        } else {
          // If first letter is already used, use first two letters
          final secondLetter = type.length > 1 ? type[1].toLowerCase() : '';
          typeAbbreviations[type] = '$firstLetter$secondLetter';
        }
      }
    }

    // Calculate hours for each requirement type
    Map<String, double> hoursByType = {};
    double totalHours = 0;

    // Initialize with 0 for all requirement types
    typeAbbreviations.keys.forEach((type) {
      hoursByType[type] = 0;
    });

    // Sum hours by type
    for (final hour in user.completedHours) {
      final normalizedType = normalizeType(hour.type);
      if (hoursByType.containsKey(normalizedType)) {
        hoursByType[normalizedType] =
            (hoursByType[normalizedType] ?? 0) + hour.hours;
        totalHours += hour.hours;
      } else if (typeAbbreviations.keys
          .any((k) => normalizeType(k) == normalizedType)) {
        // Try to find a matching type with different capitalization
        final matchingType = typeAbbreviations.keys.firstWhere(
          (k) => normalizeType(k) == normalizedType,
          orElse: () => normalizedType,
        );
        hoursByType[matchingType] =
            (hoursByType[matchingType] ?? 0) + hour.hours;
        totalHours += hour.hours;
      }
    }

    // Build the hours display text
    final StringBuffer hoursText = StringBuffer();
    hoursText.write('${totalHours.toStringAsFixed(1)} hrs (');

    final List<String> hourParts = [];
    typeAbbreviations.forEach((type, abbr) {
      hourParts.add('$abbr: ${hoursByType[type]?.toStringAsFixed(1)}');
    });

    hoursText.write(hourParts.join(', '));
    hoursText.write(')');

    // Filter hours by selected type if needed
    final List<CompletedUserHour> filteredHours = _selectedHourType != null &&
            _selectedHourType != 'All'
        ? user.completedHours
            .where((hour) =>
                normalizeType(hour.type) == normalizeType(_selectedHourType!))
            .toList()
        : user.completedHours;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppDesign.borderLarge,
        border: Border.all(
          color: _isMultiSelectMode && _selectedUserIds.contains(user.id)
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width:
              _isMultiSelectMode && _selectedUserIds.contains(user.id) ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isMultiSelectMode
          ? _buildSelectableUserCardBody(user, hoursText.toString())
          : Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(
            borderRadius: AppDesign.borderLarge,
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: AppDesign.borderLarge,
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18.0,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hoursText.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.school,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Graduation Year: ${user.graduationYear}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dues status icon
              GestureDetector(
                onDoubleTap: () => _toggleDuesStatus(user),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: user.hasPaidDues
                        ? Colors.green.withOpacity(0.1)
                        : Theme.of(context)
                            .colorScheme
                            .errorContainer
                            .withOpacity(0.3),
                    borderRadius: AppDesign.borderSmall,
                  ),
                  child: Icon(
                    user.hasPaidDues ? Icons.check_circle : Icons.cancel,
                    color: user.hasPaidDues
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Add hours button
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: AppDesign.borderSmall,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.add,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  onPressed: () {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    _openCustomEventForm(context, user.id);
                  },
                  tooltip: 'Add Hours',
                ),
              ),
            ],
          ),
          children: [
            // Add a subtle divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 8),
            // Hours list
            ...filteredHours.map((hour) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.3),
                  borderRadius: AppDesign.borderMedium,
                ),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Icon(
                      getIconForType(hour.type, context),
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    hour.eventName,
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    '${hour.hours} hours - ${hour.type}',
                    style: TextStyle(
                      fontSize: 13.0,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        tooltip: 'Edit Hour',
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          _showEditHourDialog(context, user, hour);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Delete Hour',
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          _deleteServiceHour(hour, user.id);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // Simplified member card used while selecting: no dues/grad year, no
  // expansion — the whole row toggles selection and the trailing control is a
  // selection checkbox.
  Widget _buildSelectableUserCardBody(UserProfile user, String hoursText) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _selectedUserIds.contains(user.id);

    void toggle() {
      Provider.of<HapticsProvider>(context, listen: false).selection();
      setState(() {
        if (isSelected) {
          _selectedUserIds.remove(user.id);
        } else {
          _selectedUserIds.add(user.id);
        }
      });
    }

    return InkWell(
      borderRadius: AppDesign.borderLarge,
      onTap: toggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.0,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hoursText,
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: isSelected,
              onChanged: (_) => toggle(),
            ),
          ],
        ),
      ),
    );
  }

  void _copySelectedUserInfo(bool copyEmails) async {
    if (_selectedUserIds.isEmpty) return;

    final selectedUsers =
        _users.where((u) => _selectedUserIds.contains(u.id)).toList();

    List<String> result = [];

    try {
      if (copyEmails) {
        // Need to fetch emails from the database
        final emailsResponse = await supabase
            .from('profiles')
            .select('user_id, email')
            .inFilter('user_id', _selectedUserIds.toList());

        Map<String, String> emailMap = {};
        for (var item in emailsResponse) {
          emailMap[item['user_id']] = item['email'];
        }

        // Create the list of emails
        for (var user in selectedUsers) {
          final email = emailMap[user.id] ?? '';
          if (email.isNotEmpty) {
            result.add(email);
          }
        }
      } else {
        // Just copy names
        result.addAll(selectedUsers.map((u) => u.name));
      }

      // Show dialog with text and copy button
      _showCopyDialog(
        title: copyEmails ? 'Email Addresses' : 'Member Names',
        content: result.join('\n'),
        itemCount: result.length,
        itemType: copyEmails ? 'emails' : 'names',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    }
  }

  void _showCopyDialog({
    required String title,
    required String content,
    required int itemCount,
    required String itemType,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$itemCount $itemType:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3),
                      borderRadius: AppDesign.borderMedium,
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.2),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        content,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy to Clipboard'),
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                Clipboard.setData(ClipboardData(text: content));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$itemCount $itemType copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'OK',
                      onPressed: () {},
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditHourDialog(
      BuildContext context, UserProfile user, CompletedUserHour hour) {
    final formKey = GlobalKey<_EditHourDialogContentState>();

    showAppForm<void>(
      context: context,
      title: 'Edit hours — ${user.name}',
      icon: Icons.edit,
      body: (ctx) => _EditHourDialogContent(
        key: formKey,
        hour: hour,
        availableTypes: _availableHourTypes,
      ),
      footer: (ctx) => [
        OutlinedButton(
          onPressed: () {
            Provider.of<HapticsProvider>(context, listen: false).selection();
            Navigator.of(ctx).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            Provider.of<HapticsProvider>(context, listen: false).selection();
            final saved = await formKey.currentState?.save() ?? false;
            if (saved && ctx.mounted) {
              Navigator.of(ctx).pop();
              _fetchUsers();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  // Update the sort options list to be dynamic
  Widget _buildSortOptionsList() {
    // Always include these basic sort options
    final List<Widget> options = [
      _buildSortOptionTile(SortField.name, 'Name'),
      _buildSortOptionTile(SortField.totalHours, 'Total Hours'),
      _buildSortOptionTile(
          SortField.graduationYear, 'Graduation Year'), // New sort option
    ];

    // Get society to determine which hour types to include
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society != null) {
      // If a specific type is selected, only show that one
      if (_selectedHourType != null && _selectedHourType != 'All') {
        options.add(_buildSortOptionTile(
            SortField.serviceHours, '$_selectedHourType Hours'));
      } else {
        // Otherwise show for each active requirement type
        // Always include Meeting hours
        options
            .add(_buildSortOptionTile(SortField.meetingHours, 'Meeting Hours'));

        // Add option for each active requirement type
        for (final req in society.hourRequirements) {
          if (req.isActive && req.type != 'Meeting') {
            options.add(_buildSortOptionTile(
                // We'll still use serviceHours or tutoringHours as the enum value,
                // but the display name will match the requirement type
                req.type.toLowerCase().contains('tutor')
                    ? SortField.tutoringHours
                    : SortField.serviceHours,
                '${req.type} Hours'));
          }
        }
      }
    }

    return Column(children: options);
  }

  // Helper method for sort option tile
  Widget _buildSortOptionTile(SortField field, String label) {
    return RadioListTile<SortField>(
      title: Text(label),
      value: field,
      groupValue: _sortField,
      onChanged: (value) {
        setState(() {
          _sortField = value!;
        });
      },
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  // Helper to show more actions for a user
  void _showUserActionsMenu(BuildContext context, UserProfile user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${user.name} - Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add Hours'),
                onTap: () {
                  final hapticsProvider =
                      Provider.of<HapticsProvider>(context, listen: false);
                  hapticsProvider.selection();
                  Navigator.pop(context);
                  _openCustomEventForm(context, user.id);
                },
              ),
              ListTile(
                leading: Icon(
                  user.hasPaidDues ? Icons.cancel : Icons.check_circle,
                  color: user.hasPaidDues
                      ? Theme.of(context).colorScheme.error
                      : Colors.green,
                ),
                title: Text(
                    user.hasPaidDues ? 'Mark Dues Unpaid' : 'Mark Dues Paid'),
                onTap: () {
                  final hapticsProvider =
                      Provider.of<HapticsProvider>(context, listen: false);
                  hapticsProvider.selection();
                  Navigator.pop(context);
                  _toggleDuesStatus(user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('View All Hours'),
                onTap: () {
                  final hapticsProvider =
                      Provider.of<HapticsProvider>(context, listen: false);
                  hapticsProvider.selection();
                  Navigator.pop(context);
                  _showUserDetailsDialog(user);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Show detailed user information
  void _showUserDetailsDialog(UserProfile user) {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return;

    // Group hours by type
    final Map<String, List<CompletedUserHour>> hoursByType = {};

    // Initialize with empty lists for all society requirement types
    hoursByType['Meeting'] = [];

    for (final req in society.hourRequirements) {
      if (req.isActive) {
        hoursByType[req.type] = [];
      }
    }

    // Categorize hours
    for (final hour in user.completedHours) {
      final type = hour.type;
      if (hoursByType.containsKey(type)) {
        hoursByType[type]!.add(hour);
      } else {
        // Try to find a matching type with different capitalization
        final matchingType = hoursByType.keys.firstWhere(
          (k) => normalizeType(k) == normalizeType(type),
          orElse: () => 'Other',
        );

        if (!hoursByType.containsKey(matchingType)) {
          hoursByType[matchingType] = [];
        }
        hoursByType[matchingType]!.add(hour);
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: AppDesign.paddingMedium,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          user.name.isNotEmpty ? user.name[0] : '?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Graduation Year: ${user.graduationYear}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Dues Paid: ',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Icon(
                                  user.hasPaidDues
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: user.hasPaidDues
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.error,
                                  size: 16,
                                ),
                                Text(
                                  user.hasPaidDues ? ' Yes' : ' No',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Hour summary
                Padding(
                  padding: AppDesign.paddingMedium,
                  child: _buildHourTypeCards(user),
                ),

                // Tab navigator for different hour types
                Expanded(
                  child: DefaultTabController(
                    length: hoursByType.length + 1, // All + each type
                    child: Column(
                      children: [
                        TabBar(
                          isScrollable: true,
                          tabs: [
                            const Tab(text: 'All'),
                            ...hoursByType.keys.map((type) => Tab(text: type)),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // All hours tab
                              _buildHoursList(user.completedHours),
                              // Type-specific tabs
                              ...hoursByType.values
                                  .map((hours) => _buildHoursList(hours)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom actions
                Padding(
                  padding: AppDesign.paddingMedium,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          Navigator.pop(context);
                        },
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          Navigator.pop(context);
                          _openCustomEventForm(context, user.id);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Hours'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper to build hour summary card
  Widget _buildHourSummaryCard(
      String title, String hours, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      child: Padding(
        padding: AppDesign.paddingSmall,
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              hours,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build hours list
  Widget _buildHoursList(List<CompletedUserHour> hours) {
    if (hours.isEmpty) {
      return Center(
        child: Text(
          'No hours recorded',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Sort hours by type (optional)
    hours.sort((a, b) => a.type.compareTo(b.type));

    return ListView.builder(
      itemCount: hours.length,
      itemBuilder: (context, index) {
        final hour = hours[index];
        return ListTile(
          title: Text(hour.eventName),
          subtitle: Text(hour.type),
          trailing: Text(
            '${hour.hours.toStringAsFixed(1)} hrs',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  // Helper to get color for hour type
  Color _getColorForHourType(String type, BuildContext context) {
    // Use the society's categories to determine colors systematically
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return Theme.of(context).colorScheme.primary;

    final normalizedType = type.toLowerCase();

    // Meeting is special
    if (normalizedType.contains('meet'))
      return Theme.of(context).colorScheme.tertiary;

    // Build color palette based on requirement index
    final scheme = Theme.of(context).colorScheme;
    final List<Color> palette = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
      scheme.onSurfaceVariant,
    ];

    // Find index of requirement
    int index = society.hourRequirements
        .indexWhere((req) => normalizeType(req.type) == normalizeType(type));

    // Default to primary if not found
    if (index == -1) return Theme.of(context).colorScheme.primary;

    // Return color from palette, wrapping around if needed
    return palette[index % palette.length];
  }

  // Existing method for order chip
  Widget _buildOrderChip(SortOrder order, String label, StateSetter setState) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      selected: _sortOrder == order,
      label: Text(label),
      onSelected: (selected) {
        if (selected) {
          this.setState(() => _sortOrder = order);
        }
      },
      backgroundColor:
          scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDesign.radiusXLarge)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Filter by Hour Type',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _availableHourTypes.map((type) {
                        return FilterChip(
                          selected: _selectedHourType == type,
                          label: Text(type),
                          onSelected: (selected) {
                            setState(() =>
                                _selectedHourType = selected ? type : null);
                            this.setState(() {}); // Update main screen
                          },
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          selectedColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          checkmarkColor:
                              Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOrderChip(
                          SortOrder.ascending, '↑ Ascending', setState),
                      const SizedBox(width: 8),
                      _buildOrderChip(
                          SortOrder.descending, '↓ Descending', setState),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleDuesStatus(UserProfile user) async {
    try {
      final societyId = Provider.of<SocietyProvider>(context, listen: false)
          .currentSociety
          ?.id;
      if (societyId == null) return;

      // Update dues status in user_society_memberships table instead of profiles
      await supabase
          .from('user_society_memberships')
          .update({'has_paid_dues': !user.hasPaidDues})
          .eq('user_id', user.id)
          .eq('society_id', societyId);

      // Refresh the user list to reflect the change
      await _fetchUsers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user.hasPaidDues
                  ? 'Dues marked as unpaid'
                  : 'Dues marked as paid',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating dues status: $e')),
      );
    }
  }

  Future<void> _saveCustomEvent(
    String userId,
    String eventName,
    String timeSlot,
    double hours,
    String type,
  ) async {
    try {
      final societyId = Provider.of<SocietyProvider>(context, listen: false)
          .currentSociety
          ?.id;
      if (societyId == null) return;

      await supabase.from('Service hours').insert({
        'user_id': userId,
        'event_name': eventName,
        'timeslot': timeSlot,
        'hours': hours.toDouble(),
        'type': type,
        'society_id': societyId,
      });

      await logactivity(
        eventName,
        timeSlot,
        hours,
        'manual_addition',
        userId,
        societyId: societyId,
      );

      // Update local state
      setState(() {
        final userIndex = _users.indexWhere((u) => u.id == userId);
        if (userIndex != -1) {
          final newHour = CompletedUserHour(
            eventName: eventName,
            hours: hours,
            type: type,
          );

          final updatedHours =
              List<CompletedUserHour>.from(_users[userIndex].completedHours)
                ..add(newHour);

          _users[userIndex] = UserProfile(
            name: _users[userIndex].name,
            id: userId,
            completedHours: updatedHours,
            hasPaidDues: _users[userIndex].hasPaidDues,
            graduationYear: _users[userIndex].graduationYear,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service hours added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding service hours: $e')),
      );
    }

    _fetchUsers(); // Refresh the user list after saving the custom event
  }

  void _openCustomEventForm(BuildContext context, String userId,
      {String eventName = '',
      TimeOfDay? selectedTime,
      double hours = 0,
      String? type}) {
    // Get available event types from society
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    List<String> availableTypes = [
      'Service',
      'Tutoring',
      'Meeting'
    ]; // Default fallback

    if (society != null) {
      availableTypes = ['Meeting']; // Always include Meeting

      // Add all active requirement types
      for (final req in society.hourRequirements) {
        if (req.isActive && !availableTypes.contains(req.type)) {
          availableTypes.add(req.type);
        }
      }
    }

    // If type is not provided or not in available types, set default
    type ??= availableTypes.isNotEmpty ? availableTypes.first : 'Service';
    if (!availableTypes.contains(type)) {
      type = availableTypes.isNotEmpty ? availableTypes.first : 'Service';
    }

    final formKey = GlobalKey<FormState>();
    final nameC = TextEditingController(text: eventName);
    final hoursC =
        TextEditingController(text: hours == 0 ? '0' : hours.toString());
    TimeOfDay? time = selectedTime;
    String selectedType = type;

    showAppForm<void>(
      context: context,
      title: 'Add Custom Event',
      icon: Icons.more_time,
      body: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Form(
          key: formKey,
          child: AppFormSection(
            title: 'Event details',
            icon: Icons.event_note,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Event name',
                  controller: nameC,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter an event name'
                      : null,
                ),
                const SizedBox(height: AppDesign.spacingM),
                AppTextField(
                  label: 'Hours',
                  controller: hoursC,
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid';
                    return null;
                  },
                ),
                const SizedBox(height: AppDesign.spacingM),
                AppPickerField(
                  label: 'Time',
                  hint: 'Select',
                  value: time != null
                      ? NhsFormatUtils.formatTimeOfDay(time!, ctx)
                      : null,
                  icon: Icons.schedule,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: time ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setSheetState(() => time = picked);
                    }
                  },
                ),
                const SizedBox(height: AppDesign.spacingM),
                AppDropdownField<String>(
                  label: 'Event type',
                  value: selectedType,
                  onChanged: (value) =>
                      setSheetState(() => selectedType = value ?? selectedType),
                  items: availableTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Please select an event type'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      footer: (ctx) => [
        OutlinedButton(
          onPressed: () {
            Provider.of<HapticsProvider>(context, listen: false).selection();
            Navigator.of(ctx).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Provider.of<HapticsProvider>(context, listen: false).selection();
            if (!(formKey.currentState?.validate() ?? false)) return;
            if (time == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a time')),
              );
              return;
            }
            final timeSlot = '${time!.hour}:${time!.minute}';
            _saveCustomEvent(userId, nameC.text.trim(), timeSlot,
                double.tryParse(hoursC.text) ?? 0.0, selectedType);
            Navigator.of(ctx).pop();
          },
          child: const Text('Save'),
        ),
      ],
      onDispose: () {
        nameC.dispose();
        hoursC.dispose();
      },
    );
  }

  Future<void> _deleteServiceHour(CompletedUserHour hour, String userId) async {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    await logactivity(
      hour.eventName,
      'N/A',
      hour.hours,
      'manual_deletion',
      userId,
      societyId: society?.id,
    );

    await supabase
        .from('Service hours')
        .delete()
        .eq('event_name', hour.eventName)
        .eq('user_id', userId);

    _fetchUsers();
  }

  /// Deletes every service-hour record for the current society whose
  /// `created_at` (entry time) is on or after a chosen date. This is
  /// irreversible, so it is gated behind a date picker plus two separate
  /// warning dialogs and a typed confirmation.
  Future<void> _deleteHoursAfterDate() async {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return;

    // Step 1 — pick the cutoff date.
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Delete hours entered on or after',
    );
    if (picked == null || !mounted) return;

    final cutoff = DateTime(picked.year, picked.month, picked.day);
    final cutoffLabel = DateFormat('MMM d, y').format(cutoff);

    // Count how many records would be affected so the warnings are concrete.
    int affectedCount;
    try {
      final affected = await supabase
          .from('Service hours')
          .select('id')
          .eq('society_id', society.id)
          .gte('created_at', cutoff.toIso8601String());
      affectedCount = (affected as List).length;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking hours: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    if (affectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hours were entered on or after $cutoffLabel.')),
      );
      return;
    }

    // Warning page 1 — explain scope and count.
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            color: Theme.of(ctx).colorScheme.error, size: 36),
        title: const Text('Delete entered hours?'),
        content: Text(
          'This will permanently delete $affectedCount service-hour '
          '${affectedCount == 1 ? 'record' : 'records'} for "${society.name}" '
          'that ${affectedCount == 1 ? 'was' : 'were'} entered on or after '
          '$cutoffLabel.\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    // Warning page 2 — final, requires typing DELETE.
    final controller = TextEditingController();
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final typed = controller.text.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            icon: Icon(Icons.delete_forever,
                color: Theme.of(ctx).colorScheme.error, size: 36),
            title: const Text('Final confirmation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Type DELETE to permanently remove $affectedCount '
                  '${affectedCount == 1 ? 'record' : 'records'}. '
                  'There is no way to recover them.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Type DELETE',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setLocalState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                ),
                onPressed:
                    typed ? () => Navigator.of(ctx).pop(true) : null,
                child: const Text('Delete permanently'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (secondConfirm != true || !mounted) return;

    // Perform the delete.
    try {
      await supabase
          .from('Service hours')
          .delete()
          .eq('society_id', society.id)
          .gte('created_at', cutoff.toIso8601String());

      if (mounted) {
        Provider.of<HapticsProvider>(context, listen: false).success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Deleted $affectedCount ${affectedCount == 1 ? 'record' : 'records'} entered on or after $cutoffLabel.'),
          ),
        );
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        Provider.of<HapticsProvider>(context, listen: false).error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting hours: $e')),
        );
      }
    }
  }

  void _openBulkCustomEventForm(BuildContext context,
      {List<UserProfile>? users}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkCustomEventFormPage(users: users ?? _users),
      ),
    );

    if (result == true) {
      // Refresh the user list if the bulk custom event was saved successfully
      _fetchUsers();
    }
  }
}

class _EditHourDialogContent extends StatefulWidget {
  final CompletedUserHour hour;
  final List<String> availableTypes;

  const _EditHourDialogContent({
    super.key,
    required this.hour,
    required this.availableTypes,
  });

  @override
  _EditHourDialogContentState createState() => _EditHourDialogContentState();
}

class _EditHourDialogContentState extends State<_EditHourDialogContent> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _eventNameController;
  late TextEditingController _hoursController;
  late String _selectedType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _eventNameController = TextEditingController(text: widget.hour.eventName);
    _hoursController =
        TextEditingController(text: widget.hour.hours.toString());
    _selectedType = widget.hour.type;

    // Ensure the current type is available, otherwise default to the first available
    if (!widget.availableTypes.contains(_selectedType)) {
      _selectedType = widget.availableTypes.isNotEmpty
          ? widget.availableTypes
              .firstWhere((t) => t != 'All', orElse: () => 'Service')
          : 'Service';
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  /// Validates and persists the hour change. Returns true on success so the
  /// presenting sheet can dismiss and refresh.
  Future<bool> save() async {
    if (!_formKey.currentState!.validate()) {
      return false; // Don't proceed if form is invalid
    }
    if (_isSaving) return false; // Prevent double submission

    setState(() => _isSaving = true);

    final newEventName = _eventNameController.text.trim();
    final newHours = double.tryParse(_hoursController.text.trim()) ?? 0.0;
    final newType = _selectedType;

    try {
      await supabase.from('Service hours').update({
        'event_name': newEventName,
        'hours': newHours,
        'type': newType,
      }).eq('id', widget.hour.id ?? 0); // Use the hour's ID to update

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hour updated successfully!'),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating hour: $e'),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter out 'All' from dropdown types
    final dropdownTypes =
        widget.availableTypes.where((t) => t != 'All').toList();
    // Ensure the selected type is still valid after filtering
    if (!dropdownTypes.contains(_selectedType) && dropdownTypes.isNotEmpty) {
      _selectedType = dropdownTypes.first;
    } else if (dropdownTypes.isEmpty) {
      // Handle case where no types are available (should ideally not happen if 'Service' is default)
      _selectedType = 'Service';
      if (!dropdownTypes.contains('Service'))
        dropdownTypes.add('Service'); // Add Service if missing
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppTextField(
            label: 'Event name',
            controller: _eventNameController,
            prefixIcon: Icons.event,
            validator: (value) =>
                (value == null || value.trim().isEmpty)
                    ? 'Please enter an event name'
                    : null,
          ),
          const SizedBox(height: AppDesign.spacingM),
          AppTextField(
            label: 'Hours',
            controller: _hoursController,
            prefixIcon: Icons.timer,
            keyboardType:
                const TextInputType.numberWithOptions(signed: true, decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^-?\d*\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter hours';
              }
              final hours = double.tryParse(value.trim());
              if (hours == null || hours == 0) {
                return 'Please enter a non-zero number of hours';
              }
              return null;
            },
          ),
          const SizedBox(height: AppDesign.spacingM),
          // dropdownTypes is normalized above to always be non-empty and to
          // contain _selectedType, so a dropdown is always safe here.
          AppDropdownField<String>(
            label: 'Type',
            prefixIcon: Icons.category,
            value: _selectedType,
            items: dropdownTypes.map((String type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedType = newValue;
                });
              }
            },
            validator: (value) => (value == null || value.isEmpty)
                ? 'Please select an event type'
                : null,
          ),
        ],
      ),
    );
  }
}
