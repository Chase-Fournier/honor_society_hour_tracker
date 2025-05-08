import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../providers/societyprovider.dart';
import '../common/app_design.dart';
import '../models/completeduserhour.dart';
import '../models/userprofile.dart';
import 'bulkediteventspage.dart';
import 'customeventformpage.dart';
import '../common/customexpansiontile.dart';
import '../models/logactivity.dart';
import '../exporttoexcel.dart';
import '../common/normalizetype.dart';
import 'package:flutter/services.dart';

final supabase = Supabase.instance.client;

enum SortField {
  name,
  totalHours,
  serviceHours,
  tutoringHours,
  meetingHours,
  graduationYear, // New sort field for graduation year
}

enum SortOrder {
  ascending,
  descending,
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
  
  // Hour filtering options
  double _minimumTotalHours = 0;
  double _maximumTotalHours = 50;
  String _totalHoursCondition = 'atLeast'; // 'atLeast', 'atMost', 'between'
  
  double _minimumServiceHours = 0;
  double _maximumServiceHours = 25;
  String _serviceHoursCondition = 'atLeast'; // 'atLeast', 'atMost', 'between'
  
  double _minimumTutoringHours = 0;
  double _maximumTutoringHours = 25;
  String _tutoringHoursCondition = 'atLeast'; // 'atLeast', 'atMost', 'between'
  
  // Graduation year filtering
  String _filterGraduationYear = '';
  String _graduationYearCondition = 'equals'; // 'equals', 'before', 'after'
  
