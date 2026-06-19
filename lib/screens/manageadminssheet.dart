import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../common/app_design.dart';
import '../providers/societyprovider.dart';
import '../providers/hapticsprovider.dart';

final supabase = Supabase.instance.client;

/// A single society member as shown in the Manage Admins sheet.
class _AdminMember {
  final String userId;
  final String name;
  final String email;
  bool isAdmin;

  _AdminMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.isAdmin,
  });
}

/// Bottom sheet that lets an admin promote or demote other members of the
/// current society. Promoting and demoting both require confirmation. An admin
/// cannot remove their own admin access here (to avoid locking themselves out)
/// — they should use "View as member" instead.
class ManageAdminsSheet extends StatefulWidget {
  const ManageAdminsSheet({super.key});

  @override
  State<ManageAdminsSheet> createState() => _ManageAdminsSheetState();
}

class _ManageAdminsSheetState extends State<ManageAdminsSheet> {
  final List<_AdminMember> _members = [];
  final Set<String> _updating = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String? _error;

  String? get _currentUserId => supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final societyId =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety?.id;
    if (societyId == null) {
      setState(() {
        _isLoading = false;
        _error = 'No society selected.';
      });
      return;
    }

    try {
      final rows = await supabase
          .from('user_society_memberships')
          .select('user_id, is_admin, profiles:user_id(name, email)')
          .eq('society_id', societyId);

      final List<_AdminMember> members = [];
      for (final row in rows as List) {
        final profile = row['profiles'];
        if (profile == null) continue;
        members.add(_AdminMember(
          userId: row['user_id'] as String,
          name: (profile['name'] as String?)?.trim().isNotEmpty == true
              ? profile['name'] as String
              : 'Unknown member',
          email: profile['email'] as String? ?? '',
          isAdmin: row['is_admin'] as bool? ?? false,
        ));
      }

      members.sort((a, b) {
        // Admins first, then alphabetical by name.
        if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (!mounted) return;
      setState(() {
        _members
          ..clear()
          ..addAll(members);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load members: $e';
      });
    }
  }

  List<_AdminMember> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    final q = _searchQuery.toLowerCase();
    return _members
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            m.email.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _onToggle(_AdminMember member, bool makeAdmin) async {
    final haptics = Provider.of<HapticsProvider>(context, listen: false);
    haptics.selection();

    final societyProvider =
        Provider.of<SocietyProvider>(context, listen: false);
    final societyId = societyProvider.currentSociety?.id;
    final societyName = societyProvider.currentSociety?.name ?? 'this society';
    if (societyId == null) return;

    final confirmed = await _confirmChange(member, makeAdmin, societyName);
    if (confirmed != true) return;

    setState(() => _updating.add(member.userId));
    try {
      await supabase
          .from('user_society_memberships')
          .update({'is_admin': makeAdmin})
          .eq('society_id', societyId)
          .eq('user_id', member.userId);

      haptics.success();
      if (!mounted) return;
      setState(() => member.isAdmin = makeAdmin);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(makeAdmin
              ? '${member.name} is now an admin'
              : '${member.name} is no longer an admin'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      haptics.error();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update ${member.name}: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _updating.remove(member.userId));
    }
  }

  Future<bool?> _confirmChange(
      _AdminMember member, bool makeAdmin, String societyName) {
    final scheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(makeAdmin
            ? 'Make ${member.name} an admin?'
            : 'Remove ${member.name} as admin?'),
        content: Text(makeAdmin
            ? 'Admins can manage events, attendance, members, hour '
                'requirements, and settings for $societyName.'
            : '${member.name} will lose access to all admin features in '
                '$societyName. You can make them an admin again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: makeAdmin ? scheme.primary : scheme.error,
            ),
            child: Text(makeAdmin ? 'Make admin' : 'Remove admin'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filteredMembers;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDesign.spacingL,
          right: AppDesign.spacingL,
          top: AppDesign.spacingS,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppDesign.spacingL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings, color: scheme.primary),
                const SizedBox(width: AppDesign.spacingS),
                Text(
                  'Manage Admins',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppDesign.spacingXS),
            Text(
              'Promote members to admin or remove admin access.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppDesign.spacingM),
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                labelText: 'Search members',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: AppDesign.borderMedium),
              ),
            ),
            const SizedBox(height: AppDesign.spacingM),
            Flexible(child: _buildBody(filtered)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<_AdminMember> filtered) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppDesign.spacingXL),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppDesign.spacingL),
        child: Center(
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppDesign.spacingXL),
        child: Center(child: Text('No members found')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildMemberTile(filtered[index]),
    );
  }

  Widget _buildMemberTile(_AdminMember member) {
    final scheme = Theme.of(context).colorScheme;
    final isSelf = member.userId == _currentUserId;
    final isUpdating = _updating.contains(member.userId);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            member.isAdmin ? scheme.primaryContainer : scheme.surfaceVariant,
        child: Text(
          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: member.isAdmin
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              member.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (isSelf)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '(You)',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        isSelf && member.isAdmin
            ? "Use 'View as member' to preview the member experience"
            : member.email,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: isUpdating
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: member.isAdmin,
              // Block self-demote: an admin cannot turn off their own admin
              // access from here, only via "View as member".
              onChanged: (isSelf && member.isAdmin)
                  ? null
                  : (value) => _onToggle(member, value),
            ),
    );
  }
}
