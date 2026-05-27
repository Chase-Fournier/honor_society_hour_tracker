import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'main.dart';
import 'package:provider/provider.dart';
import '../providers/hapticsprovider.dart';

class SnakePage extends StatefulWidget {
  const SnakePage({Key? key}) : super(key: key);

  @override
  State<SnakePage> createState() => _SnakePageState();
}

class _SnakePageState extends State<SnakePage> with TickerProviderStateMixin {
  final GlobalKey<SnakeGameState> _gameKey = GlobalKey<SnakeGameState>();
  late TabController _tabController;
  bool _isPaused = false;
  String _currentGameMode = 'classic';
  List<SnakeScore> _topScores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchTopScores();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTopScores() async {
    setState(() => _isLoading = true);

    try {
      final response = await supabase
          .from('snake_scores')
          .select('*, profiles!inner(name)')
          .order('score', ascending: false)
          .limit(10);

      setState(() {
        _topScores = response
            .map<SnakeScore>((json) => SnakeScore.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching scores: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveScore(int score, String gameMode) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('snake_scores').insert({
        'user_id': userId,
        'score': score,
        'game_mode': gameMode,
      });

      await _fetchTopScores();
    } catch (e) {
      print('Error saving score: $e');
    }
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    _gameKey.currentState?.togglePause();
  }

  void _onGameOver(GameStats stats) {
    final score = stats.score;
    final gameMode = stats.gameMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Game Over',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildScoreCard(score, gameMode),
              const SizedBox(height: 24),
              if (_topScores.isNotEmpty && score > 0) _getRankingMessage(score),
              const SizedBox(height: 16),
              _buildStatsRow(stats),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save Score'),
            onPressed: () async {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              await _saveScore(score, gameMode);
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.replay),
            label: const Text('Play Again'),
            onPressed: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              Navigator.of(context).pop();
              _gameKey.currentState?.resetGame();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(int score, String gameMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Your Score',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          Text(
            'Mode: ${gameMode.toUpperCase()}',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onPrimaryContainer
                  .withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(GameStats stats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard(
            Icons.speed, 'Max Speed', '${stats.maxSpeed.toStringAsFixed(1)}x'),
        _buildStatCard(Icons.restaurant, 'Food Eaten', '${stats.foodEaten}'),
        _buildStatCard(Icons.straighten, 'Max Length', '${stats.maxLength}'),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getRankingMessage(int score) {
    bool isHighScore = false;
    int rank = _topScores.length + 1;

    for (int i = 0; i < _topScores.length; i++) {
      if (score > _topScores[i].score) {
        isHighScore = true;
        rank = i + 1;
        break;
      }
    }

    if (isHighScore && rank <= 3) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                rank == 1
                    ? '🏆 New High Score! You\'re #1! 🏆'
                    : '🎉 Amazing! You made it to #$rank! 🎉',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    } else if (isHighScore) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.stars,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Great job! You made it to #$rank!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    } else if (_topScores.length < 10) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'You made it to the leaderboard!',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Keep trying! You need ${_topScores.last.score - score + 1} more points to make the leaderboard!',
          style: TextStyle(
            fontWeight: FontWeight.normal,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
  }

  void _selectGameMode(String mode) {
    setState(() => _currentGameMode = mode);
    _gameKey.currentState?.setGameMode(mode);
    _gameKey.currentState?.resetGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        title: Text(
          'Snake Game',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              _togglePause();
            },
            tooltip: _isPaused ? 'Resume Game' : 'Pause Game',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'GAME'),
            Tab(text: 'LEADERBOARD'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Game Tab
          LayoutBuilder(builder: (context, constraints) {
            return Column(
              children: [
                // Game Mode Selector
                Container(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: _buildModeButton('classic', 'Classic')),
                      Expanded(child: _buildModeButton('walls', 'Walls')),
                      Expanded(child: _buildModeButton('speed', 'Speed')),
                      Expanded(child: _buildModeButton('chaos', 'Chaos')),
                    ],
                  ),
                ),

                // Snake Game - Takes all available space
                Expanded(
                  child: Center(
                    child: SnakeGame(
                      key: _gameKey,
                      onGameOver: _onGameOver,
                      initialGameMode: _currentGameMode,
                    ),
                  ),
                ),
              ],
            );
          }),

          // Leaderboard Tab
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(),
                )
              : _buildLeaderboard(),
        ],
      ),
    );
  }

  Widget _buildModeButton(String mode, String label) {
    bool isSelected = _currentGameMode == mode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            final hapticsProvider =
                Provider.of<HapticsProvider>(context, listen: false);
            hapticsProvider.selection();
            _selectGameMode(mode);
          },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          foregroundColor: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
          elevation: isSelected ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildLeaderboard() {
    return _topScores.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No scores yet. Be the first!',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    _tabController.animateTo(0);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _topScores.length + 1, // +1 for header
            itemBuilder: (context, index) {
              if (index == 0) {
                // Header
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Top Scores',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Can you beat the best?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final score = _topScores[index - 1];
              final isTop3 = index <= 3;
              final colors = _getLeaderboardColors(index);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isTop3
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: ListTile(
                  leading: _buildRankBadge(index, colors),
                  title: Text(
                    score.playerName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                  subtitle: Text(
                    score.gameMode != null
                        ? 'Mode: ${score.gameMode!.toUpperCase()}'
                        : '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.badge,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${score.score} pts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isTop3
                            ? Colors.black87
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }

  LeaderboardColors _getLeaderboardColors(int index) {
    if (index == 1) {
      return LeaderboardColors(
        background: const Color(0xFFFFF9C4), // Gold
        badge: const Color(0xFFFFD700).withOpacity(0.7),
        text: const Color(0xFF5D4037),
      );
    } else if (index == 2) {
      return LeaderboardColors(
        background: const Color(0xFFE8E8E8), // Silver
        badge: const Color(0xFFC0C0C0).withOpacity(0.7),
        text: const Color(0xFF455A64),
      );
    } else if (index == 3) {
      return LeaderboardColors(
        background: const Color(0xFFE0C8BC), // Bronze
        badge: const Color(0xFFCD7F32).withOpacity(0.7),
        text: const Color(0xFF6D4C41),
      );
    } else {
      return LeaderboardColors(
        background: Theme.of(context).colorScheme.surfaceVariant,
        badge: Theme.of(context).colorScheme.primaryContainer,
        text: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }
  }

  Widget _buildRankBadge(int rank, LeaderboardColors colors) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.badge,
        boxShadow: rank <= 3
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        border: rank > 3
            ? Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 1,
              )
            : null,
      ),
      child: Center(
        child: Text(
          rank <= 3 ? '#$rank' : '$rank',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: rank <= 3 ? Colors.black87 : colors.text,
          ),
        ),
      ),
    );
  }
}

