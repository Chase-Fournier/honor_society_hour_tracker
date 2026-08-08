import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'common/app_design.dart';
import 'data/supabase_client.dart';
import 'providers/hapticsprovider.dart';

/// ---------------------------------------------------------------------------
/// Snake — a self-contained mini game reachable from the settings page.
///
/// The page hosts two tabs (Game / Leaderboard). The board itself is rendered
/// by a single [CustomPainter] for smoothness, and every color is pulled from
/// the active [ColorScheme] so the game tracks all of the app's themes.
/// ---------------------------------------------------------------------------

class SnakePage extends StatefulWidget {
  const SnakePage({super.key});

  @override
  State<SnakePage> createState() => _SnakePageState();
}

class _SnakePageState extends State<SnakePage> with TickerProviderStateMixin {
  final GlobalKey<SnakeGameState> _gameKey = GlobalKey<SnakeGameState>();
  late final TabController _tabController;

  String _currentGameMode = 'classic';
  GameState _gameState = GameState.notStarted;

  List<SnakeScore> _topScores = [];
  bool _isLoading = true;

  static const List<_GameMode> _modes = [
    _GameMode('classic', 'Classic', Icons.gamepad_outlined),
    _GameMode('walls', 'Walls', Icons.border_outer),
    _GameMode('speed', 'Speed', Icons.bolt),
    _GameMode('chaos', 'Chaos', Icons.shuffle),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
    _fetchTopScores();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // Auto-pause so you never die while reading the leaderboard, and refresh
    // the scores when the leaderboard comes into view.
    if (_tabController.index != 0 && _gameState == GameState.playing) {
      _gameKey.currentState?.togglePause();
    }
    if (_tabController.index == 1) {
      _fetchTopScores();
    }
    setState(() {});
  }

  HapticsProvider get _haptics =>
      Provider.of<HapticsProvider>(context, listen: false);

  Future<void> _fetchTopScores() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('snake_scores')
          .select('*, profiles!inner(name)')
          .order('score', ascending: false)
          .limit(10);

      if (!mounted) return;
      setState(() {
        _topScores =
            response.map<SnakeScore>((json) => SnakeScore.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching scores: $e');
      if (mounted) setState(() => _isLoading = false);
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
      debugPrint('Error saving score: $e');
    }
  }

  void _onStateChanged(GameState state) {
    if (mounted) setState(() => _gameState = state);
  }

  void _selectGameMode(String mode) {
    if (_currentGameMode == mode) return;
    _haptics.selection();
    setState(() => _currentGameMode = mode);
    _gameKey.currentState?.setGameMode(mode);
  }

  void _togglePause() {
    _haptics.selection();
    _gameKey.currentState?.togglePause();
  }

  void _restart() {
    _haptics.selection();
    _gameKey.currentState?.resetGame();
  }

  // ---------------------------------------------------------------------------
  // Game over
  // ---------------------------------------------------------------------------

  void _onGameOver(GameStats stats) {
    _haptics.error();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _GameOverDialog(
        stats: stats,
        rankingMessage: _rankingMessageFor(stats.score),
        onSave: stats.score > 0
            ? () async {
                _haptics.success();
                await _saveScore(stats.score, stats.gameMode);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              }
            : null,
        onPlayAgain: () {
          _haptics.selection();
          Navigator.of(dialogContext).pop();
          _gameKey.currentState?.resetGame();
        },
      ),
    );
  }

