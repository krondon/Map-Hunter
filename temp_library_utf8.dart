import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../race_track_widget.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../../shared/widgets/animated_cyber_background.dart';

class LibrarySortMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const LibrarySortMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<LibrarySortMinigame> createState() => _LibrarySortMinigameState();
}

class _LibrarySortMinigameState extends State<LibrarySortMinigame> {
  // Game Configuration
  final List<ColorCategory> _categories = [
    ColorCategory(name: 'ROJO', color: Colors.redAccent, icon: Icons.auto_stories),
    ColorCategory(name: 'AZUL', color: Colors.blueAccent, icon: Icons.auto_stories),
    ColorCategory(name: 'VERDE', color: Colors.greenAccent, icon: Icons.auto_stories),
    ColorCategory(name: 'AMARILLO', color: Colors.amberAccent, icon: Icons.auto_stories),
  ];

  late List<BookModel> _missingBooks;
  late List<SlotModel> _shelfSlots;
  
  // Timer State
  late Timer _timer;
  int _secondsRemaining = 45;
  bool _isGameOver = false;
  
  // UI State
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _isVictory = false;

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _initializeGame() {
    _missingBooks = [];
    _shelfSlots = [];

    // Create 2 missing books per category (8 total)
    for (var category in _categories) {
      for (int i = 0; i < 2; i++) {
        final book = BookModel(
          id: Random().nextInt(1000000),
          category: category,
        );
        _missingBooks.add(book);
        
        // Create matching slots in the shelf
        _shelfSlots.add(SlotModel(targetCategory: category));
      }
    }

    // Shuffle both to make it interesting
    _missingBooks.shuffle();
    _shelfSlots.shuffle();
    
    // Add some "filler" books that are already placed to make the library look full
    for (int i = 0; i < 4; i++) {
      final fillerCategory = _categories[Random().nextInt(_categories.length)];
      _shelfSlots.add(SlotModel(
        targetCategory: fillerCategory,
        placedBook: BookModel(id: -1 - i, category: fillerCategory),
        isFixed: true,
      ));
    }
    _shelfSlots.shuffle();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isFrozen) return;

      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _handleTimeOut();
      }
    });
  }

  void _handleTimeOut() {
    _timer.cancel();
    _loseLife("┬íTiempo agotado!");
  }

  void _checkVictory() {
    bool allPlaced = _shelfSlots.every((slot) => slot.placedBook != null);
    if (allPlaced) {
      _handleWin();
    }
  }

  void _handleWin() {
    _timer.cancel();
    setState(() {
      _isGameOver = true;
      _isVictory = true;
    });
    HapticFeedback.heavyImpact();
    _showOverlayState(
      title: "ARCHIVO RESTAURADO",
      message: "Has ordenado todos los n├║cleos de datos.",
      victory: true,
    );
  }

  void _loseLife(String reason) async {
    _timer.cancel();
    int livesLeftCount = await MinigameLogicHelper.executeLoseLife(context);
    
    if (mounted) {
      if (livesLeftCount <= 0) {
        setState(() => _isGameOver = true);
        _showOverlayState(
          title: "SISTEMA BLOQUEADO",
          message: "$reason - Sin vidas.",
        );
      } else {
        _showOverlayState(
          title: "ERROR DE SECTOR",
          message: "$reason -1 Vida.",
          retry: true,
        );
      }
    }
  }

  void _handleGiveUp() {
    _timer.cancel();
    _loseLife("Abandono.");
  }

  void _showOverlayState({required String title, required String message, bool retry = false, bool victory = false}) {
    setState(() {
      _showOverlay = true;
      _overlayTitle = title;
      _overlayMessage = message;
      _canRetry = retry;
      _isVictory = victory;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final player = context.watch<PlayerProvider>().currentPlayer;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const AnimatedCyberBackground(),
          
          SafeArea(
            child: Column(
              children: [
                // 1. TOP HEADER (Requested: Lives, XP and Flag Icon at the top right)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildStatPill(Icons.favorite, "x${gameProvider.lives}", AppTheme.dangerRed),
                      const SizedBox(width: 8),
                      _buildStatPill(Icons.star, "+50 XP", Colors.amber),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: _handleGiveUp,
                        icon: const Icon(Icons.flag, color: AppTheme.dangerRed, size: 22),
                        tooltip: 'Rendirse',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // 2. RACE TRACK
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RaceTrackWidget(
                    leaderboard: gameProvider.leaderboard,
                    currentPlayerId: player?.userId ?? '',
                    totalClues: gameProvider.clues.length,
                  ),
                ),

                // 3. SUB-HEADER (Requested: Timer and Lives BELOW race)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                  child: Row(
                    children: [
                      // Lives Design matched to reference image (simple heart + text)
                      Row(
                        children: [
                          const Icon(Icons.favorite, color: AppTheme.dangerRed, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            "x${gameProvider.lives}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Timer
                      _buildStatPill(Icons.timer_outlined, "${(_secondsRemaining ~/ 60)}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}", _secondsRemaining < 10 ? AppTheme.dangerRed : Colors.white70),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 3. TITLE & INSTRUCTIONS (Smaller to fit more content)
                const Text(
                  "BIBLIOTECA DE DATOS",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 2),
                  child: Text(
                    "Ordena los n├║cleos por color.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ),

                // 4. THE LIBRARY SHELF (Slots)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(15),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white10),
                      boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        childAspectRatio: 0.6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _shelfSlots.length,
                      itemBuilder: (context, index) {
                        final slot = _shelfSlots[index];
                        return _buildShelfSlot(slot);
                      },
                    ),
                  ),
                ),

                // 5. THE SCATTERED BOOKS (Source tray)
                Container(
                  height: 100,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: _missingBooks.isEmpty 
                    ? const Center(child: Text("┬íTodos colocados!", style: TextStyle(color: Colors.white30)))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _missingBooks.length,
                        itemBuilder: (context, index) {
                          final book = _missingBooks[index];
                          return Draggable<BookModel>(
                            data: book,
                            feedback: Opacity(
                              opacity: 0.8,
                              child: _buildBookCore(book, isDragging: true),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _buildBookCore(book),
                            ),
                            child: _buildBookCore(book),
                          );
                        },
                      ),
                ),

                // 6. SURRENDER
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: OutlinedButton(
                    onPressed: _handleGiveUp,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      side: const BorderSide(color: AppTheme.dangerRed, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("RENDIRSE", style: TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),

          if (_showOverlay)
            GameOverOverlay(
              title: _overlayTitle,
              message: _overlayMessage,
              isVictory: _isVictory,
              onRetry: _canRetry ? () {
                setState(() {
                  _showOverlay = false;
                  _isGameOver = false;
                  _isVictory = false;
                  _secondsRemaining = 45;
                  _initializeGame();
                  _startTimer();
                });
              } : null,
              onExit: () {
                if (_isVictory) widget.onSuccess();
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildShelfSlot(SlotModel slot) {
    if (slot.placedBook != null) {
      return _buildBookCore(slot.placedBook!, isFixed: slot.isFixed);
    }

    return DragTarget<BookModel>(
      onWillAccept: (data) => data != null && data.category == slot.targetCategory,
      onAccept: (book) {
        setState(() {
          slot.placedBook = book;
          _missingBooks.removeWhere((b) => b.id == book.id);
        });
        HapticFeedback.mediumImpact();
        _checkVictory();
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHovering 
              ? slot.targetCategory.color.withOpacity(0.4) 
              : Colors.black45,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              bottomLeft: Radius.circular(4),
              topRight: Radius.circular(2),
              bottomRight: Radius.circular(2),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withOpacity(0.4),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              if (isHovering)
                BoxShadow(
                  color: slot.targetCategory.color.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
            ],
            border: Border.all(
              color: isHovering ? slot.targetCategory.color : slot.targetCategory.color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.bookmarks_outlined, 
                  color: slot.targetCategory.color.withOpacity(isHovering ? 0.8 : 0.15),
                  size: 24,
                ),
              ),
              // Directional indicator
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: slot.targetCategory.color.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookCore(BookModel book, {bool isDragging = false, bool isFixed = false}) {
    return Container(
      width: 48,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          bottomLeft: Radius.circular(6),
          topRight: Radius.circular(2),
          bottomRight: Radius.circular(2),
        ),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            book.category.color.withOpacity(0.8),
            book.category.color,
            book.category.color.withOpacity(0.9),
            book.category.color.withOpacity(0.7),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
          if (!isDragging)
            BoxShadow(
              color: book.category.color.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          bottomLeft: Radius.circular(6),
        ),
        child: Stack(
          children: [
            // Spine Ribs (Realistic book detail)
            Positioned(
              top: 10, left: 0, right: 0,
              child: Container(height: 2, color: Colors.black26),
            ),
            Positioned(
              top: 14, left: 0, right: 0,
              child: Container(height: 1, color: Colors.white10),
            ),
            Positioned(
              bottom: 10, left: 0, right: 0,
              child: Container(height: 2, color: Colors.black26),
            ),
            Positioned(
              bottom: 14, left: 0, right: 0,
              child: Container(height: 1, color: Colors.white10),
            ),
            
            // Central Label / Author area
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 25,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(4, (index) => 
                        Container(width: 15, height: 1.5, color: Colors.white24)
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Icon(
                    isFixed ? Icons.lock_clock_outlined : Icons.auto_stories,
                    color: Colors.white30,
                    size: 14,
                  ),
                ],
              ),
            ),
            
            // Top Badge
            Positioned(
              top: 2,
              right: 2,
              child: Icon(Icons.star, color: Colors.white.withOpacity(0.1), size: 10),
            ),

            // Shine overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class ColorCategory {
  final String name;
  final Color color;
  final IconData icon;

  ColorCategory({required this.name, required this.color, required this.icon});
}

class BookModel {
  final int id;
  final ColorCategory category;

  BookModel({required this.id, required this.category});
}

class SlotModel {
  final ColorCategory targetCategory;
  BookModel? placedBook;
  bool isFixed;

  SlotModel({required this.targetCategory, this.placedBook, this.isFixed = false});
}