class LeaderboardColors {
  final Color background;
  final Color badge;
  final Color text;

  LeaderboardColors({
    required this.background,
    required this.badge,
    required this.text,
  });
}

class SnakeScore {
  final String userId;
  final String playerName;
  final int score;
  final DateTime createdAt;
  final String? gameMode;

  SnakeScore({
    required this.userId,
    required this.playerName,
    required this.score,
    required this.createdAt,
    this.gameMode,
  });

  factory SnakeScore.fromJson(Map<String, dynamic> json) {
    return SnakeScore(
      userId: json['user_id'],
      playerName: json['profiles']['name'],
      score: json['score'],
      createdAt: DateTime.parse(json['created_at']),
      gameMode: json['game_mode'],
    );
  }
}

// Game-related classes
enum Direction { up, down, left, right }

enum FoodType { normal, bonus, special }

enum GameState { notStarted, playing, paused, gameOver }

class GameStats {
  final int score;
  final int foodEaten;
  final double maxSpeed;
  final int maxLength;
  final String gameMode;

  GameStats({
    required this.score,
    required this.foodEaten,
    required this.maxSpeed,
    required this.maxLength,
    required this.gameMode,
  });
}

class Position {
  final int x;
  final int y;

  const Position(this.x, this.y);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Position && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

class SnakeGame extends StatefulWidget {
  final Function(GameStats) onGameOver;
  final String initialGameMode;