  /// Returns a friendly message describing how the run placed on the board.
  String? _rankingMessageFor(int score) {
    if (score <= 0) return null;

    int rank = _topScores.length + 1;
    for (int i = 0; i < _topScores.length; i++) {
      if (score > _topScores[i].score) {
        rank = i + 1;
        break;
      }
    }

    if (rank == 1) return '🏆 New high score — you\'re #1!';
    if (rank <= 3) return '🎉 Amazing! You made it to #$rank!';
    if (rank <= 10) return 'Nice! That lands you at #$rank on the board.';
    if (_topScores.length < 10) return 'You made the leaderboard!';

    final needed = _topScores.last.score - score + 1;
    return 'So close! $needed more point${needed == 1 ? '' : 's'} to crack the top 10.';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onGameTab = _tabController.index == 0;
    final canPause =
        _gameState == GameState.playing || _gameState == GameState.paused;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        centerTitle: true,
        title: Text(
          'Snake',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: scheme.onSurface,
          ),
        ),
        actions: onGameTab
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Restart',
                  onPressed: _restart,
                ),
                IconButton(
                  icon: Icon(_gameState == GameState.playing
                      ? Icons.pause
                      : Icons.play_arrow),
                  tooltip:
                      _gameState == GameState.playing ? 'Pause' : 'Resume',
                  onPressed: canPause ? _togglePause : null,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh scores',
                  onPressed: () {
                    _haptics.selection();
                    _fetchTopScores();
                  },
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
          _buildGameTab(),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildLeaderboard(scheme),
        ],
      ),
    );
  }

  Widget _buildGameTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppDesign.spacingM, AppDesign.spacingM, AppDesign.spacingM, AppDesign.spacingS),
          child: _SegmentedModeSelector(
            modes: _modes,
            selected: _currentGameMode,
            onSelected: _selectGameMode,
          ),
        ),
        Expanded(
          child: SnakeGame(
            key: _gameKey,
            onGameOver: _onGameOver,
            onStateChanged: _onStateChanged,
            initialGameMode: _currentGameMode,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Leaderboard
  // ---------------------------------------------------------------------------

  Widget _buildLeaderboard(ColorScheme scheme) {
    if (_topScores.isEmpty) {
      return Center(
        child: Padding(
          padding: AppDesign.paddingLarge,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: scheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppDesign.spacingM),
              Text(
                'No scores yet — be the first!',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDesign.spacingL),
              FilledButton.icon(
                onPressed: () {
                  _haptics.selection();
                  _tabController.animateTo(0);
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play now'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTopScores,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppDesign.spacingS),
        itemCount: _topScores.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildLeaderboardHeader(scheme);
          return _buildScoreTile(scheme, index, _topScores[index - 1]);
        },
      ),
    );
  }

  Widget _buildLeaderboardHeader(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppDesign.spacingM, AppDesign.spacingS, AppDesign.spacingM, AppDesign.spacingS),
      padding: AppDesign.paddingLarge,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: AppDesign.borderLarge,
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: scheme.onPrimaryContainer, size: 28),
          const SizedBox(width: AppDesign.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Scores',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: AppDesign.spacingXS),
                Text(
                  'Can you beat the best?',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreTile(ColorScheme scheme, int rank, SnakeScore score) {
    final medal = _medalColor(rank);
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppDesign.spacingM, vertical: AppDesign.spacingXS),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppDesign.borderLarge,
        border: Border.all(
          color: medal ?? scheme.outlineVariant,
          width: medal != null ? 1.5 : 1,
        ),
        boxShadow: AppDesign.shadowSmall(context),
      ),
      child: ListTile(
        leading: _buildRankBadge(scheme, rank, medal),
        title: Text(
          score.playerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: score.gameMode != null
            ? Text(
                score.gameMode!.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: AppDesign.borderRound,
          ),
          child: Text(
            '${score.score} pts',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(ColorScheme scheme, int rank, Color? medal) {
    final hasMedal = medal != null;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasMedal ? medal : scheme.surfaceContainerHighest,
        border: hasMedal
            ? null
            : Border.all(color: scheme.outlineVariant, width: 1),
      ),
      alignment: Alignment.center,
      child: hasMedal
          ? Icon(Icons.emoji_events,
              size: 18, color: _onMedal(medal))
          : Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.onSurfaceVariant,
              ),
            ),
    );
  }

  /// Medal accent colors are intentionally fixed (gold/silver/bronze read the
  /// same in every theme); they're only ever used on the small badge/border,
  /// never as a content background.
  Color? _medalColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFC107); // gold
      case 2:
        return const Color(0xFFB0BEC5); // silver
      case 3:
        return const Color(0xFFCD7F32); // bronze
      default:
        return null;
    }
  }

  Color _onMedal(Color medal) =>
      ThemeData.estimateBrightnessForColor(medal) == Brightness.dark
          ? Colors.white
          : Colors.black87;
}

/// ---------------------------------------------------------------------------
/// Mode selector — an iOS-style segmented control built from theme colors.
/// ---------------------------------------------------------------------------

class _GameMode {
  final String id;
  final String label;
  final IconData icon;
  const _GameMode(this.id, this.label, this.icon);
}

