import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/app_design.dart';
import '../common/app_widgets.dart';
import '../common/iconutils.dart';
import '../models/continuousevent.dart';
import '../models/continuouseventstep.dart';
import '../models/continuouseventsubmission.dart';
import '../providers/hapticsprovider.dart';

final _supabase = Supabase.instance.client;

class ContinuousEventDetailPage extends StatefulWidget {
  final ContinuousEvent event;

  const ContinuousEventDetailPage({super.key, required this.event});

  @override
  State<ContinuousEventDetailPage> createState() =>
      _ContinuousEventDetailPageState();
}

class _ContinuousEventDetailPageState extends State<ContinuousEventDetailPage> {
  List<ContinuousEventSubmission> _mySubmissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMySubmissions();
  }

  Future<void> _fetchMySubmissions() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final rows = await _supabase
          .from('continuous_event_submissions')
          .select()
          .eq('continuous_event_id', widget.event.id)
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      _mySubmissions = (rows as List)
          .map((r) =>
              ContinuousEventSubmission.fromJson(r as Map<String, dynamic>))
          .toList();
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

  bool get _canLogHours {
    if (widget.event.allowMultipleSubmissions) return true;
    return !_mySubmissions.any((s) => s.isPending || s.isApproved);
  }

  Future<void> _openLink(String urlStr) async {
    Provider.of<HapticsProvider>(context, listen: false).selection();
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

  Future<void> _openLogHoursDialog({ContinuousEventSubmission? prefill}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => LogHoursDialog(event: widget.event, prefill: prefill),
    );
    if (result == true) {
      await _fetchMySubmissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final event = widget.event;

    return Scaffold(
      appBar: AppBar(
        title: Text(event.name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppDesign.paddingMedium,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primary.withOpacity(0.15),
                      child: Icon(getIconForType(event.type, context),
                          color: scheme.primary),
                    ),
                    const SizedBox(width: AppDesign.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(event.type,
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: AppDesign.spacingM),
                  AppSurfaceCard(child: Text(event.description)),
                ],
                const SizedBox(height: AppDesign.spacingL),
                _buildStepsSection(event.steps),
                const SizedBox(height: AppDesign.spacingL),
                _buildMySubmissionsSection(),
                const SizedBox(height: 80),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: AppDesign.paddingMedium,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: AppDesign.borderMedium),
            ),
            icon: const Icon(Icons.upload),
            label: Text(_canLogHours
                ? 'Log Hours'
                : 'Hours already submitted'),
            onPressed: _canLogHours ? () => _openLogHoursDialog() : null,
          ),
        ),
      ),
    );
  }

  Widget _buildStepsSection(List<ContinuousEventStep> steps) {
    if (steps.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Steps', icon: Icons.list_alt),
        const SizedBox(height: AppDesign.spacingS),
        ...steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          return _StepRow(
            index: i + 1,
            step: step,
            onOpen: step.link == null ? null : () => _openLink(step.link!),
          );
        }),
      ],
    );
  }

  Widget _buildMySubmissionsSection() {
    if (_mySubmissions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'My Submissions', icon: Icons.history),
        const SizedBox(height: AppDesign.spacingS),
        ..._mySubmissions.map((s) => _MySubmissionTile(
              submission: s,
              onResubmit: s.isRejected
                  ? () => _openLogHoursDialog(prefill: s)
                  : null,
              onShowReason: s.isRejected &&
                      s.reviewerNotes != null &&
                      s.reviewerNotes!.isNotEmpty
                  ? () {
                      showDialog<void>(
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
                      );
                    }
                  : null,
            )),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final ContinuousEventStep step;
  final VoidCallback? onOpen;

  const _StepRow({required this.index, required this.step, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              '$index',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: AppDesign.spacingM),
          Expanded(child: Text(step.description)),
          if (onOpen != null)
            IconButton(
              tooltip: 'Open link',
              icon: const Icon(Icons.open_in_new),
              onPressed: onOpen,
            ),
        ],
      ),
    );
  }
}

class _MySubmissionTile extends StatelessWidget {
  final ContinuousEventSubmission submission;
  final VoidCallback? onResubmit;
  final VoidCallback? onShowReason;

  const _MySubmissionTile(
      {required this.submission, this.onResubmit, this.onShowReason});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat.yMMMd();

    Color statusColor;
    String statusLabel;
    switch (submission.status) {
      case 'approved':
        statusColor = Colors.green;
        statusLabel = 'Approved';
        break;
      case 'rejected':
        statusColor = scheme.error;
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = scheme.primary;
        statusLabel = 'Pending';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AppSurfaceCard(
        padding: AppDesign.paddingMedium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${submission.hours} hr',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text('on ${dateFmt.format(submission.activityDate)}',
                    style:
                        TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: AppDesign.borderRound,
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (onShowReason != null || onResubmit != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onShowReason != null)
                    TextButton.icon(
                      onPressed: onShowReason,
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('See reason'),
                    ),
                  const Spacer(),
                  if (onResubmit != null)
                    ElevatedButton.icon(
                      onPressed: onResubmit,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Resubmit'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LogHoursDialog extends StatefulWidget {
  final ContinuousEvent event;
  final ContinuousEventSubmission? prefill;

  const LogHoursDialog({super.key, required this.event, this.prefill});

  @override
  State<LogHoursDialog> createState() => _LogHoursDialogState();
}

class _LogHoursDialogState extends State<LogHoursDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hoursCtl;
  late final TextEditingController _proofCtl;
  late final TextEditingController _notesCtl;
  late DateTime _activityDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    _hoursCtl = TextEditingController(text: p?.hours.toString() ?? '');
    _proofCtl = TextEditingController(text: p?.proofLink ?? '');
    _notesCtl = TextEditingController(text: p?.notes ?? '');
    _activityDate = p?.activityDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _hoursCtl.dispose();
    _proofCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    Provider.of<HapticsProvider>(context, listen: false).selection();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _activityDate,
      firstDate: DateTime(now.year - 2, now.month, now.day),
      lastDate: now,
    );
    if (picked != null) setState(() => _activityDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final haptics = Provider.of<HapticsProvider>(context, listen: false);
    setState(() => _submitting = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw 'Not signed in';

      await _supabase.from('continuous_event_submissions').insert({
        'continuous_event_id': widget.event.id,
        'society_id': widget.event.societyId,
        'user_id': userId,
        'hours': double.parse(_hoursCtl.text.trim()),
        'activity_date':
            _activityDate.toIso8601String().substring(0, 10),
        'proof_link': _proofCtl.text.trim(),
        'notes': _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
        'status': 'pending',
      });

      haptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted for review')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      haptics.error();
      setState(() => _submitting = false);
      if (mounted) {
        final msg = e.toString();
        final friendly = msg.contains('continuous_submission_limit')
            ? 'Only one submission is allowed for this opportunity.'
            : (msg.contains('duplicate key')
                ? 'You already have a submission for this opportunity.'
                : 'Submit failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendly)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd();
    return AlertDialog(
      title: const Text('Log Hours'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _hoursCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Hours',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = double.tryParse(v.trim());
                  if (n == null) return 'Enter a number';
                  if (n <= 0) return 'Must be greater than 0';
                  if (n > 999) return 'Too large';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text('Date: ${dateFmt.format(_activityDate)}'),
                onPressed: _pickDate,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _proofCtl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Proof link',
                  hintText: 'Drive, photo, receipt URL',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Required';
                  final uri = Uri.tryParse(s);
                  if (uri == null || !(uri.hasScheme && uri.hasAuthority)) {
                    return 'Enter a valid URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit'),
        ),
      ],
    );
  }
}
