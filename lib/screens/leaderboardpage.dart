import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../common/app_design.dart';
import '../models/userranking.dart';


final supabase = Supabase.instance.client;

class LeaderboardPage extends StatefulWidget {
  final String currentUserId;

  const LeaderboardPage({Key? key, required this.currentUserId})
      : super(key: key);

  @override
  _LeaderboardPageState createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<UserRanking> _rankings = [];
  UserRanking? _currentUserRanking;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboardData();
  }

  Future<void> _fetchLeaderboardData() async {
    try {
      // Fetch profiles first
      final profilesResponse =
          await supabase.from('profiles').select('user_id, name');

      // Create a map of user_id to name for quick lookup
      Map<String, String> userNames = {
        for (var profile in profilesResponse)
          profile['user_id'].toString(): profile['name'].toString()
      };

      // Fetch service hours
      final response = await supabase
          .from('Service hours')
          .select('user_id, hours, type')
          .neq('type', 'Meeting'); // Exclude meeting hours

      // Process the data to calculate total hours per user
      Map<String, UserRanking> userHours = {};

      for (var record in response) {
        final userId = record['user_id'] as String;
        final hours = (record['hours'] as num).toDouble();
        final userName = userNames[userId] ?? 'Unknown User';

        if (!userHours.containsKey(userId)) {
          userHours[userId] = UserRanking(
            userId: userId,
            name: userName,
            totalHours: 0,
            rank: 0,
          );
        }
        userHours[userId]!.totalHours += hours;
      }

      // Convert to list and sort by total hours
      List<UserRanking> rankings = userHours.values.toList()
        ..sort((a, b) => b.totalHours.compareTo(a.totalHours));

      // Assign ranks
      for (int i = 0; i < rankings.length; i++) {
        rankings[i].rank = i + 1;
      }

      if (mounted) {
        setState(() {
          _rankings = rankings.take(10).toList(); // Top 10
          _currentUserRanking = rankings.firstWhere(
            (ranking) => ranking.userId == widget.currentUserId,
            orElse: () => UserRanking(
              userId: widget.currentUserId,
              name: 'You',
              totalHours: 0,
              rank: rankings.length + 1,
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching leaderboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        title: Text(
          'Leaderboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _fetchLeaderboardData,
              color: Theme.of(context).colorScheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Header section
                    Container(
                      width: double.infinity,
                      padding: AppDesign.paddingMedium,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(AppDesign.radiusXLarge),
                          bottomRight: Radius.circular(AppDesign.radiusXLarge),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          if (_rankings.isNotEmpty) _buildTopThree(),
                        ],
                      ),
                    ),

                    if (_rankings.length > 3) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.emoji_events_outlined,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Honorable Mentions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _rankings.length - 3,
                        itemBuilder: (context, index) {
                          return _buildRankingTile(_rankings[index + 3]);
                        },
                      ),
                    ],

                    // Current user section (if not in top 10)
                    if (_currentUserRanking != null &&
                        _currentUserRanking!.rank > 10) ...[
                      const Divider(height: 40, thickness: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Your Position',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.5),
                          borderRadius: AppDesign.borderLarge,
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: _buildRankingTile(_currentUserRanking!),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTopThree() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_rankings.length > 1)
          _buildPodiumItem(_rankings[1], 2, Colors.grey[400]!),
        if (_rankings.isNotEmpty)
          _buildPodiumItem(_rankings[0], 1, Colors.amber),
        if (_rankings.length > 2)
          _buildPodiumItem(_rankings[2], 3, Colors.brown[300]!),
      ],
    );
  }

  // Keep the original podium item design
  Widget _buildPodiumItem(UserRanking ranking, int position, Color color) {
    final double baseHeight = 120.0;
    final double height = position == 1
        ? baseHeight
        : position == 2
            ? baseHeight * 0.85
            : baseHeight * 0.7;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: AppDesign.borderMedium,
          ),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: color,
                radius: position == 1 ? 30 : 25,
                child: Text(
                  position.toString(),
                  style: TextStyle(
                    fontSize: position == 1 ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: position == 1 ? 100 : 80,
                height: height,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDesign.radiusSmall)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        ranking.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: position == 1 ? 16 : 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: AppDesign.borderMedium,
                      ),
                      child: Text(
                        '${ranking.totalHours.toStringAsFixed(1)}h',
                        style: TextStyle(
                          fontSize: position == 1 ? 14 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankingTile(UserRanking ranking) {
    final bool isCurrentUser = ranking.userId == widget.currentUserId;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isCurrentUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: AppDesign.borderXLarge,
        ),
        child: Center(
          child: Text(
            ranking.rank.toString(),
            style: TextStyle(
              color: isCurrentUser
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(
        ranking.name,
        style: TextStyle(
          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: AppDesign.borderLarge,
        ),
        child: Text(
          '${ranking.totalHours.toStringAsFixed(1)}h',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCurrentUser
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