class _SegmentedModeSelector extends StatelessWidget {
  final List<_GameMode> modes;
  final String selected;
  final ValueChanged<String> onSelected;

  const _SegmentedModeSelector({
    required this.modes,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDesign.spacingXS),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppDesign.borderRound,
      ),
      child: Row(
        children: modes.map((mode) {
          final isSelected = mode.id == selected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(mode.id),
              child: AnimatedContainer(
                duration: AppDesign.animationShort,
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? scheme.primary : Colors.transparent,
                  borderRadius: AppDesign.borderRound,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mode.icon,
                      size: 18,
                      color: isSelected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        mode.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Game over dialog
/// ---------------------------------------------------------------------------

class _GameOverDialog extends StatelessWidget {
  final GameStats stats;
  final String? rankingMessage;
  final Future<void> Function()? onSave;
  final VoidCallback onPlayAgain;

  const _GameOverDialog({
    required this.stats,
    required this.rankingMessage,
    required this.onSave,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppDesign.borderXLarge),
      title: Text(
        'Game Over',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: scheme.primary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Score card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: AppDesign.borderLarge,
              ),
              child: Column(
                children: [
                  Text(
                    'Your Score',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    '${stats.score}',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    stats.gameMode.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1,
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (rankingMessage != null) ...[
              const SizedBox(height: AppDesign.spacingM),
              Container(
                width: double.infinity,
                padding: AppDesign.paddingMedium,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: AppDesign.borderMedium,
                ),
                child: Text(
                  rankingMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppDesign.spacingL),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                    icon: Icons.speed,
                    label: 'Max Speed',
                    value: '${stats.maxSpeed.toStringAsFixed(1)}x'),
                _StatChip(
                    icon: Icons.restaurant,
                    label: 'Food',
                    value: '${stats.foodEaten}'),
                _StatChip(
                    icon: Icons.straighten,
                    label: 'Length',
                    value: '${stats.maxLength}'),
              ],
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save Score'),
          onPressed: onSave,
        ),
        FilledButton.icon(
          icon: const Icon(Icons.replay),
          label: const Text('Play Again'),
          onPressed: onPlayAgain,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 22, color: scheme.primary),
        const SizedBox(height: AppDesign.spacingXS),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Leaderboard model
/// ---------------------------------------------------------------------------

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
      playerName: json['profiles']['name'] ?? 'Anonymous',
      score: json['score'],
      createdAt: DateTime.parse(json['created_at']),
      gameMode: json['game_mode'],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Game types
/// ---------------------------------------------------------------------------

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
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Position && other.x == x && other.y == y);

  @override
  int get hashCode => Object.hash(x, y);
}

/// ---------------------------------------------------------------------------
/// The game widget
/// ---------------------------------------------------------------------------

class SnakeGame extends StatefulWidget {
  final ValueChanged<GameStats> onGameOver;
  final ValueChanged<GameState>? onStateChanged;
  final String initialGameMode;

  const SnakeGame({
    super.key,
    required this.onGameOver,
    this.onStateChanged,
    this.initialGameMode = 'classic',
  });

  @override
  State<SnakeGame> createState() => SnakeGameState();
}

class SnakeGameState extends State<SnakeGame>
    with SingleTickerProviderStateMixin {
  static const int gridSize = 20;
  static const int _minTickMs = 60;

  // Game state
  late List<Position> snake;
  late Position food;
  FoodType foodType = FoodType.normal;
  Direction direction = Direction.right;
  Direction nextDirection = Direction.right;
  GameState gameState = GameState.notStarted;
  String gameMode = 'classic';
  List<Position> obstacles = [];

  // Metrics
  int score = 0;
  int foodEaten = 0;
  double speedMultiplier = 1.0;
  double maxSpeed = 1.0;
  int maxLength = 0;

  // Tuning (per mode)
  int _baseSpeedMs = 200;
  double _speedStep = 0.06;
  double _speedCap = 2.2;

  Timer? _gameTimer;
  final Random _random = Random();

  // A single buffered turn, so two quick taps don't get dropped or reverse you.
  Direction? _bufferedDirection;

  // Swipe tracking
  Offset? _swipeAnchor;

  final FocusNode _focusNode = FocusNode();
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    gameMode = widget.initialGameMode;
    _initGame();
    // Sync the parent's controls with the initial state once we're mounted —
    // notifying synchronously here would setState() the parent during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onStateChanged?.call(gameState);
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _pulse.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Update [gameState] and notify the parent. Safe to call from event handlers
  /// and timers, but never from build/initState (see initState above).
  void _emitState(GameState state) {
    setState(() => gameState = state);
    widget.onStateChanged?.call(state);
  }

  // ---------------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------------

  void _initGame() {
    const middle = gridSize ~/ 2;
    snake = [
      const Position(middle, middle),
      const Position(middle - 1, middle),
      const Position(middle - 2, middle),
    ];

    direction = Direction.right;
    nextDirection = Direction.right;
    _bufferedDirection = null;
    score = 0;
    foodEaten = 0;
    speedMultiplier = 1.0;
    maxSpeed = 1.0;
    obstacles = [];
    maxLength = snake.length;

    // Per-mode tuning.
    switch (gameMode) {
      case 'speed':
        _baseSpeedMs = 140;
        _speedStep = 0.12;
        _speedCap = 3.0;
        break;
      case 'walls':
        _baseSpeedMs = 200;
        _speedStep = 0.05;
        _speedCap = 2.0;
        break;
      case 'chaos':
        _baseSpeedMs = 190;
        _speedStep = 0.06;
        _speedCap = 2.2;
        _seedChaosObstacles();
        break;
      case 'classic':
      default:
        _baseSpeedMs = 200;
        _speedStep = 0.06;
        _speedCap = 2.2;
        break;
    }

    _placeFood();
    _gameTimer?.cancel();
    // Set directly (no notify): this runs during initState/inside setState.
    gameState = GameState.notStarted;
  }

  void _seedChaosObstacles() {
    for (int i = 0; i < 12; i++) {
      Position p;
      do {
        p = Position(_random.nextInt(gridSize), _random.nextInt(gridSize));
      } while (_isObstacle(p) || _isSnake(p) || _nearCenter(p));
      obstacles.add(p);
    }
  }

  bool _nearCenter(Position p) {
    const mid = gridSize ~/ 2;
    return (p.x - mid).abs() <= 2 && (p.y - mid).abs() <= 1;
  }

  void _placeFood() {
    Position candidate;
    do {
      candidate = Position(_random.nextInt(gridSize), _random.nextInt(gridSize));
    } while (_isObstacle(candidate) || _isSnake(candidate));

    final roll = _random.nextDouble();
    if (roll < 0.15 && foodEaten > 5) {
      foodType = FoodType.special;
    } else if (roll < 0.4 && foodEaten > 2) {
      foodType = FoodType.bonus;
    } else {
      foodType = FoodType.normal;
    }

    food = candidate;
  }

  bool _isObstacle(Position pos) => obstacles.contains(pos);
  bool _isSnake(Position pos) => snake.contains(pos);

  // ---------------------------------------------------------------------------
  // Loop control
  // ---------------------------------------------------------------------------

  Duration get _tickDuration => Duration(
        milliseconds:
            (_baseSpeedMs / speedMultiplier).round().clamp(_minTickMs, 1000),
      );

  /// A self-rescheduling timer: each tick re-reads the current speed, so the
  /// game actually speeds up as you eat (the old code locked speed at start).
  void _scheduleTick() {
    _gameTimer?.cancel();
    _gameTimer = Timer(_tickDuration, _tick);
  }

  void _tick() {
    if (gameState != GameState.playing) return;
    _step();
    if (gameState == GameState.playing) _scheduleTick();
  }

  void startGame() {
    if (gameState == GameState.notStarted ||
        gameState == GameState.gameOver) {
      _emitState(GameState.playing);
      _scheduleTick();
    }
  }

  void togglePause() {
    if (gameState == GameState.playing) {
      _gameTimer?.cancel();
      _emitState(GameState.paused);
    } else if (gameState == GameState.paused) {
      _emitState(GameState.playing);
      _scheduleTick();
    }
  }

  void resetGame() {
    _gameTimer?.cancel();
    setState(_initGame);
    widget.onStateChanged?.call(gameState);
  }

  void setGameMode(String mode) {
    if (gameMode == mode) return;
    gameMode = mode;
    resetGame();
  }

  // ---------------------------------------------------------------------------
  // Movement
  // ---------------------------------------------------------------------------

  void _step() {
    // Commit the queued direction, then pull in any buffered second turn.
    direction = nextDirection;
    if (_bufferedDirection != null) {
      nextDirection = _bufferedDirection!;
      _bufferedDirection = null;
    }

    final head = snake.first;
    int nx = head.x;
    int ny = head.y;
    switch (direction) {
      case Direction.up:
        ny -= 1;
        break;
      case Direction.down:
        ny += 1;
        break;
      case Direction.left:
        nx -= 1;
        break;
      case Direction.right:
        nx += 1;
        break;
    }

    // Walls mode: the border is solid. Everything else wraps around.
    if (gameMode == 'walls') {
      if (nx < 0 || nx >= gridSize || ny < 0 || ny >= gridSize) {
        _gameOver();
        return;
      }
    } else {
      nx = (nx + gridSize) % gridSize;
      ny = (ny + gridSize) % gridSize;
    }

    final newHead = Position(nx, ny);

    if (_isObstacle(newHead)) {
      _gameOver();
      return;
    }

    // Collide with self (the tail is excluded — it's about to move away).
    final willEat = newHead == food;
    final body = willEat ? snake : snake.sublist(0, snake.length - 1);
    if (body.contains(newHead)) {
      _gameOver();
      return;
    }

    setState(() {
      snake.insert(0, newHead);
      if (willEat) {
        _eatFood();
      } else {
        snake.removeLast();
      }
      if (snake.length > maxLength) maxLength = snake.length;
    });
  }

  void _eatFood() {
    final int points;
    switch (foodType) {
      case FoodType.special:
        points = 25;
        break;
      case FoodType.bonus:
        points = 15;
        break;
      case FoodType.normal:
        points = 10;
        break;
    }
    score += points;
    foodEaten++;

    Provider.of<HapticsProvider>(context, listen: false).light();

    speedMultiplier = (speedMultiplier + _speedStep).clamp(1.0, _speedCap);
    if (speedMultiplier > maxSpeed) maxSpeed = speedMultiplier;

    // Chaos mode slowly fills the board with hazards.
    if (gameMode == 'chaos' && obstacles.length < 40 && _random.nextBool()) {
      Position p;
      int tries = 0;
      do {
        p = Position(_random.nextInt(gridSize), _random.nextInt(gridSize));
        tries++;
      } while ((_isObstacle(p) || _isSnake(p)) && tries < 20);
      if (!_isObstacle(p) && !_isSnake(p)) obstacles.add(p);
    }

    _placeFood();
  }

  void _gameOver() {
    _gameTimer?.cancel();
    _emitState(GameState.gameOver);
    widget.onGameOver(GameStats(
      score: score,
      foodEaten: foodEaten,
      maxSpeed: maxSpeed,
      maxLength: maxLength,
      gameMode: gameMode,
    ));
  }

  void changeDirection(Direction newDirection) {
    // The reference for the 180° check is the *queued* direction, not the
    // committed one — this prevents a fast double-turn from reversing into
    // the neck and causing an instant death.
    final reference = nextDirection;
    final isReverse =
        (reference == Direction.up && newDirection == Direction.down) ||
            (reference == Direction.down && newDirection == Direction.up) ||
            (reference == Direction.left && newDirection == Direction.right) ||
            (reference == Direction.right && newDirection == Direction.left);
    if (isReverse || reference == newDirection) return;

    if (gameState == GameState.notStarted) {
      nextDirection = newDirection;
      startGame();
    } else if (gameState == GameState.playing) {
      // Buffer at most one extra turn for this tick.
      _bufferedDirection = newDirection;
      nextDirection = newDirection;
    }
  }

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      changeDirection(Direction.up);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      changeDirection(Direction.down);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyA) {
      changeDirection(Direction.left);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      changeDirection(Direction.right);
    } else if (key == LogicalKeyboardKey.space) {
      if (gameState == GameState.notStarted) {
        startGame();
      } else if (gameState == GameState.playing ||
          gameState == GameState.paused) {
        togglePause();
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _onPanStart(DragStartDetails details) {
    _swipeAnchor = details.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final anchor = _swipeAnchor;
    if (anchor == null) return;
    final delta = details.localPosition - anchor;
    const threshold = 18.0;
    if (delta.distance < threshold) return;

    if (delta.dx.abs() > delta.dy.abs()) {
      changeDirection(delta.dx > 0 ? Direction.right : Direction.left);
    } else {
      changeDirection(delta.dy > 0 ? Direction.down : Direction.up);
    }
    // Re-anchor so a single continuous drag can chain multiple turns.
    _swipeAnchor = details.localPosition;
  }

  void _onTap() {
    if (gameState == GameState.notStarted) {
      startGame();
    } else if (gameState == GameState.paused) {
      togglePause();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDesign.spacingM, vertical: AppDesign.spacingS),
          child: _buildHud(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppDesign.spacingM, 0,
                AppDesign.spacingM, AppDesign.spacingM),
            child: Center(child: _buildBoard()),
          ),
        ),
      ],
    );
  }

  Widget _buildHud() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _HudPill(
          icon: Icons.star_rounded,
          value: '$score',
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
        ),
        _HudPill(
          icon: Icons.straighten,
          value: '${snake.length}',
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
        ),
        _HudPill(
          icon: Icons.speed,
          value: '${speedMultiplier.toStringAsFixed(1)}x',
          background: scheme.tertiaryContainer,
          foreground: scheme.onTertiaryContainer,
        ),
      ],
    );
  }

