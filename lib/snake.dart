import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'main.dart';
import 'package:flutter/src/painting/box_border.dart' as border;

class SnakePage extends StatefulWidget {
  const SnakePage({Key? key}) : super(key: key);

  @override
  _SnakePageState createState() => _SnakePageState();
}

class _SnakePageState extends State<SnakePage> {
  List<SnakeScore> _topScores = [];
  bool _isLoading = true;
  GlobalKey<_SnakeGameState> _gameKey = GlobalKey<_SnakeGameState>();
  double _leaderboardPosition = 0;
  bool _isDragging = false;
  double _dragStartY = 0;
  final double _maxDragHeight = 300;
  static const double boardSize = 320.0;
  
  @override
  void initState() {
    super.initState();
    _fetchTopScores();
  }

  Future<void> _fetchTopScores() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await supabase
          .from('snake_scores')
          .select('*, profiles!inner(name)')
          .order('score', ascending: false)
          .limit(5);

      setState(() {
        _topScores = response.map<SnakeScore>((json) => SnakeScore.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching scores: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveScore(int score) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('snake_scores').insert({
        'user_id': userId,
        'score': score,
      });

      await _fetchTopScores();
    } catch (e) {
      print('Error saving score: $e');
    }
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStartY = details.globalPosition.dy + _leaderboardPosition;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    setState(() {
      double newPosition = _dragStartY - details.globalPosition.dy;
      _leaderboardPosition = newPosition.clamp(0, _maxDragHeight);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      if (_leaderboardPosition > _maxDragHeight / 2) {
        _leaderboardPosition = _maxDragHeight;
      } else {
        _leaderboardPosition = 0;
      }
    });
  }

  void _onGameOver(int score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Game Over'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                'Score: $score',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_topScores.isEmpty || score > (_topScores.last.score))
              Container(
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
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'New High Score! 🎉',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Save Score'),
            onPressed: () async {
              await _saveScore(score);
              Navigator.of(context).pop();
              _gameKey.currentState?.resetGame();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Play Again'),
            onPressed: () {
              Navigator.of(context).pop();
              _gameKey.currentState?.resetGame();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate available height for game area
    double screenHeight = MediaQuery.of(context).size.height;
    double gameAreaHeight = screenHeight - _leaderboardPosition - 100; // Account for app bar

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        title: Text(
          'Snake',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Centered Game Board
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: gameAreaHeight,
            child: Center(
              child: Container(
                width: boardSize,
                height: boardSize * 1.5, // Maintain 2:3 aspect ratio
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2.0,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SnakeGame(
                  key: _gameKey,
                  onGameOver: _onGameOver,
                ),
              ),
            ),
          ),
          
          // Draggable Leaderboard
          Positioned(
            bottom: -_maxDragHeight + _leaderboardPosition,
            left: 0,
            right: 0,
            height: _maxDragHeight + 50, // Extra height for drag handle
            child: GestureDetector(
              onVerticalDragStart: _handleDragStart,
              onVerticalDragUpdate: _handleDragUpdate,
              onVerticalDragEnd: _handleDragEnd,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag Handle
                    Container(
                      height: 50,
                      alignment: Alignment.center,
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    
                    // Leaderboard Content
                    Expanded(
                      child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _topScores.isEmpty
                          ? Center(
                              child: Text(
                                'No scores yet. Be the first!',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _topScores.length,
                              itemBuilder: (context, index) {
                                final score = _topScores[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: index == 0
                                        ? Theme.of(context).colorScheme.tertiaryContainer
                                        : Theme.of(context).colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: index == 0
                                          ? Theme.of(context).colorScheme.tertiary
                                          : Theme.of(context).colorScheme.primary,
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: index == 0
                                              ? Theme.of(context).colorScheme.onTertiary
                                              : Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      score.playerName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: index == 0
                                            ? Theme.of(context).colorScheme.onTertiaryContainer
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: index == 0
                                            ? Theme.of(context).colorScheme.tertiary
                                            : Theme.of(context).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${score.score} pts',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: index == 0
                                              ? Theme.of(context).colorScheme.onTertiary
                                              : Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SnakeScore {
  final String userId;
  final String playerName;
  final int score;
  final DateTime createdAt;

  SnakeScore({
    required this.userId,
    required this.playerName,
    required this.score,
    required this.createdAt,
  });

  factory SnakeScore.fromJson(Map<String, dynamic> json) {
    return SnakeScore(
      userId: json['user_id'],
      playerName: json['profiles']['name'],
      score: json['score'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

enum Direction { up, down, left, right }

class SnakeGame extends StatefulWidget {
  final Function(int) onGameOver;
  
  const SnakeGame({Key? key, required this.onGameOver}) : super(key: key);

  @override
  _SnakeGameState createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> {
  static const int squaresPerRow = 20;
  static const int squaresPerCol = 30;
  static const double boardSize = 320.0;
  final int updateRate = 200;

  List<Offset> snakePositions = [];
  Offset? food;
  Direction direction = Direction.right;
  Timer? timer;
  int score = 0;
  bool isPlaying = false;
  GlobalKey boardKey = GlobalKey();
  Offset? swipeStart;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    snakePositions = [
      const Offset(squaresPerRow / 2, squaresPerCol / 2),
    ];
    direction = Direction.right;
    score = 0;
    _placeFood();
    if (timer?.isActive ?? false) timer?.cancel();
  }

  void _placeFood() {
    Random random = Random();
    double x, y;
    do {
      x = random.nextInt(squaresPerRow).toDouble();
      y = random.nextInt(squaresPerCol).toDouble();
    } while (snakePositions.contains(Offset(x, y)));
    food = Offset(x, y);
  }

  void _startGame() {
    isPlaying = true;
    timer = Timer.periodic(Duration(milliseconds: updateRate), (timer) {
      _updateGame();
    });
  }

  void _updateGame() {
    setState(() {
      _moveSnake();
      _checkForFood();
      if (_checkForCollision()) {
        _gameOver();
      }
    });
  }

  void resetGame() {
    setState(() {
      _initGame();
      isPlaying = false;
      if (timer?.isActive ?? false) {
        timer?.cancel();
      }
    });
  }

  void _moveSnake() {
    Offset head = snakePositions.first;
    Offset newHead;

    switch (direction) {
      case Direction.up:
        newHead = Offset(head.dx, (head.dy - 1) % squaresPerCol);
        break;
      case Direction.down:
        newHead = Offset(head.dx, (head.dy + 1) % squaresPerCol);
        break;
      case Direction.left:
        newHead = Offset((head.dx - 1) % squaresPerRow, head.dy);
        break;
      case Direction.right:
        newHead = Offset((head.dx + 1) % squaresPerRow, head.dy);
        break;
    }

    snakePositions.insert(0, newHead);
    if (food != newHead) {
      snakePositions.removeLast();
    }
  }

  void _checkForFood() {
    if (snakePositions.first == food) {
      score += 10;
      _placeFood();
    }
  }

  bool _checkForCollision() {
    Offset head = snakePositions.first;
    
    // Check for self collision
    for (int i = 1; i < snakePositions.length; i++) {
      if (snakePositions[i] == head) return true;
    }
    
    return false;
  }

  void _gameOver() {
    timer?.cancel();
    isPlaying = false;
    widget.onGameOver(score);
  }

  void _onKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (!isPlaying) {
        _startGame();
        return;
      }

      setState(() {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp && direction != Direction.down) {
          direction = Direction.up;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && direction != Direction.up) {
          direction = Direction.down;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && direction != Direction.right) {
          direction = Direction.left;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && direction != Direction.left) {
          direction = Direction.right;
        }
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: _onKeyEvent,
      child: GestureDetector(
        onPanStart: (details) {
          if (!isPlaying) {
            _startGame();
            return;
          }
          swipeStart = details.localPosition;
        },
        onPanUpdate: (details) {
          if (swipeStart == null) return;
          
          final swipeDirection = details.localPosition - swipeStart!;
          if (swipeDirection.distance < 20) return;
          
          final angle = swipeDirection.direction;
          setState(() {
            if (angle > -pi/4 && angle <= pi/4 && direction != Direction.left) {
              direction = Direction.right;
            } else if (angle > pi/4 && angle <= 3*pi/4 && direction != Direction.up) {
              direction = Direction.down;
            } else if ((angle > 3*pi/4 || angle <= -3*pi/4) && direction != Direction.right) {
              direction = Direction.left;
            } else if (angle > -3*pi/4 && angle <= -pi/4 && direction != Direction.down) {
              direction = Direction.up;
            }
          });
          swipeStart = null;
        },
        child: Container(
          key: boardKey,
          width: boardSize,
          height: boardSize * squaresPerCol / squaresPerRow,
          decoration: BoxDecoration(
            border: border.Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              // Draw snake
              ...snakePositions.map((position) {
                return Positioned(
                  left: position.dx * boardSize / squaresPerRow,
                  top: position.dy * boardSize / squaresPerRow,
                  child: Container(
                    width: boardSize / squaresPerRow,
                    height: boardSize / squaresPerRow,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
              // Draw food
              if (food != null)
                Positioned(
                  left: food!.dx * boardSize / squaresPerRow,
                  top: food!.dy * boardSize / squaresPerRow,
                  child: Container(
                    width: boardSize / squaresPerRow,
                    height: boardSize / squaresPerRow,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              // Show start message
              if (!isPlaying)
                Center(
                  child: Text(
                    'Press any arrow key or swipe to start',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // Show score
              Positioned(
                right: 8,
                top: 8,
                child: Text(
                  'Score: $score',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}