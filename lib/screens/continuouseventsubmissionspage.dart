import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/app_design.dart';
import '../common/app_widgets.dart';
import '../models/continuousevent.dart';
import '../models/continuouseventsubmission.dart';
import '../models/logactivity.dart';
import '../providers/hapticsprovider.dart';

final _supabase = Supabase.instance.client;

class ContinuousEventSubmissionsPage extends StatefulWidget {
  final ContinuousEvent event;

  const ContinuousEventSubmissionsPage({super.key, required this.event});

  @override
  State<ContinuousEventSubmissionsPage> createState() =>
      _ContinuousEventSubmissionsPageState();
}

class _ContinuousEventSubmissionsPageState
    extends State<ContinuousEventSubmissionsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<ContinuousEventSubmission> _submissions = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchSubmissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSubmissions() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _supabase
          .from('continuous_event_submissions')
          .select()
          .eq('continuous_event_id', widget.event.id)
          .order('created_at', ascending: false);

      final list = (rows as List).cast<Map<String, dynamic>>();

      // user_id references auth.users, so PostgREST can't embed profiles
      // directly — fetch the names in a second query and merge them in.
      final userIds =
          list.map((r) => r['user_id'] as String).toSet().toList();
      if (userIds.isNotEmpty) {
        final profileRows = await _supabase
            .from('profiles')
            .select('user_id, name')
            .inFilter('user_id', userIds);
        final nameById = {
          for (final p in (profileRows as List))
            p['user_id'] as String: p['name'] as String?
        };
        for (final r in list) {
          r['profiles'] = {'name': nameById[r['user_id']]};
        }
      }

      _submissions =
          list.map((r) => ContinuousEventSubmission.fromJson(r)).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load submissions: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ContinuousEventSubmission> _filterByStatus(String status) {
    final q = _searchQuery.trim().toLowerCase();
    return _submissions.where((s) {
      if (s.status != status) return false;
      if (q.isEmpty) return true;
      return (s.userName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  // Counts ignore the search query so the tab labels stay stable.
  int _countByStatus(String status) =>
      _submissions.where((s) => s.status == status).length;

  Future<void> _approve(ContinuousEventSubmission s) async {
    final haptics = Provider.of<HapticsProvider>(context, listen: false);
    final reviewerId = _supabase.auth.currentUser?.id;
    if (reviewerId == null) return;

    try {
      final inserted = await _supabase.from('Service hours').insert({
        'user_id': s.userId,
        'event_name': widget.event.name,
        'hours': s.hours,
        'date': s.activityDate.toIso8601String(),
        'type': widget.event.type,
        'society_id': widget.event.societyId,
      }).select('id').single();

      final serviceHoursId = (inserted['id'] as num).toInt();

      await _supabase.from('continuous_event_submissions').update({
        'status': 'approved',
        'reviewer_id': reviewerId,
        'reviewed_at': DateTime.now().toIso8601String(),
        'service_hours_id': serviceHoursId,
      }).eq('id', s.id);

      await logactivity(
        widget.event.name,
        '',
        s.hours,
        'continuous_submission_approved',
        s.userId,
        societyId: widget.event.societyId,
      );

      haptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission approved')),
        );
      }
      await _fetchSubmissions();
    } catch (e) {
      haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approve failed: $e')),
        );
      }
    }
  }

  Future<void> _reject(ContinuousEventSubmission s) async {
    final haptics = Provider.of<HapticsProvider>(context, listen: false);
    final reviewerId = _supabase.auth.currentUser?.id;
    if (reviewerId == null) return;

    final reason = await _promptForReason();
    if (reason == null) return;

    try {
      await _supabase.from('continuous_event_submissions').update({
        'status': 'rejected',
        'reviewer_id': reviewerId,
        'reviewer_notes': reason.isEmpty ? null : reason,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', s.id);

      await logactivity(
        widget.event.name,
        '',
        s.hours,
        'continuous_submission_rejected',
        s.userId,
        societyId: widget.event.societyId,
      );

      haptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission rejected')),
        );
      }
      await _fetchSubmissions();
    } catch (e) {
      haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reject failed: $e')),
        );
      }
    }
  }

  Future<void> _undo(ContinuousEventSubmission s) async {
    final haptics = Provider.of<HapticsProvider>(context, listen: false);

    try {
      if (s.isApproved && s.serviceHoursId != null) {
        await _supabase
            .from('Service hours')
            .delete()
            .eq('id', s.serviceHoursId!);
      }

      await _supabase.from('continuous_event_submissions').update({
        'status': 'pending',
        'reviewer_id': null,
        'reviewer_notes': null,
        'reviewed_at': null,
        'service_hours_id': null,
      }).eq('id', s.id);

      await logactivity(
        widget.event.name,
        '',
        s.hours,
        'continuous_submission_undone',
        s.userId,
        societyId: widget.event.societyId,
      );

      haptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review undone — back to pending')),
        );
      }
      await _fetchSubmissions();
    } catch (e) {
      haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Undo failed: $e')),
        );
      }
    }
  }

  Future<String?> _promptForReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reject submission'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'Shown to the member',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openProof(String urlStr) async {
    final haptics = Provider.of<HapticsProvider>(context, listen: false);
    haptics.selection();
    try {
      final uri = Uri.parse(urlStr);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open: $urlStr')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid link: $urlStr')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Submissions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              widget.event.name,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Pending (${_countByStatus('pending')})'),
            Tab(text: 'Approved (${_countByStatus('approved')})'),
            Tab(text: 'Rejected (${_countByStatus('rejected')})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppDesign.spacingM, AppDesign.spacingS,
                      AppDesign.spacingM, 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search by member name',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: AppDesign.borderMedium,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchSubmissions,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(_filterByStatus('pending'), 'pending'),
                        _buildList(_filterByStatus('approved'), 'approved'),
                        _buildList(_filterByStatus('rejected'), 'rejected'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildList(List<ContinuousEventSubmission> list, String status) {
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 96),
            child: Center(
              child: Text(
                'No $status submissions',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ],
      );
    }

    // Pending submissions get the full card with proof + approve/reject;
    // reviewed (approved/rejected) ones use a compact tile.
    if (status == 'pending') {
      return ListView.builder(
        padding: AppDesign.paddingMedium,
        itemCount: list.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: AppDesign.spacingM),
          child: _buildSubmissionCard(list[i]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spacingM, vertical: AppDesign.spacingS),
      itemCount: list.length,
      itemBuilder: (context, i) => _buildCompactSubmissionTile(list[i]),
    );
  }

  Widget _buildCompactSubmissionTile(ContinuousEventSubmission s) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat.yMMMd();
    final isApproved = s.isApproved;
    final accent = isApproved ? Colors.green : scheme.error;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppDesign.spacingS),
      shape: RoundedRectangleBorder(
        borderRadius: AppDesign.borderMedium,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: accent.withOpacity(0.15),
          child: Icon(isApproved ? Icons.check : Icons.close,
              size: 16, color: accent),
        ),
        title: Text(
          s.userName ?? 'Unknown member',
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${s.hours} hr • ${dateFmt.format(s.activityDate)}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Open proof link',
              icon: const Icon(Icons.link, size: 20),
              onPressed: () => _openProof(s.proofLink),
            ),
            TextButton(
              onPressed: () => _undo(s),
              child: const Text('Undo'),
            ),
          ],
        ),
        onTap: (s.isRejected &&
                s.reviewerNotes != null &&
                s.reviewerNotes!.isNotEmpty)
            ? () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Rejection reason'),
                    content: Text(s.reviewerNotes!),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                )
            : null,
      ),
    );
  }

  Widget _buildSubmissionCard(ContinuousEventSubmission s) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat.yMMMd();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  (s.userName ?? '?').substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppDesign.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.userName ?? 'Unknown member',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Submitted ${dateFmt.format(s.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: AppDesign.borderRound,
                ),
                child: Text(
                  '${s.hours} hr',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.spacingM),
          Row(
            children: [
              Icon(Icons.event, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('Activity date: ${dateFmt.format(s.activityDate)}'),
            ],
          ),
          if (s.notes != null && s.notes!.isNotEmpty) ...[
            const SizedBox(height: AppDesign.spacingS),
            Container(
              width: double.infinity,
              padding: AppDesign.paddingSmall,
              decoration: BoxDecoration(
                color: scheme.surfaceVariant.withOpacity(0.4),
                borderRadius: AppDesign.borderSmall,
              ),
              child: Text(s.notes!),
            ),
          ],
          const SizedBox(height: AppDesign.spacingS),
          ActionChip(
            avatar: const Icon(Icons.link, size: 18),
            label: const Text('Open proof link'),
            onPressed: () => _openProof(s.proofLink),
          ),
          if (s.isRejected &&
              s.reviewerNotes != null &&
              s.reviewerNotes!.isNotEmpty) ...[
            const SizedBox(height: AppDesign.spacingS),
            Container(
              width: double.infinity,
              padding: AppDesign.paddingSmall,
              decoration: BoxDecoration(
                color: scheme.errorContainer.withOpacity(0.4),
                borderRadius: AppDesign.borderSmall,
              ),
              child: Text('Review note: ${s.reviewerNotes!}'),
            ),
          ],
          const SizedBox(height: AppDesign.spacingM),
          _buildActionRow(s),
        ],
      ),
    );
  }

  Widget _buildActionRow(ContinuousEventSubmission s) {
    if (s.isPending) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
              onPressed: () => _reject(s),
            ),
          ),
          const SizedBox(width: AppDesign.spacingS),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
              onPressed: () => _approve(s),
            ),
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        icon: const Icon(Icons.undo),
        label: const Text('Undo'),
        onPressed: () => _undo(s),
      ),
    );
  }
}