  const SnakeGame({
    Key? key,
    required this.onGameOver,
    this.initialGameMode = 'classic',
  }) : super(key: key);

  @override
  State<SnakeGame> createState() => SnakeGameState();
}

class SnakeGameState extends State<SnakeGame>
    with SingleTickerProviderStateMixin {
  // Game config
  static const int gridSize = 20;

  // Game state
  late List<Position> snake;
  late Position food;
  FoodType foodType = FoodType.normal;
  Direction direction = Direction.right;
  Direction nextDirection = Direction.right;
  GameState gameState = GameState.notStarted;
  String gameMode = '';
  List<Position> obstacles = [];

  // Game metrics
  int score = 0;
  int foodEaten = 0;
  double speedMultiplier = 1.0;
  double maxSpeed = 1.0;
  int baseSpeed = 200; // ms between updates
  int maxLength = 0;

  // Game timer
  Timer? gameTimer;

  // Touch control
  Offset? swipeStart;

  // Animation
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);

    gameMode = widget.initialGameMode;
    _initGame();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    _animationController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _initGame() {
    // Initialize snake in the middle of the board
    final middle = gridSize ~/ 2;
    snake = [
      Position(middle, middle),
      Position(middle - 1, middle),
      Position(middle - 2, middle),
    ];

    // Reset game state
    direction = Direction.right;
    nextDirection = Direction.right;
    score = 0;
    foodEaten = 0;
    speedMultiplier = 1.0;
    maxSpeed = 1.0;
    obstacles = [];
    maxLength = snake.length;
    gameState = GameState.notStarted;

    // Initialize game mode specifics
    switch (gameMode) {
      case 'walls':
        _initWallsMode();
        break;
      case 'speed':
        baseSpeed = 150; // Start faster
        break;
      case 'chaos':
        _initChaosMode();
        break;
    }

    // Place initial food
    _placeFood();

    // Clean up any existing timer
    gameTimer?.cancel();
  }

  void _initWallsMode() {
    // Add walls around the edges with gaps
    for (int i = 0; i < gridSize; i++) {
      if (i < 3 || i > gridSize - 4) continue; // Leave gaps

      obstacles.add(Position(i, 0)); // Top wall
      obstacles.add(Position(i, gridSize - 1)); // Bottom wall
    }

    for (int i = 0; i < gridSize; i++) {
      if (i < 3 || i > gridSize - 4) continue; // Leave gaps

      obstacles.add(Position(0, i)); // Left wall
      obstacles.add(Position(gridSize - 1, i)); // Right wall
    }

    // Add some internal walls
    for (int i = 5; i < 15; i++) {
      obstacles.add(Position(i, gridSize ~/ 3));
    }
  }

  void _initChaosMode() {
    // Add random obstacles
    final random = Random();
    for (int i = 0; i < 15; i++) {
      int x, y;
      do {
        x = random.nextInt(gridSize);
        y = random.nextInt(gridSize);
      } while (_isObstacle(Position(x, y)) || _isSnake(Position(x, y)));

      obstacles.add(Position(x, y));
    }
  }

  void _placeFood() {
    final random = Random();
    int x, y;
    Position newFood;

    // Find a free position for food
    do {
      x = random.nextInt(gridSize);
      y = random.nextInt(gridSize);
      newFood = Position(x, y);
    } while (_isObstacle(newFood) || _isSnake(newFood));

    // Determine food type with probabilities
    final roll = random.nextDouble();
    if (roll < 0.15 && foodEaten > 5) {
      // 15% chance for special food after eating 5 normal foods
      foodType = FoodType.special;
    } else if (roll < 0.4 && foodEaten > 2) {
      // 25% chance for bonus food after eating 2 normal foods
      foodType = FoodType.bonus;
    } else {
      // 60% chance for normal food
      foodType = FoodType.normal;
    }

    food = newFood;

    // In chaos mode, occasionally add a new obstacle
    if (gameMode == 'chaos' && random.nextDouble() < 0.3 && foodEaten > 0) {
      do {
        x = random.nextInt(gridSize);
        y = random.nextInt(gridSize);
        newFood = Position(x, y);
      } while (_isObstacle(newFood) || _isSnake(newFood) || (newFood == food));

      obstacles.add(newFood);
    }
  }