  // Dues filtering
  bool _filterByDues = false;
  bool _showPaidDues = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // Helper method to get available requirement types from current society
  List<String> get _availableHourTypes {
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
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
      final societyId = Provider.of<SocietyProvider>(context, listen: false).currentSociety?.id;
      if (societyId == null) {
        setState((){
          _isLoading = false;
        });
        return;
      }
      
      // Get all the data we need in just two queries run in parallel
      final results = await Future.wait([
        // 1. Get members with their profiles and dues status in a single query
        supabase
          .from('user_society_memberships')
          .select('''
            user_id, 
            has_paid_dues,
            profiles:user_id(name, email, graduation_year)
          ''')
          .eq('society_id', societyId),
        
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
    List<UserProfile> filteredUsers = _users;

    if (_searchQuery.isNotEmpty) {
      final lowercaseQuery = _searchQuery.toLowerCase();
      filteredUsers = filteredUsers.where((user) {
        final lowercaseName = user.name.toLowerCase();
        return lowercaseName.contains(lowercaseQuery);
      }).toList();
    }

    // Filter by hour type if selected
    if (_selectedHourType != null && _selectedHourType != 'All') {
      filteredUsers = filteredUsers.where((user) {
        return user.completedHours.any((hour) => 
          normalizeType(hour.type) == normalizeType(_selectedHourType!));
      }).toList();
    }

    // Apply advanced filtering if enabled
    if (_useAdvancedFiltering) {
      filteredUsers = filteredUsers.where((user) {
        bool meetsAllCriteria = true;
        
        // Filter by total hours
        final totalHours = _getTotalHours(user);
        if (_totalHoursCondition == 'atLeast' && _minimumTotalHours > 0) {
          meetsAllCriteria = meetsAllCriteria && (totalHours >= _minimumTotalHours);
        } else if (_totalHoursCondition == 'atMost' && _maximumTotalHours < 50) {
          meetsAllCriteria = meetsAllCriteria && (totalHours <= _maximumTotalHours);
        } else if (_totalHoursCondition == 'between' && (_minimumTotalHours > 0 || _maximumTotalHours < 50)) {
          meetsAllCriteria = meetsAllCriteria && 
            (totalHours >= _minimumTotalHours && totalHours <= _maximumTotalHours);
        }
        
        // Filter by service hours
        final serviceHours = _getHoursByType(user, 'Service');
        if (_serviceHoursCondition == 'atLeast' && _minimumServiceHours > 0) {
          meetsAllCriteria = meetsAllCriteria && (serviceHours >= _minimumServiceHours);
        } else if (_serviceHoursCondition == 'atMost' && _maximumServiceHours < 25) {
          meetsAllCriteria = meetsAllCriteria && (serviceHours <= _maximumServiceHours);
        } else if (_serviceHoursCondition == 'between' && (_minimumServiceHours > 0 || _maximumServiceHours < 25)) {
          meetsAllCriteria = meetsAllCriteria && 
            (serviceHours >= _minimumServiceHours && serviceHours <= _maximumServiceHours);
        }
        
        // Filter by tutoring hours
        final tutoringHours = _getHoursByType(user, 'Tutoring');
        if (_tutoringHoursCondition == 'atLeast' && _minimumTutoringHours > 0) {
          meetsAllCriteria = meetsAllCriteria && (tutoringHours >= _minimumTutoringHours);
        } else if (_tutoringHoursCondition == 'atMost' && _maximumTutoringHours < 25) {
          meetsAllCriteria = meetsAllCriteria && (tutoringHours <= _maximumTutoringHours);
        } else if (_tutoringHoursCondition == 'between' && (_minimumTutoringHours > 0 || _maximumTutoringHours < 25)) {
          meetsAllCriteria = meetsAllCriteria && 
            (tutoringHours >= _minimumTutoringHours && tutoringHours <= _maximumTutoringHours);
        }
        
        // Check graduation year
        if (_filterGraduationYear.isNotEmpty) {
          if (_graduationYearCondition == 'equals') {
            meetsAllCriteria = meetsAllCriteria && user.graduationYear == _filterGraduationYear;
          } else if (_graduationYearCondition == 'before') {
            // Try to convert to int for comparison
            try {
              final gradYear = int.parse(user.graduationYear);
              final filterYear = int.parse(_filterGraduationYear);
              meetsAllCriteria = meetsAllCriteria && gradYear < filterYear;
            } catch (e) {
              // Fallback to string comparison if parsing fails
              meetsAllCriteria = meetsAllCriteria && user.graduationYear.compareTo(_filterGraduationYear) < 0;
            }
          } else if (_graduationYearCondition == 'after') {
            // Try to convert to int for comparison
            try {
              final gradYear = int.parse(user.graduationYear);
              final filterYear = int.parse(_filterGraduationYear);
              meetsAllCriteria = meetsAllCriteria && gradYear > filterYear;
            } catch (e) {
              // Fallback to string comparison if parsing fails
              meetsAllCriteria = meetsAllCriteria && user.graduationYear.compareTo(_filterGraduationYear) > 0;
            }
          }
        }
        
        // Filter by dues status if selected
        if (_filterByDues) {
          meetsAllCriteria = meetsAllCriteria && user.hasPaidDues == _showPaidDues;
        }
        
        return meetsAllCriteria;
      }).toList();
    }

    // Sort the filtered users
    filteredUsers.sort((a, b) {
      int comparison;
      switch (_sortField) {
        case SortField.name:
          comparison = a.name.compareTo(b.name);
          break;
        case SortField.totalHours:
          comparison = _getTotalHours(a).compareTo(_getTotalHours(b));
          break;
        case SortField.serviceHours:
          if (_selectedHourType != null && _selectedHourType != 'All') {
            // Use dynamic type if specified
            comparison = _getHoursByType(a, _selectedHourType!)
                .compareTo(_getHoursByType(b, _selectedHourType!));
          } else {
            // Default to all service hours
            comparison = _getHoursByType(a, 'Service')
                .compareTo(_getHoursByType(b, 'Service'));
          }
          break;
        case SortField.tutoringHours:
          comparison = _getHoursByType(a, 'Tutoring')
              .compareTo(_getHoursByType(b, 'Tutoring'));
          break;
        case SortField.meetingHours:
          comparison = _getHoursByType(a, 'Meeting')
              .compareTo(_getHoursByType(b, 'Meeting'));
          break;
        case SortField.graduationYear:
          // Add sorting by graduation year
          comparison = a.graduationYear.compareTo(b.graduationYear);
          break;
      }

      return _sortOrder == SortOrder.ascending ? comparison : -comparison;
    });

    return filteredUsers;
  }

  double _getTotalHours(UserProfile user) {
    return user.completedHours.fold(0.0, (sum, hour) => sum + hour.hours);
  }

  double _getHoursByType(UserProfile user, String type) {
    return user.completedHours
        .where((hour) => normalizeType(hour.type) == normalizeType(type))
        .fold(0.0, (sum, hour) => sum + hour.hours);
  }

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
    if (_useAdvancedFiltering) {
      final totalHours = _getTotalHours(user);
      final serviceHours = _getHoursByType(user, 'Service');
      final tutoringHours = _getHoursByType(user, 'Tutoring');
      
      // Example: Color students graduating in current year + low hours in warning color
      if (user.graduationYear == DateTime.now().year.toString() && 
          totalHours < 10) {
        return Theme.of(context).colorScheme.errorContainer.withOpacity(0.3);
      }
      
      // Color students with very low tutoring hours
      if (tutoringHours < 3) {
        return Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3);
      }
      
      // Color students with low service hours and graduating soon
      if (serviceHours < 5 && 
          user.graduationYear == DateTime.now().year.toString()) {
        return Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3);
      }
    }
    