  Widget _buildBoard() {
    final scheme = Theme.of(context).colorScheme;
    final isWalls = gameMode == 'walls';

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize =
            min(constraints.maxWidth, constraints.maxHeight).floorToDouble();

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKey,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onTap: _onTap,
            child: Container(
              width: boardSize,
              height: boardSize,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: AppDesign.borderLarge,
                border: Border.all(
                  color: isWalls ? scheme.error : scheme.primary,
                  width: isWalls ? 4.0 : 2.5,
                ),
                boxShadow: AppDesign.shadowMedium(context),
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppDesign.radiusLarge - 3),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: SnakeBoardPainter(
                            snake: snake,
                            food: food,
                            foodType: foodType,
                            obstacles: obstacles,
                            gridSize: gridSize,
                            direction: direction,
                            scheme: scheme,
                            pulse: _pulse,
                          ),
                        ),
                      ),
                    ),
                    if (gameState != GameState.playing)
                      Positioned.fill(child: _buildOverlay(boardSize, scheme)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlay(double size, ColorScheme scheme) {
    final String title;
    final String subtitle;
    final IconData icon;
    final String buttonLabel;
    final VoidCallback action;

    switch (gameState) {
      case GameState.paused:
        title = 'Paused';
        subtitle = 'Take a breather';
        icon = Icons.play_arrow;
        buttonLabel = 'Resume';
        action = togglePause;
        break;
      case GameState.gameOver:
        title = 'Game Over';
        subtitle = 'Score: $score';
        icon = Icons.replay;
        buttonLabel = 'Play Again';
        action = resetGame;
        break;
      case GameState.notStarted:
      default:
        title = 'Snake';
        subtitle = 'Swipe or use arrow keys to move';
        icon = Icons.play_arrow;
        buttonLabel = 'Start';
        action = startGame;
        break;
    }

    return Container(
      color: scheme.surface.withValues(alpha: 0.82),
      alignment: Alignment.center,
      padding: AppDesign.paddingLarge,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: (size / 9).clamp(28.0, 56.0),
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: AppDesign.spacingS),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDesign.spacingL),
          FilledButton.icon(
            onPressed: () {
              Provider.of<HapticsProvider>(context, listen: false).selection();
              action();
            },
            icon: Icon(icon),
            label: Text(buttonLabel),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color background;
  final Color foreground;

  const _HudPill({
    required this.icon,
    required this.value,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppDesign.borderRound,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Board painter — draws the whole board in one pass for smoothness.
/// ---------------------------------------------------------------------------

class SnakeBoardPainter extends CustomPainter {
  final List<Position> snake;
  final Position food;
  final FoodType foodType;
  final List<Position> obstacles;
  final int gridSize;
  final Direction direction;
  final ColorScheme scheme;
  final Animation<double> pulse;

  SnakeBoardPainter({
    required this.snake,
    required this.food,
    required this.foodType,
    required this.obstacles,
    required this.gridSize,
    required this.direction,
    required this.scheme,
    required this.pulse,
  }) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / gridSize;
    _paintGrid(canvas, size, cell);
    _paintObstacles(canvas, cell);
    _paintFood(canvas, cell);
    _paintSnake(canvas, cell);
  }

  Offset _center(Position p, double cell) =>
      Offset((p.x + 0.5) * cell, (p.y + 0.5) * cell);

  void _paintGrid(Canvas canvas, Size size, double cell) {
    final paint = Paint()
      ..color = scheme.onSurface.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (int i = 1; i < gridSize; i++) {
      final d = cell * i;
      canvas.drawLine(Offset(d, 0), Offset(d, size.height), paint);
      canvas.drawLine(Offset(0, d), Offset(size.width, d), paint);
    }
  }

  void _paintObstacles(Canvas canvas, double cell) {
    final paint = Paint()..color = scheme.onSurfaceVariant.withValues(alpha: 0.85);
    final radius = Radius.circular(cell * 0.18);
    for (final p in obstacles) {
      final rect = Rect.fromLTWH(
        p.x * cell + cell * 0.08,
        p.y * cell + cell * 0.08,
        cell * 0.84,
        cell * 0.84,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    }
  }

  void _paintFood(Canvas canvas, double cell) {
    final center = _center(food, cell);
    final scale = 1.0 + pulse.value * 0.14;

    switch (foodType) {
      case FoodType.normal:
        final r = cell * 0.30 * scale;
        canvas.drawCircle(center, r, Paint()..color = scheme.error);
        // little highlight
        canvas.drawCircle(
          center.translate(-r * 0.3, -r * 0.3),
          r * 0.28,
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );
        break;
      case FoodType.bonus:
        final half = cell * 0.30 * scale;
        final rect = Rect.fromCenter(
            center: center, width: half * 2, height: half * 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.12)),
          Paint()..color = scheme.secondary,
        );
        break;
      case FoodType.special:
        // Glow + star — clearly the high-value pickup.
        canvas.drawCircle(
          center,
          cell * 0.46 * scale,
          Paint()..color = scheme.tertiary.withValues(alpha: 0.25),
        );
        canvas.drawPath(
          _starPath(center, cell * 0.40 * scale),
          Paint()..color = scheme.tertiary,
        );
        break;
    }
  }

  Path _starPath(Offset c, double radius) {
    final path = Path();
    const points = 5;
    final inner = radius * 0.45;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : inner;
      final angle = -pi / 2 + i * pi / points;
      final p = Offset(c.dx + r * cos(angle), c.dy + r * sin(angle));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  void _paintSnake(Canvas canvas, double cell) {
    if (snake.isEmpty) return;

    // Body drawn as one continuous rounded tube, broken at wrap-around jumps.
    final bodyPaint = Paint()
      ..color = scheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.74
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final path = Path();
    bool started = false;
    Position? prev;
    for (final seg in snake) {
      final c = _center(seg, cell);
      if (!started) {
        path.moveTo(c.dx, c.dy);
        started = true;
      } else {
        final adjacent = (seg.x - prev!.x).abs() + (seg.y - prev.y).abs() == 1;
        adjacent ? path.lineTo(c.dx, c.dy) : path.moveTo(c.dx, c.dy);
      }
      prev = seg;
    }
    canvas.drawPath(path, bodyPaint);

    _paintHead(canvas, cell, _center(snake.first, cell));
  }

  void _paintHead(Canvas canvas, double cell, Offset center) {
    final headRadius = cell * 0.44 * (1.0 + pulse.value * 0.05);
    canvas.drawCircle(center, headRadius, Paint()..color = scheme.primary);

    // Forward / perpendicular unit vectors based on travel direction.
    late Offset fwd;
    switch (direction) {
      case Direction.up:
        fwd = const Offset(0, -1);
        break;
      case Direction.down:
        fwd = const Offset(0, 1);
        break;
      case Direction.left:
        fwd = const Offset(-1, 0);
        break;
      case Direction.right:
        fwd = const Offset(1, 0);
        break;
    }
    final perp = Offset(-fwd.dy, fwd.dx);

    final eyeR = cell * 0.11;
    final pupilR = cell * 0.055;
    final fwdOffset = cell * 0.12;
    final spread = cell * 0.17;

    for (final s in [1.0, -1.0]) {
      final eye = center + fwd * fwdOffset + perp * (spread * s);
      canvas.drawCircle(eye, eyeR, Paint()..color = Colors.white);
      canvas.drawCircle(
        eye + fwd * (cell * 0.03),
        pupilR,
        Paint()..color = Colors.black87,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SnakeBoardPainter oldDelegate) => true;
}