  bool _isObstacle(Position pos) {
    return obstacles.contains(pos);
  }

  bool _isSnake(Position pos) {
    return snake.contains(pos);
  }

  bool _isFood(Position pos) {
    return pos == food;
  }

  void startGame() {
    if (gameState == GameState.notStarted || gameState == GameState.gameOver) {
      setState(() {
        gameState = GameState.playing;
      });

      gameTimer = Timer.periodic(
        Duration(milliseconds: (baseSpeed / speedMultiplier).round()),
        (_) {
          if (gameState == GameState.playing) {
            _updateGame();
          }
        },
      );
    }
  }

  void togglePause() {
    if (gameState == GameState.playing) {
      setState(() {
        gameState = GameState.paused;
      });
    } else if (gameState == GameState.paused) {
      setState(() {
        gameState = GameState.playing;
      });
    }
  }

  void resetGame() {
    gameTimer?.cancel();
    setState(() {
      _initGame();
    });
  }

  void setGameMode(String mode) {
    if (gameMode != mode) {
      gameMode = mode;
      resetGame();
    }
  }

  void _updateGame() {
    // Update direction
    direction = nextDirection;

    // Move snake
    final head = snake.first;
    Position newHead;

    // Calculate new head position based on direction
    switch (direction) {
      case Direction.up:
        newHead = Position(head.x, (head.y - 1 + gridSize) % gridSize);
        break;
      case Direction.down:
        newHead = Position(head.x, (head.y + 1) % gridSize);
        break;
      case Direction.left:
        newHead = Position((head.x - 1 + gridSize) % gridSize, head.y);
        break;
      case Direction.right:
        newHead = Position((head.x + 1) % gridSize, head.y);
        break;
    }

    // Check for collision with obstacle
    if ((gameMode == 'walls' || gameMode == 'chaos') && _isObstacle(newHead)) {
      _gameOver();
      return;
    }

    // Check for collision with self
    if (snake.sublist(0, snake.length - 1).contains(newHead)) {
      _gameOver();
      return;
    }

    // Move snake: add new head
    setState(() {
      snake.insert(0, newHead);

      // Check if food was eaten
      if (_isFood(newHead)) {
        _eatFood();
      } else {
        // Remove tail if no food was eaten
        snake.removeLast();
      }

      // Update max length if needed
      if (snake.length > maxLength) {
        maxLength = snake.length;
      }
    });
  }

  void _eatFood() {
    // Add points based on food type
    int points;
    switch (foodType) {
      case FoodType.special:
        points = 25;
        break;
      case FoodType.bonus:
        points = 15;
        break;
      case FoodType.normal:
      default:
        points = 10;
        break;
    }

    score += points;
    foodEaten++;

    // Increase speed
    if (gameMode == 'speed') {
      speedMultiplier += 0.1;
    } else {
      speedMultiplier += 0.05;
    }

    if (speedMultiplier > maxSpeed) {
      maxSpeed = speedMultiplier;
    }

    // Place new food
    _placeFood();

    // In chaos mode, sometimes add extra food
    if (gameMode == 'chaos' && Random().nextDouble() < 0.3) {
      _placeFood();
    }
  }

  void _gameOver() {
    gameTimer?.cancel();

    setState(() {
      gameState = GameState.gameOver;
    });

    widget.onGameOver(GameStats(
      score: score,
      foodEaten: foodEaten,
      maxSpeed: maxSpeed,
      maxLength: maxLength,
      gameMode: gameMode,
    ));
  }

