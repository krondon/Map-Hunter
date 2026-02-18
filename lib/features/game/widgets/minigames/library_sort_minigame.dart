import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../race_track_widget.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../../shared/widgets/animated_cyber_background.dart';
import '../../../mall/screens/mall_screen.dart';

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
    ColorCategory(
        name: 'ROJO', color: Colors.redAccent, icon: Icons.auto_stories),
    ColorCategory(
        name: 'AZUL', color: Colors.blueAccent, icon: Icons.auto_stories),
    ColorCategory(
        name: 'VERDE', color: Colors.greenAccent, icon: Icons.auto_stories),
    ColorCategory(
        name: 'AMARILLO', color: Colors.amberAccent, icon: Icons.auto_stories),
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
  bool _showShopButton = false;

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

      if (gameProvider.isFrozen) return;

      // [FIX] Pause timer if connectivity is bad
      final connectivityByProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivityByProvider.isOnline) {
        return; // Skip tick
      }

      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _handleTimeOut();
      }
    });
  }

  void _handleTimeOut() {
    _timer.cancel();
    _loseLife("¡Tiempo agotado!");
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
    widget.onSuccess();
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

  void _showOverlayState(
      {required String title,
      required String message,
      bool retry = false,
      bool victory = false}) {
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
    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 5),

            // BARRA DE ESTADO (Vidas, Progreso y Tiempo)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  _buildStatPill(
                      Icons.favorite,
                      "x${Provider.of<GameProvider>(context).lives}",
                      AppTheme.dangerRed),
                  const SizedBox(width: 8),
                  _buildStatPill(
                      Icons.inventory_2_outlined,
                      "${_shelfSlots.where((s) => s.placedBook != null).length}/${_shelfSlots.length}",
                      AppTheme.accentGold),
                  const Spacer(),
                  _buildStatPill(
                      Icons.timer_outlined,
                      "${(_secondsRemaining ~/ 60)}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}",
                      _secondsRemaining < 10
                          ? AppTheme.dangerRed
                          : Colors.white70),
                ],
              ),
            ),

            const SizedBox(height: 5),

            // TITLE & INSTRUCTIONS
            const Text(
              "BIBLIOTECA DE DATOS",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  decoration: TextDecoration.none),
            ),
            const Text(
              "Ordena los núcleos por color para restaurar el archivo.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  decoration: TextDecoration.none),
            ),

            // THE LIBRARY SHELF (Slots) - EXPANDED TO FIT
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10)
                  ],
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _shelfSlots.length,
                  itemBuilder: (context, index) =>
                      _buildShelfSlot(_shelfSlots[index]),
                ),
              ),
            ),

            // THE SCATTERED BOOKS (Source tray)
            Container(
              height: 100,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("LIBROS PENDIENTES",
                      style: TextStyle(
                          color: Colors.white24,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none)),
                  Expanded(
                    child: _missingBooks.isEmpty
                        ? const Center(
                            child: Text("¡Todos colocados!",
                                style: TextStyle(
                                    color: AppTheme.successGreen,
                                    decoration: TextDecoration.none,
                                    fontSize: 11)))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _missingBooks.length,
                            itemBuilder: (context, index) {
                              final book = _missingBooks[index];
                              return Draggable<BookModel>(
                                data: book,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Opacity(
                                    opacity: 0.8,
                                    child:
                                        _buildBookCore(book, isDragging: true),
                                  ),
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
                ],
              ),
            ),

            // SURRENDER BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: OutlinedButton(
                onPressed: _handleGiveUp,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  side: BorderSide(
                      color: AppTheme.dangerRed.withOpacity(0.4), width: 1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  "RENDIRSE",
                  style: TextStyle(
                      color: AppTheme.dangerRed.withOpacity(0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
        if (_showOverlay)
          GameOverOverlay(
            title: _overlayTitle,
            message: _overlayMessage,
            isVictory: _isVictory,
            onRetry: _canRetry
                ? () {
                    setState(() {
                      _showOverlay = false;
                      _isGameOver = false;
                      _isVictory = false;
                      _secondsRemaining = 45;
                      _initializeGame();
                      _startTimer();
                    });
                  }
                : null,
            onGoToShop: _showShopButton
                ? () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MallScreen()));
                    if (mounted) {
                      setState(() {
                        _canRetry = true;
                        _showShopButton = false;
                      });
                    }
                  }
                : null,
            onExit: () {
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  Widget _buildShelfSlot(SlotModel slot) {
    if (slot.placedBook != null) {
      return _buildBookCore(slot.placedBook!, isFixed: slot.isFixed);
    }

    return DragTarget<BookModel>(
      onWillAccept: (data) {
        // [FIX] Prevent interaction if offline
        final connectivity =
            Provider.of<ConnectivityProvider>(context, listen: false);
        if (!connectivity.isOnline) return false;

        return data != null && data.category == slot.targetCategory;
      },
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
              color: isHovering
                  ? slot.targetCategory.color
                  : slot.targetCategory.color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.bookmarks_outlined,
                  color: slot.targetCategory.color
                      .withOpacity(isHovering ? 0.8 : 0.15),
                  size: 24,
                ),
              ),
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

  Widget _buildBookCore(BookModel book,
      {bool isDragging = false, bool isFixed = false}) {
    return Container(
      width: 48,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
            Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Container(height: 2, color: Colors.black26)),
            Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Container(height: 1, color: Colors.white10)),
            Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Container(height: 2, color: Colors.black26)),
            Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Container(height: 1, color: Colors.white10)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 35,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                          4,
                          (index) => Container(
                              width: 12, height: 1.5, color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    isFixed ? Icons.lock_clock_outlined : Icons.auto_stories,
                    color: Colors.white30,
                    size: 14,
                  ),
                ],
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  decoration: TextDecoration.none)),
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

  SlotModel(
      {required this.targetCategory, this.placedBook, this.isFixed = false});
}
