import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/societyprovider.dart';
import '../data/supabase_client.dart';
import '../common/app_design.dart';
import '../common/app_widgets.dart';
import '../common/nhsformatutils.dart';
import '../providers/hapticsprovider.dart';

enum RequestSortField {
  name,
  graduationYear,
  status,
  requestedAt,
  processedAt,
}

enum RequestSortOrder {
  ascending,
  descending,
}

/// Page to manage join requests for a society's admin
class JoinRequestsAdminPage extends StatefulWidget {
  const JoinRequestsAdminPage({Key? key}) : super(key: key);

  @override
  _JoinRequestsAdminPageState createState() => _JoinRequestsAdminPageState();
}

class _JoinRequestsAdminPageState extends State<JoinRequestsAdminPage>
    with SingleTickerProviderStateMixin {
  List<JoinRequest> _requests = [];
  bool _isLoading = true;
  bool _isBusy = false;
  late TabController _tabController;

  RequestSortField _sortField = RequestSortField.requestedAt;
  RequestSortOrder _sortOrder = RequestSortOrder.descending;

  // Multi-select functionality
  bool _isSelectionMode = false;
  Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _fetchJoinRequests();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  // Selection is per-tab: leaving a tab drops what was picked there.
  void _onTabChanged() {
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  // ---- Derived lists ----

  List<JoinRequest> get _pendingRequests =>
      _sorted(_requests.where((r) => r.status == 'pending'));

  List<JoinRequest> get _processedRequests =>
      _sorted(_requests.where((r) => r.status != 'pending'));

  bool get _isPendingTab => _tabController.index == 0;

  List<JoinRequest> get _visibleRequests =>
      _isPendingTab ? _pendingRequests : _processedRequests;

  List<JoinRequest> get _selectedRequests =>
      _visibleRequests.where((r) => _selectedIds.contains(r.id)).toList();

  List<JoinRequest> _sorted(Iterable<JoinRequest> requests) {
    final list = requests.toList();
    list.sort((a, b) {
      int comparison;
      switch (_sortField) {
        case RequestSortField.name:
          comparison =
              a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
          break;
        case RequestSortField.graduationYear:
          // Members without a year on file sort last in ascending order.
          comparison = _gradYearValue(a).compareTo(_gradYearValue(b));
          break;
        case RequestSortField.status:
          comparison = _statusRank(a.status).compareTo(_statusRank(b.status));
          break;
        case RequestSortField.requestedAt:
          comparison = a.requestedAt.compareTo(b.requestedAt);
          break;
        case RequestSortField.processedAt:
          final aProcessed =
              a.processedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bProcessed =
              b.processedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          comparison = aProcessed.compareTo(bProcessed);
          break;
      }

      // Stable, predictable tiebreak so equal keys don't shuffle between builds.
      if (comparison == 0) {
        comparison =
            a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
      }
      if (comparison == 0) comparison = a.id.compareTo(b.id);

      return _sortOrder == RequestSortOrder.ascending
          ? comparison
          : -comparison;
    });
    return list;
  }

  int _gradYearValue(JoinRequest request) =>
      int.tryParse(request.graduationYear) ?? 9999;

  int _statusRank(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'approved':
        return 1;
      case 'rejected':
        return 2;
      case 'revoked':
        return 3;
      default:
        return 4;
    }
  }

  String _sortFieldLabel(RequestSortField field) {
    switch (field) {
      case RequestSortField.name:
        return 'Name';
      case RequestSortField.graduationYear:
        return 'Graduation Year';
      case RequestSortField.status:
        return 'Status';
      case RequestSortField.requestedAt:
        return 'Date Requested';
      case RequestSortField.processedAt:
        return 'Date Processed';
    }
  }

  // ---- Data ----

  Future<void> _fetchJoinRequests() async {
    setState(() => _isLoading = true);

    try {
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;

      if (society == null) {
        if (mounted) {
          setState(() {
            _requests = [];
            _isLoading = false;
          });
        }
        return;
      }

      final joinRequestsResponse = await supabase
          .from('society_join_requests')
          .select()
          .eq('society_id', society.id)
          .order('requested_at', ascending: false);

      // Collect every user_id we need to resolve (requesters + processors)
      // and fetch them all in a single batched query instead of N+1.
      final Set<String> userIds = {};
      for (final req in joinRequestsResponse) {
        if (req['user_id'] != null) userIds.add(req['user_id'] as String);
        if (req['processed_by'] != null) {
          userIds.add(req['processed_by'] as String);
        }
      }

      final Map<String, Map<String, dynamic>> profilesById = {};
      if (userIds.isNotEmpty) {
        final profilesResponse = await supabase
            .from('profiles')
            .select('user_id, name, email, graduation_year')
            .inFilter('user_id', userIds.toList());
        for (final p in profilesResponse) {
          profilesById[p['user_id'] as String] = p;
        }
      }

      final List<JoinRequest> requests = [];

      for (final req in joinRequestsResponse) {
        final requester = profilesById[req['user_id']];
        final processor = req['processed_by'] != null
            ? profilesById[req['processed_by']]
            : null;

        requests.add(JoinRequest(
          id: req['id'],
          status: req['status'],
          userId: req['user_id'],
          userName: requester?['name'] ?? 'Unknown User',
          userEmail: requester?['email'] ?? 'No email',
          graduationYear: requester?['graduation_year']?.toString() ?? '',
          requestedAt: DateTime.parse(req['requested_at']),
          processedAt: req['processed_at'] != null
              ? DateTime.parse(req['processed_at'])
              : null,
          processorName: processor?['name'] as String?,
        ));
      }

      if (mounted) {
        setState(() {
          _requests = requests;
          // Drop selections pointing at rows that no longer exist.
          _selectedIds = _selectedIds
              .where((id) => requests.any((r) => r.id == id))
              .toSet();
          if (_selectedIds.isEmpty) _isSelectionMode = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error fetching join requests: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  // ---- Actions ----

  /// Approves or rejects every still-pending request in [targets].
  Future<void> _processRequests(List<JoinRequest> targets, bool approve) async {
    if (_isBusy) return;
    final eligible = targets.where((r) => r.status == 'pending').toList();
    if (eligible.isEmpty) {
      _showMessage('Nothing to ${approve ? 'approve' : 'reject'}');
      return;
    }

    setState(() => _isBusy = true);

    try {
      final societyProvider =
          Provider.of<SocietyProvider>(context, listen: false);
      final society = societyProvider.currentSociety;
      if (society == null) {
        throw Exception('No society selected');
      }

      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not logged in');
      }

      final now = DateTime.now();
      final ids = eligible.map((r) => r.id).toList();

      await supabase.from('society_join_requests').update({
        'status': approve ? 'approved' : 'rejected',
        'processed_by': currentUserId,
        'processed_at': now.toIso8601String(),
      }).inFilter('id', ids);

      if (approve) {
        // Only insert memberships that don't exist yet — a user can hold more
        // than one pending request, and may already have been added by hand.
        final userIds = eligible.map((r) => r.userId).toSet().toList();
        final existing = await supabase
            .from('user_society_memberships')
            .select('user_id')
            .eq('society_id', society.id)
            .inFilter('user_id', userIds);
        final existingIds = {
          for (final row in existing) row['user_id'] as String
        };

        final newRows = [
          for (final userId in userIds)
            if (!existingIds.contains(userId))
              {
                'user_id': userId,
                'society_id': society.id,
                'is_admin': false, // New members are not admins by default
              }
        ];

        if (newRows.isNotEmpty) {
          await supabase.from('user_society_memberships').insert(newRows);
        }
      }

      if (!mounted) return;
      setState(() {
        _requests = _requests
            .map((r) => ids.contains(r.id)
                ? r.copyWith(
                    status: approve ? 'approved' : 'rejected',
                    processedAt: now,
                    processorName: 'You',
                  )
                : r)
            .toList();
        _clearSelection(ids);
      });

      // If approved, refresh the society provider to reflect new members
      if (approve) {
        await societyProvider.loadUserSocieties();
      }
      if (!mounted) return;

      Provider.of<HapticsProvider>(context, listen: false).success();
      final skipped = targets.length - eligible.length;
      _showMessage(
        '${_countLabel(eligible.length, 'request')} '
        '${approve ? 'approved' : 'rejected'}'
        '${skipped > 0 ? ' · $skipped already processed' : ''}',
        isPositive: approve,
      );
    } catch (e) {
      if (mounted) {
        Provider.of<HapticsProvider>(context, listen: false).error();
        _showMessage('Error processing requests: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Revokes membership for every approved request in [targets].
  Future<void> _removeMembers(List<JoinRequest> targets) async {
    if (_isBusy) return;
    final eligible = targets.where((r) => r.status == 'approved').toList();
    if (eligible.isEmpty) {
      _showMessage('Only approved members can be removed');
      return;
    }

    final confirmed = await _confirmAction(
      title: eligible.length == 1 ? 'Remove Member' : 'Remove Members',
      message: eligible.length == 1
          ? 'Are you sure you want to remove ${eligible.first.userName} from the honor society?'
          : 'Are you sure you want to remove these ${eligible.length} members from the honor society?',
      details: '• Remove their access to society events and activities\n'
          '• Preserve their completed service hours for records\n'
          '• Allow them to request to rejoin in the future',
      confirmLabel:
          eligible.length == 1 ? 'Remove Member' : 'Remove ${eligible.length}',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);

    try {
      final societyProvider =
          Provider.of<SocietyProvider>(context, listen: false);
      final society = societyProvider.currentSociety;
      if (society == null) {
        throw Exception('No society selected');
      }

      final currentUserId = supabase.auth.currentUser?.id;
      final now = DateTime.now();
      final ids = eligible.map((r) => r.id).toList();
      final userIds = eligible.map((r) => r.userId).toSet().toList();

      // Remove from society membership
      await supabase
          .from('user_society_memberships')
          .delete()
          .eq('society_id', society.id)
          .inFilter('user_id', userIds);

      // Mark the requests as revoked so the history reads correctly
      await supabase.from('society_join_requests').update({
        'status': 'revoked',
        'processed_by': currentUserId,
        'processed_at': now.toIso8601String(),
      }).inFilter('id', ids);

      if (!mounted) return;
      setState(() {
        _requests = _requests
            .map((r) => ids.contains(r.id)
                ? r.copyWith(
                    status: 'revoked',
                    processedAt: now,
                    processorName: 'You',
                  )
                : r)
            .toList();
        _clearSelection(ids);
      });

      await societyProvider.loadUserSocieties();
      if (!mounted) return;

      Provider.of<HapticsProvider>(context, listen: false).success();
      _showMessage(
        eligible.length == 1
            ? '${eligible.first.userName} has been removed from the society'
            : '${eligible.length} members removed from the society',
        isPositive: true,
      );
    } catch (e) {
      if (mounted) {
        Provider.of<HapticsProvider>(context, listen: false).error();
        _showMessage('Error removing members: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _clearSelection(List<int> ids) {
    _selectedIds.removeAll(ids);
    if (_selectedIds.isEmpty) _isSelectionMode = false;
  }

  String _countLabel(int count, String noun) =>
      '$count $noun${count == 1 ? '' : 's'}';

  void _showMessage(String message,
      {bool isError = false, bool isPositive = false}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? scheme.error
            : isPositive
                ? scheme.tertiary
                : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String details,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: AppDesign.borderLarge,
              ),
              icon: Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 32,
              ),
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppDesign.spacingM),
                  Container(
                    padding: AppDesign.paddingMedium,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: 0.3),
                      borderRadius: AppDesign.borderMedium,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: AppDesign.spacingXS),
                            Text(
                              'This action will:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDesign.spacingXS),
                        Text(
                          details,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Provider.of<HapticsProvider>(context, listen: false)
                        .selection();
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Provider.of<HapticsProvider>(context, listen: false)
                        .selection();
                    Navigator.of(context).pop(true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Consumer<SocietyProvider>(
      builder: (context, societyProvider, _) {
        final society = societyProvider.currentSociety;

        if (societyProvider.isLoading || society == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: _isSelectionMode
              ? _buildSelectionAppBar()
              : _buildBrowseAppBar(society.name),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    AbsorbPointer(
                      absorbing: _isBusy,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRequestView(_pendingRequests, true,
                              isWideScreen: isWideScreen),
                          _buildRequestView(_processedRequests, false,
                              isWideScreen: isWideScreen),
                        ],
                      ),
                    ),
                    if (_isBusy)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
        );
      },
    );
  }

  // Default ("browse") bar: sort, enter selection mode, refresh.
  PreferredSizeWidget _buildBrowseAppBar(String societyName) {
    final haptics = Provider.of<HapticsProvider>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Membership Requests',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: scheme.onSurface,
            ),
          ),
          Text(
            societyName,
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort',
          onPressed: () {
            haptics.selection();
            _showSortOptions();
          },
        ),
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: 'Select requests',
          onPressed: _visibleRequests.isEmpty
              ? null
              : () {
                  haptics.selection();
                  setState(() => _isSelectionMode = true);
                },
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            haptics.selection();
            _fetchJoinRequests();
          },
          tooltip: 'Refresh',
        ),
      ],
      bottom: _buildTabBar(),
    );
  }

  // Contextual bar shown while selecting; hosts the bulk actions.
  PreferredSizeWidget _buildSelectionAppBar() {
    final haptics = Provider.of<HapticsProvider>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;
    final visible = _visibleRequests;
    final selected = _selectedRequests;
    final hasSelection = selected.isNotEmpty;
    final allSelected =
        visible.isNotEmpty && visible.every((r) => _selectedIds.contains(r.id));
    final canRemove = selected.any((r) => r.status == 'approved');

    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel',
        onPressed: () {
          haptics.selection();
          setState(() {
            _isSelectionMode = false;
            _selectedIds.clear();
          });
        },
      ),
      title: Text(
        hasSelection
            ? '${selected.length} selected'
            : 'Select ${_isPendingTab ? 'requests' : 'members'}',
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
                _selectedIds.clear();
              } else {
                _selectedIds = visible.map((r) => r.id).toSet();
              }
            });
          },
        ),
        if (_isPendingTab) ...[
          IconButton(
            icon: const Icon(Icons.check_circle),
            tooltip: 'Approve selected',
            onPressed: hasSelection
                ? () {
                    haptics.selection();
                    _processRequests(selected, true);
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.cancel),
            tooltip: 'Reject selected',
            onPressed: hasSelection
                ? () {
                    haptics.selection();
                    _processRequests(selected, false);
                  }
                : null,
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesign.spacingS),
            child: TextButton.icon(
              icon: const Icon(Icons.person_remove, size: 18),
              label: const Text('Remove from society'),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              onPressed: canRemove
                  ? () {
                      haptics.selection();
                      _removeMembers(selected);
                    }
                  : null,
            ),
          ),
      ],
      bottom: _buildTabBar(),
    );
  }

  PreferredSizeWidget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      tabs: [
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top),
              const SizedBox(width: 8),
              Text(_pendingRequests.isEmpty
                  ? 'Pending'
                  : 'Pending (${_pendingRequests.length})'),
            ],
          ),
        ),
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history),
              const SizedBox(width: 8),
              Text(_processedRequests.isEmpty
                  ? 'Processed'
                  : 'Processed (${_processedRequests.length})'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestView(List<JoinRequest> requests, bool isPending,
      {required bool isWideScreen}) {
    if (requests.isEmpty) {
      // Keep pull-to-refresh reachable even with nothing on screen.
      return RefreshIndicator(
        onRefresh: _fetchJoinRequests,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: _buildEmptyState(isPending),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSummaryBar(requests),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchJoinRequests,
            child: isWideScreen
                ? _buildRequestTable(requests, isPending)
                : _buildRequestCardList(requests, isPending),
          ),
        ),
      ],
    );
  }

  // Row count + the sort currently in effect, mirroring the Members page.
  Widget _buildSummaryBar(List<JoinRequest> requests) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16.0, vertical: AppDesign.spacingS),
      child: Row(
        children: [
          Text(
            _countLabel(requests.length, 'request'),
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          ActionChip(
            avatar: Icon(
              _sortOrder == RequestSortOrder.ascending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 16,
              color: scheme.primary,
            ),
            label: Text(_sortFieldLabel(_sortField)),
            backgroundColor:
                scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            onPressed: () {
              Provider.of<HapticsProvider>(context, listen: false).selection();
              _showSortOptions();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isPending) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: AppDesign.paddingLarge,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: AppDesign.paddingLarge,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: AppDesign.borderRound,
              ),
              child: Icon(
                isPending ? Icons.inbox : Icons.history,
                size: 64,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppDesign.spacingL),
            Text(
              isPending ? 'No pending requests' : 'No processed requests',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppDesign.spacingS),
            Text(
              isPending
                  ? 'When users request to join, they\'ll appear here'
                  : 'Approved and rejected requests will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---- Wide-screen spreadsheet ----

  Widget _buildRequestTable(List<JoinRequest> requests, bool isPending) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Table header
        Container(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              if (_isSelectionMode)
                SizedBox(
                  width: 48,
                  child: Checkbox(
                    value: _selectedIds.length == requests.length &&
                        requests.isNotEmpty,
                    tristate: _selectedIds.isNotEmpty &&
                        _selectedIds.length < requests.length,
                    onChanged: (checked) {
                      setState(() {
                        if (checked ?? false) {
                          _selectedIds = requests.map((r) => r.id).toSet();
                        } else {
                          _selectedIds.clear();
                        }
                      });
                    },
                  ),
                ),
              _buildSortableHeader('Name', RequestSortField.name, flex: 3),
              _buildSortableHeader(
                  'Graduation Year', RequestSortField.graduationYear,
                  flex: 2),
              if (!isPending)
                _buildSortableHeader('Status', RequestSortField.status,
                    flex: 2),
              _buildSortableHeader('Requested', RequestSortField.requestedAt,
                  flex: 2),
              if (!isPending)
                _buildSortableHeader('Processed', RequestSortField.processedAt,
                    flex: 3),
              const SizedBox(
                width: 150,
                child: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // Table body
        Expanded(
          child: ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final isSelected = _selectedIds.contains(request.id);

              return Container(
                color: isSelected
                    ? scheme.primaryContainer
                    : index.isEven
                        ? scheme.surface
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.2),
                child: InkWell(
                  onTap: () => _onRequestTap(request),
                  onLongPress: () => _onRequestLongPress(request),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        if (_isSelectionMode)
                          SizedBox(
                            width: 48,
                            child: Checkbox(
                              value: isSelected,
                              onChanged: (checked) => _toggleSelection(request),
                            ),
                          ),

                        // Name + email
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.userName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              Text(
                                request.userEmail,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),

                        // Graduation year
                        Expanded(
                          flex: 2,
                          child: Text(
                            request.graduationYear.isEmpty
                                ? '—'
                                : request.graduationYear,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),

                        // Status
                        if (!isPending)
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _buildStatusChip(request),
                            ),
                          ),

                        // Requested
                        Expanded(
                          flex: 2,
                          child: Text(
                            NhsFormatUtils.formatDate(request.requestedAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),

                        // Processed by / at
                        if (!isPending)
                          Expanded(
                            flex: 3,
                            child: Text(
                              request.processedAt == null
                                  ? '—'
                                  : '${NhsFormatUtils.formatDate(request.processedAt!)} · ${request.processorName ?? "Unknown"}',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),

                        // Actions
                        SizedBox(
                          width: 150,
                          child: Center(
                            child: _buildRowActions(request, isPending),
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

  Widget _buildSortableHeader(String label, RequestSortField field,
      {required int flex}) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = _sortField == field;

    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          Provider.of<HapticsProvider>(context, listen: false).selection();
          setState(() {
            if (isActive) {
              _sortOrder = _sortOrder == RequestSortOrder.ascending
                  ? RequestSortOrder.descending
                  : RequestSortOrder.ascending;
            } else {
              _sortField = field;
              _sortOrder = field == RequestSortField.requestedAt ||
                      field == RequestSortField.processedAt
                  ? RequestSortOrder.descending
                  : RequestSortOrder.ascending;
            }
          });
        },
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive ? scheme.primary : null,
                ),
              ),
            ),
            if (isActive)
              Icon(
                _sortOrder == RequestSortOrder.ascending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 16,
                color: scheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  // ---- Mobile card list ----

  Widget _buildRequestCardList(List<JoinRequest> requests, bool isPending) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppDesign.spacingL),
      itemCount: requests.length,
      itemBuilder: (context, index) =>
          _buildRequestCard(requests[index], isPending),
    );
  }

  Widget _buildRequestCard(JoinRequest request, bool isPending) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _selectedIds.contains(request.id);

    return AppContentCard(
      margin: const EdgeInsets.symmetric(
          horizontal: AppDesign.spacingM, vertical: AppDesign.spacingS),
      child: Material(
        color: isSelected
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        child: InkWell(
          onTap: () => _onRequestTap(request),
          onLongPress: () => _onRequestLongPress(request),
          child: Padding(
            padding: AppDesign.paddingMedium,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isSelectionMode)
                      Padding(
                        padding:
                            const EdgeInsets.only(right: AppDesign.spacingS),
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (checked) => _toggleSelection(request),
                        ),
                      ),

                    // Body
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.userName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            request.userEmail,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppDesign.spacingS),
                          Wrap(
                            spacing: AppDesign.spacingS,
                            runSpacing: AppDesign.spacingXS,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (request.graduationYear.isNotEmpty)
                                _buildMetaChip(Icons.school,
                                    'Class of ${request.graduationYear}'),
                              _buildMetaChip(Icons.access_time,
                                  _formatDateTime(request.requestedAt)),
                              if (!isPending) _buildStatusChip(request),
                            ],
                          ),
                          if (!isPending && request.processedAt != null) ...[
                            const SizedBox(height: AppDesign.spacingXS),
                            Text(
                              'By ${request.processorName ?? "Unknown"} · ${_formatDateTime(request.processedAt!)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Approve / reject sit inline — two taps, no labels needed
                    if (isPending && !_isSelectionMode)
                      _buildRowActions(request, isPending),
                  ],
                ),

                // Remove gets its own full-width row so the label always fits
                if (!isPending &&
                    !_isSelectionMode &&
                    request.status == 'approved') ...[
                  const SizedBox(height: AppDesign.spacingS),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildRowActions(request, isPending),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppDesign.borderSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(JoinRequest request) {
    final statusColor = _statusColor(request.status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spacingS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: AppDesign.borderSmall,
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(request.status), size: 14, color: statusColor),
          const SizedBox(width: 4),
          Text(
            _statusLabel(request.status),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Per-row actions, shared by the table and the cards so both stay in step.
  Widget _buildRowActions(JoinRequest request, bool isPending) {
    final haptics = Provider.of<HapticsProvider>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;

    if (isPending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            color: scheme.tertiary,
            tooltip: 'Approve',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              haptics.selection();
              _processRequests([request], true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cancel),
            color: scheme.error,
            tooltip: 'Reject',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              haptics.selection();
              _processRequests([request], false);
            },
          ),
        ],
      );
    }

    // Only members who are actually in the society can be removed; rejected and
    // already-removed rows are history with nothing left to act on.
    if (request.status != 'approved') return const SizedBox.shrink();

    return OutlinedButton.icon(
      icon: const Icon(Icons.person_remove, size: 18),
      label: const Text('Remove'),
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.error,
        side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () {
        haptics.selection();
        _removeMembers([request]);
      },
    );
  }

  // ---- Selection helpers ----

  void _onRequestTap(JoinRequest request) {
    Provider.of<HapticsProvider>(context, listen: false).selection();
    if (_isSelectionMode) _toggleSelection(request);
  }

  void _onRequestLongPress(JoinRequest request) {
    Provider.of<HapticsProvider>(context, listen: false).medium();
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(request.id);
    });
  }

  void _toggleSelection(JoinRequest request) {
    setState(() {
      if (_selectedIds.contains(request.id)) {
        _selectedIds.remove(request.id);
      } else {
        _selectedIds.add(request.id);
      }
    });
  }

  // ---- Sorting sheet ----

  void _showSortOptions() {
    final isPending = _isPendingTab;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDesign.radiusLarge)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void update(VoidCallback change) {
              setState(change);
              setSheetState(() {});
            }

            final fields = [
              RequestSortField.name,
              RequestSortField.graduationYear,
              RequestSortField.requestedAt,
              if (!isPending) RequestSortField.status,
              if (!isPending) RequestSortField.processedAt,
            ];

            return SafeArea(
              child: SingleChildScrollView(
                padding: AppDesign.paddingMedium,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppSectionHeader(
                      icon: Icons.sort,
                      title: 'Sort requests',
                    ),
                    const SizedBox(height: AppDesign.spacingS),
                    ...fields.map(
                      (field) => RadioListTile<RequestSortField>(
                        title: Text(_sortFieldLabel(field)),
                        value: field,
                        groupValue: _sortField,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          if (value == null) return;
                          Provider.of<HapticsProvider>(context, listen: false)
                              .selection();
                          update(() => _sortField = value);
                        },
                      ),
                    ),
                    const SizedBox(height: AppDesign.spacingS),
                    Text(
                      'Sort Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppDesign.spacingS),
                    Wrap(
                      spacing: AppDesign.spacingS,
                      children: [
                        _buildOrderChip(
                            RequestSortOrder.ascending, '↑ Ascending', update),
                        _buildOrderChip(RequestSortOrder.descending,
                            '↓ Descending', update),
                      ],
                    ),
                    const SizedBox(height: AppDesign.spacingM),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderChip(RequestSortOrder order, String label,
      void Function(VoidCallback) update) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: _sortOrder == order,
      onSelected: (_) {
        Provider.of<HapticsProvider>(context, listen: false).selection();
        update(() => _sortOrder = order);
      },
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  // ---- Status presentation ----

  Color _statusColor(String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'approved':
        return scheme.tertiary;
      case 'rejected':
      case 'revoked':
        return scheme.error;
      default:
        return scheme.primary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'revoked':
        return Icons.remove_circle;
      default:
        return Icons.hourglass_top;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      case 'revoked':
        return 'REMOVED';
      default:
        return 'PENDING';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return NhsFormatUtils.formatDate(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

/// Enhanced model class for join requests
class JoinRequest {
  final int id;
  final String status;
  final String userId;
  final String userName;
  final String userEmail;
  final String graduationYear;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? processorName;

  JoinRequest({
    required this.id,
    required this.status,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.graduationYear = '',
    required this.requestedAt,
    this.processedAt,
    this.processorName,
  });

  JoinRequest copyWith({
    String? status,
    DateTime? processedAt,
    String? processorName,
  }) {
    return JoinRequest(
      id: id,
      status: status ?? this.status,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      graduationYear: graduationYear,
      requestedAt: requestedAt,
      processedAt: processedAt ?? this.processedAt,
      processorName: processorName ?? this.processorName,
    );
  }

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'],
      status: json['status'],
      userId: json['user_id'],
      userName: json['userName'] ?? 'Unknown User',
      userEmail: json['userEmail'] ?? 'No email',
      graduationYear: json['graduation_year']?.toString() ?? '',
      requestedAt: DateTime.parse(json['requested_at']),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : null,
      processorName: json['processorName'],
    );
  }
}