  void changeDirection(Direction newDirection) {
    // Prevent 180-degree turns
    if ((direction == Direction.up && newDirection == Direction.down) ||
        (direction == Direction.down && newDirection == Direction.up) ||
        (direction == Direction.left && newDirection == Direction.right) ||
        (direction == Direction.right && newDirection == Direction.left)) {
      return;
    }

    nextDirection = newDirection;

    // Start game if not already started
    if (gameState == GameState.notStarted) {
      startGame();
    }
  }

  // Handle keyboard input at the class level
  FocusNode focusNode = FocusNode();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Request focus after the frame is built
    SchedulerBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(focusNode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = min(constraints.maxWidth, constraints.maxHeight);

        return SizedBox(
          width: availableSize,
          height: availableSize,
          child: Focus(
            focusNode: focusNode,
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent || event is KeyRepeatEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  changeDirection(Direction.up);
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  changeDirection(Direction.down);
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  changeDirection(Direction.left);
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  changeDirection(Direction.right);
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.space) {
                  if (gameState == GameState.notStarted) {
                    startGame();
                  } else if (gameState == GameState.paused) {
                    togglePause();
                  } else if (gameState == GameState.playing) {
                    togglePause();
                  }
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (details) {
                swipeStart = details.localPosition;
              },
              onHorizontalDragStart: (details) {
                swipeStart = details.localPosition;
              },
              onVerticalDragUpdate: (details) {
                if (swipeStart == null) return;

                final delta = details.localPosition - swipeStart!;
                if (delta.distance < 10) return; // Minimum swipe distance

                if (delta.dy < 0 && direction != Direction.down) {
                  changeDirection(Direction.up);
                } else if (delta.dy > 0 && direction != Direction.up) {
                  changeDirection(Direction.down);
                }

                swipeStart = null;
              },
              onHorizontalDragUpdate: (details) {
                if (swipeStart == null) return;

                final delta = details.localPosition - swipeStart!;
                if (delta.distance < 10) return; // Minimum swipe distance

                if (delta.dx < 0 && direction != Direction.right) {
                  changeDirection(Direction.left);
                } else if (delta.dx > 0 && direction != Direction.left) {
                  changeDirection(Direction.right);
                }

                swipeStart = null;
              },
              onTap: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                if (gameState == GameState.notStarted) {
                  startGame();
                } else if (gameState == GameState.paused) {
                  togglePause();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3.0,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    children: [
                      // Grid background
                      Positioned.fill(
                        child: CustomPaint(
                          painter: GridPainter(
                            gridSize: gridSize,
                            color: Theme.of(context)
                                .colorScheme
                                .onBackground
                                .withOpacity(0.05),
                          ),
                        ),
                      ),

                      // Draw obstacles
                      ...obstacles
                          .map((pos) => _buildObstacle(pos, availableSize)),

                      // Draw food
                      _buildFood(food, availableSize),

                      // Draw snake
                      ...snake.asMap().entries.map((entry) =>
                          _buildSnakeSegment(
                              entry.value, entry.key == 0, availableSize)),

                      // Game UI overlays
                      _buildGameUI(availableSize),

                      // Game state overlay
                      if (gameState != GameState.playing)
                        _buildGameStateOverlay(availableSize),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameUI(double size) {
    final cellSize = size / gridSize;
    final fontSize = max(10.0, size / 30);

    return Stack(
      children: [
        // Score display
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Score: $score',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
          ),
        ),

        // Speed indicator
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer
                  .withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.speed,
                  size: fontSize + 2,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  '${speedMultiplier.toStringAsFixed(1)}x',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Game mode indicator
        Positioned(
          bottom: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .tertiaryContainer
                  .withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              gameMode.toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: fontSize - 2,
              ),
            ),
          ),
        ),

        // Length indicator
        Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.straighten,
                  size: fontSize + 2,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${snake.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameStateOverlay(double size) {
    return Positioned.fill(
      child: Container(
        color: Theme.of(context).colorScheme.background.withOpacity(0.8),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                gameState == GameState.paused ? 'PAUSED' : 'SNAKE',
                style: TextStyle(
                  fontSize: size / 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: size / 20),
              Text(
                gameState == GameState.paused
                    ? 'Tap to resume'
                    : 'Swipe or use arrow keys to start',
                style: TextStyle(
                  fontSize: size / 25,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: size / 12),
              ElevatedButton.icon(
                onPressed: gameState == GameState.paused
                    ? () => togglePause()
                    : () => startGame(),
                icon: Icon(gameState == GameState.paused
                    ? Icons.play_arrow
                    : Icons.play_circle),
                label: Text(
                    gameState == GameState.paused ? 'Resume' : 'Start Game'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(
                    horizontal: size / 15,
                    vertical: size / 30,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnakeSegment(Position position, bool isHead, double boardSize) {
    final cellSize = boardSize / gridSize;
    final x = position.x * cellSize;
    final y = position.y * cellSize;

    return Positioned(
      left: x,
      top: y,
      width: cellSize,
      height: cellSize,
      child: isHead ? _buildHead(cellSize) : _buildBody(cellSize),
    );
  }

  Widget _buildHead(double cellSize) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final scale = 1.0 + (_animationController.value * 0.1);

        return Transform.scale(
          scale: scale,
          child: Container(
            margin: EdgeInsets.all(cellSize * 0.05),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(cellSize * 0.2),
            ),
            child: Center(
              child: Icon(
                _getDirectionIcon(),
                color: Theme.of(context).colorScheme.onPrimary,
                size: cellSize * 0.5,
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getDirectionIcon() {
    switch (direction) {
      case Direction.up:
        return Icons.arrow_upward;
      case Direction.down:
        return Icons.arrow_downward;
      case Direction.left:
        return Icons.arrow_back;
      case Direction.right:
        return Icons.arrow_forward;
    }
  }

  Widget _buildBody(double cellSize) {
    return Container(
      margin: EdgeInsets.all(cellSize * 0.05),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(cellSize * 0.2),
      ),
    );
  }

  Widget _buildFood(Position position, double boardSize) {
    final cellSize = boardSize / gridSize;
    final x = position.x * cellSize;
    final y = position.y * cellSize;

    // Choose color based on food type
    Color foodColor;
    switch (foodType) {
      case FoodType.special:
        foodColor = Colors.purple;
        break;
      case FoodType.bonus:
        foodColor = Colors.orange;
        break;
      case FoodType.normal:
      default:
        foodColor = Colors.red;
        break;
    }

    return Positioned(
      left: x,
      top: y,
      width: cellSize,
      height: cellSize,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final scale = 1.0 + (_animationController.value * 0.2);

          return Transform.scale(
            scale: scale,
            child: Container(
              margin: EdgeInsets.all(cellSize * 0.1),
              decoration: BoxDecoration(
                color: foodColor,
                shape: foodType == FoodType.normal
                    ? BoxShape.circle
                    : foodType == FoodType.bonus
                        ? BoxShape.rectangle
                        : BoxShape.rectangle,
                borderRadius: foodType == FoodType.bonus
                    ? BorderRadius.circular(cellSize * 0.2)
                    : foodType == FoodType.special
                        ? BorderRadius.circular(0)
                        : null,
              ),
              child: foodType == FoodType.special
                  ? Icon(
                      Icons.star,
                      color: Colors.yellow,
                      size: cellSize * 0.6,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildObstacle(Position position, double boardSize) {
    final cellSize = boardSize / gridSize;
    final x = position.x * cellSize;
    final y = position.y * cellSize;

    return Positioned(
      left: x,
      top: y,
      width: cellSize,
      height: cellSize,
      child: Container(
        margin: EdgeInsets.all(cellSize * 0.05),
        decoration: BoxDecoration(
          color: gameMode == 'chaos'
              ? Colors.purple.shade800
              : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(cellSize * 0.1),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final int gridSize;
  final Color color;

  GridPainter({
    required this.gridSize,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final cellSize = size.width / gridSize;

    // Draw vertical lines
    for (int i = 1; i < gridSize; i++) {
      final x = cellSize * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (int i = 1; i < gridSize; i++) {
      final y = cellSize * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