    return baseColor;
  }

  // Helper to build hour summary card in user details dialog
  Widget _buildHourTypeCards(UserProfile user) {
    final List<Widget> cards = [];
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    
    // Total hours card (always show)
    cards.add(
      Expanded(
        child: _buildHourSummaryCard(
          'Total',
          _getTotalHours(user).toStringAsFixed(1),
          Icons.watch_later,
          Theme.of(context).colorScheme.primary,
        ),
      )
    );
    
    // Meeting hours (always include)
    cards.add(
      Expanded(
        child: _buildHourSummaryCard(
          'Meeting',
          _getHoursByType(user, 'Meeting').toStringAsFixed(1),
          Icons.groups,
          Theme.of(context).colorScheme.tertiary,
        ),
      )
    );
    
    // Add cards for each active requirement type
    if (society != null) {
      for (final req in society.hourRequirements) {
        if (req.isActive && req.type != 'Meeting') {
          cards.add(
            Expanded(
              child: _buildHourSummaryCard(
                req.type,
                _getHoursByType(user, req.type).toStringAsFixed(1),
                _getIconForHourType(req.type),
                _getColorForHourType(req.type, context),
              ),
            )
          );
        }
      }
    }
    
    return Row(
      children: cards,
    );
  }

  // Helper to generate hour breakdown text based on society requirements
  String _generateHoursBreakdownText(UserProfile user) {
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        title: Text(
          'Members',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          // Multi-select mode toggle
          if (isWideScreen)
            IconButton(
              icon: Icon(
                _isMultiSelectMode ? Icons.check_box : Icons.check_box_outline_blank,
                color: _isMultiSelectMode ? Theme.of(context).colorScheme.primary : null,
              ),
              tooltip: _isMultiSelectMode ? 'Exit Multi-select' : 'Enter Multi-select',
              onPressed: () {
                setState(() {
                  _isMultiSelectMode = !_isMultiSelectMode;
                  if (!_isMultiSelectMode) {
                    _selectedUserIds.clear();
                  }
                });
              },
            ),
            
          // Show selected users action button if in multi-select mode
          if (_isMultiSelectMode && _selectedUserIds.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
              tooltip: 'Actions for selected members',
              onSelected: (value) {
                if (value == 'copy_names') {
                  _copySelectedUserInfo(false);
                } else if (value == 'copy_emails') {
                  _copySelectedUserInfo(true);
                } else if (value == 'export_selected') {
                  _exportSelectedUsers();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'copy_names',
                  child: Text('Copy Names (${_selectedUserIds.length})'),
                ),
                PopupMenuItem(
                  value: 'copy_emails',
                  child: Text('Copy Emails (${_selectedUserIds.length})'),
                ),
                PopupMenuItem(
                  value: 'export_selected',
                  child: Text('Export Selected (${_selectedUserIds.length})'),
                ),
              ],
            ),
            
          // Show bulk edit button on all screen sizes
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BulkEditEventsPage()),
              );
            },
          ),
          // Show export button on all screen sizes
          IconButton(
            icon: _isExporting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                : Icon(
                    Icons.file_download,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            onPressed: _isExporting 
                ? null 
                : () {
                    setState(() => _isExporting = true);
                    exportToExcel(context, filteredUsers).then((_) {
                      setState(() => _isExporting = false);
                    });
                  },
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                                    color: Theme.of(context).colorScheme.primary,
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
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _buildOrderChip(
                                      SortOrder.ascending, 
                                      '↑ Ascending', 
                                      (setState) {}
                                    ),
                                    _buildOrderChip(
                                      SortOrder.descending, 
                                      '↓ Descending', 
                                      (setState) {}
                                    ),
                                  ]
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Filter by hour type
                                Text(
                                  'Filter by Hour Type',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
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
                                          _selectedHourType = selected ? type : null;
                                        });
                                      },
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
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  children: [
                                    SwitchListTile(
                                      title: const Text('Enable Advanced Filtering'),
                                      value: _useAdvancedFiltering,
                                      onChanged: (value) {
                                        setState(() {
                                          _useAdvancedFiltering = value;
                                        });
                                      },
                                    ),
                                    if (_useAdvancedFiltering) ...[
                                      const SizedBox(height: 8),
                                      
                                      // Total Hours Filter
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Card(
                                          elevation: 0,
                                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Total Hours',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                // Filter type selector
                                                DropdownButtonFormField<String>(
                                                  value: _totalHoursCondition,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Condition',
                                                    isDense: true,
                                                  ),
                                                  items: const [
                                                    DropdownMenuItem(value: 'atLeast', child: Text('At least')),
                                                    DropdownMenuItem(value: 'atMost', child: Text('At most')),
                                                    DropdownMenuItem(value: 'between', child: Text('Between')),
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _totalHoursCondition = value!;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                                // Show appropriate sliders based on condition
                                                if (_totalHoursCondition == 'atLeast')
                                                  _buildFilterSlider(
                                                    'Minimum Value',
                                                    _minimumTotalHours,
                                                    0,
                                                    50,
                                                    (value) {
                                                      setState(() {
                                                        _minimumTotalHours = value;
                                                      });
                                                    },
                                                  )
                                                else if (_totalHoursCondition == 'atMost')
                                                  _buildFilterSlider(
                                                    'Maximum Value',
                                                    _maximumTotalHours,
                                                    0,
                                                    50,
                                                    (value) {
                                                      setState(() {
                                                        _maximumTotalHours = value;
                                                      });
                                                    },
                                                  )
                                                else if (_totalHoursCondition == 'between')
                                                  Column(
                                                    children: [
                                                      _buildFilterSlider(
                                                        'Minimum Value',
                                                        _minimumTotalHours,
                                                        0,
                                                        50,
                                                        (value) {
                                                          setState(() {
                                                            _minimumTotalHours = value;
                                                            // Adjust max if needed
                                                            if (_maximumTotalHours < _minimumTotalHours) {
                                                              _maximumTotalHours = _minimumTotalHours;
                                                            }
                                                          });
                                                        },
                                                      ),
                                                      _buildFilterSlider(
                                                        'Maximum Value',
                                                        _maximumTotalHours,
                                                        0,
                                                        50,
                                                        (value) {
                                                          setState(() {
                                                            _maximumTotalHours = value;
                                                            // Adjust min if needed
                                                            if (_minimumTotalHours > _maximumTotalHours) {
                                                              _minimumTotalHours = _maximumTotalHours;
                                                            }
                                                          });
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      // Service Hours Filter
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Card(
                                          elevation: 0,
                                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Service Hours',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                // Filter type selector
                                                DropdownButtonFormField<String>(
                                                  value: _serviceHoursCondition,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Condition',
                                                    isDense: true,
                                                  ),
                                                  items: const [
                                                    DropdownMenuItem(value: 'atLeast', child: Text('At least')),
                                                    DropdownMenuItem(value: 'atMost', child: Text('At most')),
                                                    DropdownMenuItem(value: 'between', child: Text('Between')),
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _serviceHoursCondition = value!;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                                // Show appropriate sliders based on condition
                                                if (_serviceHoursCondition == 'atLeast')
                                                  _buildFilterSlider(
                                                    'Minimum Value',
                                                    _minimumServiceHours,
                                                    0,
                                                    25,
                                                    (value) {
                                                      setState(() {
                                                        _minimumServiceHours = value;
                                                      });
                                                    },
                                                  )
                                                else if (_serviceHoursCondition == 'atMost')
                                                  _buildFilterSlider(
                                                    'Maximum Value',
                                                    _maximumServiceHours,
                                                    0,
                                                    25,
                                                    (value) {
                                                      setState(() {
                                                        _maximumServiceHours = value;
                                                      });
                                                    },
                                                  )
                                                else if (_serviceHoursCondition == 'between')
                                                  Column(
                                                    children: [
                                                      _buildFilterSlider(
                                                        'Minimum Value',
                                                        _minimumServiceHours,
                                                        0,
                                                        25,
                                                        (value) {
                                                          setState(() {
                                                            _minimumServiceHours = value;
                                                            if (_maximumServiceHours < _minimumServiceHours) {
                                                              _maximumServiceHours = _minimumServiceHours;
                                                            }
                                                          });
                                                        },
                                                      ),
                                                      _buildFilterSlider(
                                                        'Maximum Value',
                                                        _maximumServiceHours,
                                                        0,
                                                        25,
                                                        (value) {
                                                          setState(() {
                                                            _maximumServiceHours = value;
                                                            if (_minimumServiceHours > _maximumServiceHours) {
                                                              _minimumServiceHours = _maximumServiceHours;
                                                            }
                                                          });
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      // Tutoring Hours Filter
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Card(
                                          elevation: 0,
                                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Tutoring Hours',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                // Filter type selector
                                                DropdownButtonFormField<String>(
                                                  value: _tutoringHoursCondition,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Condition',
                                                    isDense: true,
                                                  ),
                                                  items: const [
                                                    DropdownMenuItem(value: 'atLeast', child: Text('At least')),
                                                    DropdownMenuItem(value: 'atMost', child: Text('At most')),
                                                    DropdownMenuItem(value: 'between', child: Text('Between')),
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _tutoringHoursCondition = value!;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                                // Show appropriate sliders based on condition
                                                if (_tutoringHoursCondition == 'atLeast')
                                                  _buildFilterSlider(
                                                    'Minimum Value',
                                                    _minimumTutoringHours,
                                                    0,
                                                    25,
                                                    (value) {
                                                      setState(() {
                                                        _minimumTutoringHours = value;
                                                      });
                                                    },
                                                  )
                                                else if (_tutoringHoursCondition == 'atMost')
                                                  _buildFilterSlider(
                                                    'Maximum Value',
                                                    _maximumTutoringHours,
                                                    0,
                                                    25,
                                                    (value) {
                                                      setState(() {
                                                        _maximumTutoringHours = value;
                                                      });
                                                    },
                                                  )
                                                else if (_tutoringHoursCondition == 'between')
                                                  Column(
                                                    children: [
                                                      _buildFilterSlider(
                                                        'Minimum Value',
                                                        _minimumTutoringHours,
                                                        0,
                                                        25,
                                                        (value) {
                                                          setState(() {
                                                            _minimumTutoringHours = value;
                                                            if (_maximumTutoringHours < _minimumTutoringHours) {
                                                              _maximumTutoringHours = _minimumTutoringHours;
                                                            }
                                                          });
                                                        },
                                                      ),
                                                      _buildFilterSlider(
                                                        'Maximum Value',
                                                        _maximumTutoringHours,
                                                        0,
                                                        25,
                                                        (value) {
                                                          setState(() {
                                                            _maximumTutoringHours = value;
                                                            if (_minimumTutoringHours > _maximumTutoringHours) {
                                                              _minimumTutoringHours = _maximumTutoringHours;
                                                            }
                                                          });
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      // Graduation Year Filter Card
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Card(
                                          elevation: 0,
                                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Graduation Year',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                // Filter type selector
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
                                      ),
                                      
                                      // Dues Status Filter
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Card(
                                          elevation: 0,
                                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Dues Status',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
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
                                                if (_filterByDues)
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
                                                if (_filterByDues)
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
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 16),
                                      
                                      // Reset filters button
                                      Center(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.clear),
                                          label: const Text('Reset Filters'),
                                          onPressed: () {
                                            setState(() {
                                              // Reset all filter values
                                              _minimumTotalHours = 0;
                                              _maximumTotalHours = 50;
                                              _totalHoursCondition = 'atLeast';
                                              
                                              _minimumServiceHours = 0;
                                              _maximumServiceHours = 25;
                                              _serviceHoursCondition = 'atLeast';
                                              
                                              _minimumTutoringHours = 0;
                                              _maximumTutoringHours = 25;
                                              _tutoringHoursCondition = 'atLeast';
                                              
                                              _filterGraduationYear = '';
                                              _graduationYearCondition = 'equals';
                                              
                                              _filterByDues = false;
                                              _showPaidDues = true;
                                            });
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
                        
                        // Fixed button at bottom of sidebar (outside of scroll view)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _openBulkCustomEventForm(context);
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Bulk Add Hours'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
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
                              const SizedBox(height: 16.0),
                              
                              // Bulk add button
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        _openBulkCustomEventForm(context);
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('Bulk Add'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Filter button that shows bottom sheet
                                  OutlinedButton.icon(
                                    onPressed: _showFilterOptions,
                                    icon: const Icon(Icons.filter_list),
                                    label: const Text('Filter'),
                                  ),
                                ],
                              ),
                              
                              // Show selected filter if any
                              if (_selectedHourType != null && _selectedHourType != 'All')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Filtered by: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      Chip(
                                        label: Text(_selectedHourType!),
                                        deleteIcon: const Icon(Icons.clear, size: 18),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${filteredUsers.length} ${filteredUsers.length == 1 ? 'member' : 'members'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty)
                                  Text(
                                    ' matching "${_searchQuery}"',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                
                                const Spacer(),
                                
                                // Show summary of advanced filters if active
                                if (_useAdvancedFiltering)
                                  Chip(
                                    label: Text('Advanced Filters'),
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    deleteIcon: const Icon(Icons.clear, size: 16),
                                    onDeleted: () {
                                      setState(() {
                                        _useAdvancedFiltering = false;
                                      });
                                    },
                                  ),
                                  
                                if (_isMultiSelectMode)
                                  Chip(
                                    label: Text('${_selectedUserIds.length} selected'),
                                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
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
                                    if (_totalHoursCondition == 'atLeast' && _minimumTotalHours > 0)
                                      _buildFilterIndicator('Total ≥ ${_minimumTotalHours.toStringAsFixed(1)}'),
                                    if (_totalHoursCondition == 'atMost' && _maximumTotalHours < 50)
                                      _buildFilterIndicator('Total ≤ ${_maximumTotalHours.toStringAsFixed(1)}'),
                                    if (_totalHoursCondition == 'between' && (_minimumTotalHours > 0 || _maximumTotalHours < 50))
                                      _buildFilterIndicator('${_minimumTotalHours.toStringAsFixed(1)} ≤ Total ≤ ${_maximumTotalHours.toStringAsFixed(1)}'),
                                    
                                    // Service hours indicators
                                    if (_serviceHoursCondition == 'atLeast' && _minimumServiceHours > 0)
                                      _buildFilterIndicator('Service ≥ ${_minimumServiceHours.toStringAsFixed(1)}'),
                                    if (_serviceHoursCondition == 'atMost' && _maximumServiceHours < 25)
                                      _buildFilterIndicator('Service ≤ ${_maximumServiceHours.toStringAsFixed(1)}'),
                                    if (_serviceHoursCondition == 'between' && (_minimumServiceHours > 0 || _maximumServiceHours < 25))
                                      _buildFilterIndicator('${_minimumServiceHours.toStringAsFixed(1)} ≤ Service ≤ ${_maximumServiceHours.toStringAsFixed(1)}'),
                                    
                                    // Tutoring hours indicators
                                    if (_tutoringHoursCondition == 'atLeast' && _minimumTutoringHours > 0)
                                      _buildFilterIndicator('Tutoring ≥ ${_minimumTutoringHours.toStringAsFixed(1)}'),
                                    if (_tutoringHoursCondition == 'atMost' && _maximumTutoringHours < 25)
                                      _buildFilterIndicator('Tutoring ≤ ${_maximumTutoringHours.toStringAsFixed(1)}'),
                                    if (_tutoringHoursCondition == 'between' && (_minimumTutoringHours > 0 || _maximumTutoringHours < 25))
                                      _buildFilterIndicator('${_minimumTutoringHours.toStringAsFixed(1)} ≤ Tutoring ≤ ${_maximumTutoringHours.toStringAsFixed(1)}'),
                                    
                                    // Graduation year indicators
                                    if (_filterGraduationYear.isNotEmpty)
                                      _buildFilterIndicator(
                                        _graduationYearCondition == 'equals' ? 'Year: $_filterGraduationYear' :
                                        _graduationYearCondition == 'before' ? 'Year < $_filterGraduationYear' :
                                        'Year > $_filterGraduationYear'
                                      ),
                                      
                                    // Dues status indicator
                                    if (_filterByDues)
                                      _buildFilterIndicator('Dues: ${_showPaidDues ? 'Paid' : 'Unpaid'}'),
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
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No members match your search'
                                          : 'No members to display',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _fetchUsers,
                                child: isWideScreen
                                    ? _buildUserTable(filteredUsers)  // Table view for wide screens
                                    : _buildUserCardList(filteredUsers)  // Card list for mobile
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
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

  Widget _buildFilterSlider(
    String label, 
    double value, 
    double min, 
    double max, 
    Function(double) onChanged
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(value.toStringAsFixed(1)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt() * 2,
            label: value.toStringAsFixed(1),
            onChanged: onChanged,
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
                    value: _selectedUserIds.length == users.length && users.isNotEmpty,
                    tristate: _selectedUserIds.isNotEmpty && _selectedUserIds.length < users.length,
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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                child: Text(
                                  user.name.isNotEmpty ? user.name[0] : '?',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
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
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                hoursText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        Expanded(
                          child: Center(
                            child: IconButton(
                              icon: Icon(
                                user.hasPaidDues ? Icons.check_circle : Icons.cancel,
                                color: user.hasPaidDues ? Colors.green : Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () => _toggleDuesStatus(user),
                            ),
                          ),
                        ),
                        
                        // Actions column
                        SizedBox(
                          width: 100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add),
                                tooltip: 'Add Hours',
                                onPressed: () {
                                  _openCustomEventForm(context, user.id);
                                },
                                constraints: const BoxConstraints(),
                                padding: AppDesign.paddingSmall,
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_vert),
                                tooltip: 'More Options',
                                onPressed: () {
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
  
  // Copy selected user information to clipboard
  void _copySelectedUserInfo(bool copyEmails) async {
    if (_selectedUserIds.isEmpty) return;
    
    final List<String> result = [];
    final selectedUsers = _users.where((u) => _selectedUserIds.contains(u.id)).toList();
    
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
    
    // Copy to clipboard and show confirmation
    final clipboardText = result.join('\n');
    // In a real implementation, you would use Flutter's clipboard package here
    // For this example, we'll just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.length} ${copyEmails ? 'emails' : 'names'} copied to clipboard'
        ),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }
  
  // Export only selected users to Excel
  void _exportSelectedUsers() {
    if (_selectedUserIds.isEmpty) return;
    
    setState(() => _isExporting = true);
    
    final selectedUsers = _users.where((u) => _selectedUserIds.contains(u.id)).toList();
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
  
  // Existing implementation
  Widget _buildUserCard(UserProfile user) {
    // Get society requirements from provider
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
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
        hoursByType[normalizedType] = (hoursByType[normalizedType] ?? 0) + hour.hours;
        totalHours += hour.hours;
      } else if (typeAbbreviations.keys.any((k) => normalizeType(k) == normalizedType)) {
        // Try to find a matching type with different capitalization
        final matchingType = typeAbbreviations.keys.firstWhere(
          (k) => normalizeType(k) == normalizedType,
          orElse: () => normalizedType,
        );
        hoursByType[matchingType] = (hoursByType[matchingType] ?? 0) + hour.hours;
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
    final List<CompletedUserHour> filteredHours = _selectedHourType != null && _selectedHourType != 'All'
        ? user.completedHours.where((hour) => 
            normalizeType(hour.type) == normalizeType(_selectedHourType!)).toList()
        : user.completedHours;

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppDesign.borderXLarge,
      ),
      elevation:  _isMultiSelectMode && _selectedUserIds.contains(user.id) ? 4 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CustomExpansionTile(
        title: ListTile(
          title: Text(
            user.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.0,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hoursText.toString(),
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Graduation Year: ${user.graduationYear}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onDoubleTap: () => _toggleDuesStatus(user),
                child: Icon(
                  user.hasPaidDues ? Icons.check_circle : Icons.cancel,
                  color: user.hasPaidDues ? Colors.green : Theme.of(context).colorScheme.error,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  _openCustomEventForm(context, user.id);
                },
              ),
            ],
          ),
        ),
        children: filteredHours.map((hour) {
          return ListTile(
            title: Text(
              hour.eventName,
              style: TextStyle(
                fontSize: 16.0,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            subtitle: Text(
              '${hour.hours} hours - ${hour.type}',
              style: TextStyle(
                fontSize: 14.0,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
              trailing: Row( // Use Row for multiple trailing icons
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 25), // Edit Icon
                      tooltip: 'Edit Hour',
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () {
                        // Show the edit dialog
                        _showEditHourDialog(context, user, hour);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 25), // Keep delete icon
                      color: Theme.of(context).colorScheme.primary,
                      tooltip: 'Delete Hour',
                      onPressed: () {
                        _deleteServiceHour(hour, user.id); // Keep existing delete logic
                      },
                       padding: EdgeInsets.zero,
                       constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
        }).toList(),
      ),
    );
  }

  void _showEditHourDialog(BuildContext context, UserProfile user, CompletedUserHour hour) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      // Use a Builder to get a context that is under the Dialog's context
      return Builder(
        builder: (builderContext) {
          return AlertDialog(
            title: Text('Edit Service Hour for ${user.name}'),
            content: _EditHourDialogContent(
              hour: hour,
              availableTypes: _availableHourTypes, // Pass available types
              onSave: () {
                Navigator.of(builderContext).pop(); // Close dialog first
                _fetchUsers(); // Then refresh data
              },
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(builderContext).pop();
                },
              ),
              // The save button is now inside the dialog content
            ],
          );
        }
      );
    },
  );
}

  // Update the sort options list to be dynamic
  Widget _buildSortOptionsList() {
    // Always include these basic sort options
    final List<Widget> options = [
      _buildSortOptionTile(SortField.name, 'Name'),
      _buildSortOptionTile(SortField.totalHours, 'Total Hours'),
      _buildSortOptionTile(SortField.graduationYear, 'Graduation Year'), // New sort option
    ];
    
    // Get society to determine which hour types to include
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society != null) {
      // If a specific type is selected, only show that one
      if (_selectedHourType != null && _selectedHourType != 'All') {
        options.add(_buildSortOptionTile(SortField.serviceHours, '$_selectedHourType Hours'));
      } else {
        // Otherwise show for each active requirement type
        // Always include Meeting hours
        options.add(_buildSortOptionTile(SortField.meetingHours, 'Meeting Hours'));
        
        // Add option for each active requirement type
        for (final req in society.hourRequirements) {
          if (req.isActive && req.type != 'Meeting') {
            options.add(_buildSortOptionTile(
              // We'll still use serviceHours or tutoringHours as the enum value,
              // but the display name will match the requirement type
              req.type.toLowerCase().contains('tutor') 
                  ? SortField.tutoringHours 
                  : SortField.serviceHours,
              '${req.type} Hours'
            ));
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
                  Navigator.pop(context);
                  _openCustomEventForm(context, user.id);
                },
              ),
              ListTile(
                leading: Icon(
                  user.hasPaidDues ? Icons.cancel : Icons.check_circle,
                  color: user.hasPaidDues ? Theme.of(context).colorScheme.error : Colors.green,
                ),
                title: Text(user.hasPaidDues ? 'Mark Dues Unpaid' : 'Mark Dues Paid'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleDuesStatus(user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('View All Hours'),
                onTap: () {
                  Navigator.pop(context);
                  _showUserDetailsDialog(user);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Show detailed user information
  void _showUserDetailsDialog(UserProfile user) {
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
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
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Icon(
                                  user.hasPaidDues ? Icons.check_circle : Icons.cancel,
                                  color: user.hasPaidDues ? Colors.green : Theme.of(context).colorScheme.error,
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
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Hour summary
                Padding(
                  padding: AppDesign.paddingMedium,
                  child:_buildHourTypeCards(user),
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
                              ...hoursByType.values.map((hours) => _buildHoursList(hours)),
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
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
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
  Widget _buildHourSummaryCard(String title, String hours, IconData icon, Color color) {
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
            color: Colors.grey[600],
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

  // Helper to get icon for hour type - dynamic based on type name
  IconData _getIconForHourType(String type) {
    final normalizedType = type.toLowerCase();
    if (normalizedType.contains('service') || normalizedType.contains('volunteer')) 
      return Icons.volunteer_activism;
    if (normalizedType.contains('tutor') || normalizedType.contains('teach')) 
      return Icons.school;
    if (normalizedType.contains('meet')) 
      return Icons.groups;
    if (normalizedType.contains('lead') || normalizedType.contains('officer')) 
      return Icons.emoji_people;
    if (normalizedType.contains('fund') || normalizedType.contains('donat')) 
      return Icons.attach_money;
    
    // Default icon if no match
    return Icons.watch_later;
  }

  // Helper to get color for hour type
  Color _getColorForHourType(String type, BuildContext context) {
    // Use the society's categories to determine colors systematically
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return Theme.of(context).colorScheme.primary;
    
    final normalizedType = type.toLowerCase();
    
    // Meeting is special
    if (normalizedType.contains('meet')) 
      return Theme.of(context).colorScheme.tertiary;
    
    // Build color palette based on requirement index
    final List<Color> palette = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Colors.amber,
      Colors.teal,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
    ];
    
    // Find index of requirement
    int index = society.hourRequirements.indexWhere(
      (req) => normalizeType(req.type) == normalizeType(type)
    );
    
    // Default to primary if not found
    if (index == -1) return Theme.of(context).colorScheme.primary;
    
    // Return color from palette, wrapping around if needed
    return palette[index % palette.length];
  }
  
  // Existing method for order chip
  Widget _buildOrderChip(SortOrder order, String label, StateSetter setState) {
    return FilterChip(
      selected: _sortOrder == order,
      label: Text(label),
      onSelected: (selected) {
        if (selected) {
          this.setState(() => _sortOrder = order);
        }
      },
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDesign.radiusXLarge)),
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
                            setState(() => _selectedHourType = selected ? type : null);
                            this.setState(() {}); // Update main screen
                          },
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

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Custom Event'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: eventName,
                  decoration: const InputDecoration(labelText: 'Event Name'),
                  onChanged: (value) {
                    eventName = value;
                  },
                ),
                Padding(
                    padding: AppDesign.paddingLarge,
                    child: ElevatedButton(
                      child: Center(
                        child: Text(selectedTime != null
                            ? selectedTime.format(context)
                            : 'Select Time'),
                      ),
                      onPressed: () async {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          // Rebuild the dialog with the selected time and preserved form data
                          Navigator.of(context).pop();
                          _openCustomEventForm(context, userId,
                              eventName: eventName,
                              selectedTime: pickedTime,
                              hours: hours,
                              type: type);
                        }
                      },
                    )),
                TextFormField(
                  initialValue: hours.toString(),
                  decoration: const InputDecoration(labelText: 'Hours'),
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                  onChanged: (value) {
                    hours = double.tryParse(value) ?? 0.0;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: type,
                  onChanged: (value) {
                    setState(() {
                      type = value;
                    });
                  },
                  borderRadius: AppDesign.borderXLarge,
                  dropdownColor: Theme.of(context).colorScheme.primaryContainer,
                  items: availableTypes
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Event Type',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select an event type';
                    }
                    return null;
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                child: const Text('Save'),
                onPressed: () {
                  if (selectedTime != null && type != null) {
                    String timeSlot =
                        '${selectedTime.hour}:${selectedTime.minute}';
                    _saveCustomEvent(
                        userId,
                        eventName,
                        timeSlot,
                        hours.toDouble(),
                        type ?? "Meeting"); // Use selected type
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _deleteServiceHour(CompletedUserHour hour, String userId) async {
    await logactivity(
      hour.eventName,
      'N/A',
      hour.hours,
      'manual_deletion',
      userId,
    );

    await Supabase.instance.client
        .from('Service hours')
        .delete()
        .eq('event_name', hour.eventName)
        .eq('user_id', userId);

    _fetchUsers();
  }

  void _openBulkCustomEventForm(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkCustomEventFormPage(users: _users),
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
  final VoidCallback onSave;

  const _EditHourDialogContent({
    Key? key,
    required this.hour,
    required this.availableTypes,
    required this.onSave,
  }) : super(key: key);

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
    _hoursController = TextEditingController(text: widget.hour.hours.toString());
    _selectedType = widget.hour.type;

    // Ensure the current type is available, otherwise default to the first available
    if (!widget.availableTypes.contains(_selectedType)) {
      _selectedType = widget.availableTypes.isNotEmpty ? widget.availableTypes.firstWhere((t) => t != 'All', orElse: () => 'Service') : 'Service';
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _saveHourChanges() async {
    if (!_formKey.currentState!.validate()) {
      return; // Don't proceed if form is invalid
    }
    if (_isSaving) return; // Prevent double submission

    setState(() => _isSaving = true);

    final newEventName = _eventNameController.text.trim();
    final newHours = double.tryParse(_hoursController.text.trim()) ?? 0.0;
    final newType = _selectedType;

    try {
      await supabase
          .from('Service hours')
          .update({
            'event_name': newEventName,
            'hours': newHours,
            'type': newType,
          })
          .eq('id', widget.hour.id ?? 0); // Use the hour's ID to update

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hour updated successfully!'),
          ),
        );
        widget.onSave(); // Call the callback to close dialog and refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating hour: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter out 'All' from dropdown types
    final dropdownTypes = widget.availableTypes.where((t) => t != 'All').toList();
    // Ensure the selected type is still valid after filtering
    if (!dropdownTypes.contains(_selectedType) && dropdownTypes.isNotEmpty) {
       _selectedType = dropdownTypes.first;
    } else if (dropdownTypes.isEmpty){
      // Handle case where no types are available (should ideally not happen if 'Service' is default)
      _selectedType = 'Service';
      if(!dropdownTypes.contains('Service')) dropdownTypes.add('Service'); // Add Service if missing
    }


    return Form(
      key: _formKey,
      child: SingleChildScrollView( // Make content scrollable if needed
        child: Column(
          mainAxisSize: MainAxisSize.min, // Important for dialog content
          children: <Widget>[
            TextFormField(
              controller: _eventNameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an event name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hoursController,
              decoration: const InputDecoration(
                labelText: 'Hours',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')), // Allow numbers and decimal
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter hours';
                }
                final hours = double.tryParse(value.trim());
                if (hours == null || hours <= 0) {
                  return 'Please enter a valid positive number for hours';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
             if (dropdownTypes.isNotEmpty) // Only show dropdown if there are types
              DropdownButtonFormField<String>(
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
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an event type';
                  }
                  return null;
                },
              )
            else // Show a disabled field or message if no types available
              TextFormField(
                initialValue: _selectedType, // Show current type
                enabled: false, // Disable editing
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveHourChanges,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48), // Make button larger
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}