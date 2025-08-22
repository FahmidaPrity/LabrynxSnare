import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  static const int gridSize = 9;
  static const Color darkCyan = Color(0xFF008B8B);

  double cellSize = 64;

  late List<List<int>> labyrinth;
  late List<int> playerPos;
  late List<int> ghostPos;
  late Set<List<int>> revealedTraps;
  late List<int> exitPos;

  String gameState = "playing";
  Timer? ghostTimer;

  double playerOpacity = 1.0;
  double playerScale = 1.0;

  bool showOhNo = false;
  late AnimationController _ohNoController;
  late Animation<double> _ohNoScale;

  static const String _playerPath = "assets/images/player.png";
  static const String _exitPath = "assets/images/exit.png";
  static const String _trapPath = "assets/images/trap.png";
  static const String _floorPath = "assets/images/floor.jpg";
  static const String _ghostPath = "assets/images/ghost.png";
  static const String _safePath = "assets/images/safe.jpg";
  static const String _bgPath = "assets/images/bg_game.jpg";

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _ohNoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _ohNoScale = CurvedAnimation(
      parent: _ohNoController,
      curve: Curves.easeOutBack,
    );
    restartGame();
  }

  @override
  void dispose() {
    ghostTimer?.cancel();
    _focusNode.dispose();
    _ohNoController.dispose();
    super.dispose();
  }

  Widget _img(String path) => Image.asset(path, fit: BoxFit.cover);

  void restartGame() {
    final rand = Random();

    labyrinth = List.generate(
      gridSize,
      (_) => List.generate(gridSize, (_) => 0),
    );

    exitPos = [gridSize - 1, gridSize - 1];
    labyrinth[exitPos[1]][exitPos[0]] = 2;

    for (int i = 0; i < gridSize * 2; i++) {
      int x = rand.nextInt(gridSize);
      int y = rand.nextInt(gridSize);
      if (!((x == 0 && y == 0) || (x == exitPos[0] && y == exitPos[1]))) {
        labyrinth[y][x] = 1;
      }
    }

    labyrinth[0][0] = 3;
    if (gridSize > 1) {
      labyrinth[0][1] = 3;
      labyrinth[1][0] = 3;
    }
    for (int i = 0; i < 3; i++) {
      while (true) {
        int x = rand.nextInt(gridSize);
        int y = rand.nextInt(gridSize);
        if (labyrinth[y][x] == 0 && !(x == exitPos[0] && y == exitPos[1])) {
          labyrinth[y][x] = 3;
          break;
        }
      }
    }

    playerPos = [0, 0];
    ghostPos = [gridSize ~/ 2, gridSize ~/ 2];
    revealedTraps = <List<int>>{};

    gameState = "playing";
    playerOpacity = 1.0;
    playerScale = 1.0;
    showOhNo = false;

    ghostTimer?.cancel();
    ghostTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (gameState == "playing") moveGhost();
    });

    setState(() {});
  }

  void disappearOhNo() {
    setState(() {
      showOhNo = true;
    });
    _ohNoController.forward(from: 0.0);

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        showOhNo = false;
        playerScale = 0.0;
        playerOpacity = 0.0;
      });
    });
  }

  void triggerLose() {
    setState(() {
      gameState = "lose";
    });
    disappearOhNo();
  }

  void triggerWin() {
    setState(() {
      gameState = "win";
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        playerScale = 0.0;
        playerOpacity = 0.0;
      });
    });
  }

  void moveGhost() {
    int gx = ghostPos[0], gy = ghostPos[1];
    int px = playerPos[0], py = playerPos[1];
    final rand = Random();

    int nx = gx, ny = gy;

    if (gx == px) {
      int step = (py > gy) ? 1 : -1;
      ny = gy + step;
    } else if (gy == py) {
      int step = (px > gx) ? 1 : -1;
      nx = gx + step;
    } else {
      const moves = [
        [1, 0],
        [-1, 0],
        [0, 1],
        [0, -1],
      ];
      final move = moves[rand.nextInt(moves.length)];
      nx = (gx + move[0]).clamp(0, gridSize - 1);
      ny = (gy + move[1]).clamp(0, gridSize - 1);
    }
    if (labyrinth[ny][nx] != 3) {
      ghostPos = [nx, ny];
    }
    if (ghostPos[0] == playerPos[0] && ghostPos[1] == playerPos[1]) {
      triggerLose();
    }
    setState(() {});
  }

  void revealAdjacentTraps(int x, int y) {
    const directions = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
      [1, 1],
      [1, -1],
      [-1, 1],
      [-1, -1],
    ];
    for (var d in directions) {
      final nx = x + d[0];
      final ny = y + d[1];
      if (nx >= 0 && nx < gridSize && ny >= 0 && ny < gridSize) {
        if (labyrinth[ny][nx] == 1) revealedTraps.add([nx, ny]);
      }
    }
  }

  void movePlayer(int dx, int dy) {
    if (gameState != "playing") return;

    final nx = (playerPos[0] + dx).clamp(0, gridSize - 1);
    final ny = (playerPos[1] + dy).clamp(0, gridSize - 1);

    final cell = labyrinth[ny][nx];
    playerPos = [nx, ny];

    if (cell == 1) {
      revealedTraps.add([nx, ny]);
      setState(() {});
      triggerLose();
    } else if (cell == 2) {
      setState(() {});
      triggerWin();
    } else {
      revealAdjacentTraps(nx, ny);
      setState(() {});
    }
  }

  Widget buildCell(int x, int y) {
    final cell = labyrinth[y][x];
    Widget content = SizedBox.expand(child: _img(_floorPath));

    if (cell == 2) {
      content = Stack(
        children: [
          content,
          SizedBox.expand(child: _img(_exitPath)),
        ],
      );
    }
    if (cell == 3) {
      content = Stack(
        children: [
          content,
          SizedBox.expand(child: _img(_safePath)),
        ],
      );
    }
    if (revealedTraps.any((t) => t[0] == x && t[1] == y)) {
      content = Stack(
        children: [
          content,
          SizedBox.expand(child: _img(_trapPath)),
        ],
      );
    }
    if (playerPos[0] == x && playerPos[1] == y) {
      final playerWidget = SizedBox.expand(child: _img(_playerPath));
      content = Stack(
        children: [
          content,
          AnimatedScale(
            scale: playerScale,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeIn,
            child: AnimatedOpacity(
              opacity: playerOpacity,
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeIn,
              child: playerWidget,
            ),
          ),
        ],
      );
    }

    if (ghostPos[0] == x && ghostPos[1] == y) {
      content = Stack(
        children: [
          content,
          SizedBox.expand(child: _img(_ghostPath)),
        ],
      );
    }
    return SizedBox(width: cellSize, height: cellSize, child: content);
  }

  Widget _statusOverlay() {
    if (gameState == "playing") return const SizedBox.shrink();

    if (showOhNo) {
      return Center(
        child: ScaleTransition(
          scale: _ohNoScale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: darkCyan.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(
                  color: darkCyan.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Text(
              "Aaaaaa!",
              style: GoogleFonts.pressStart2p(
                fontSize: 28,
                color: const Color(0xFF8B0000),
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: darkCyan.withOpacity(0.5)),
        ),
        child: Text(
          gameState == "win" ? "Victory!" : "Defeated...",
          style: GoogleFonts.pressStart2p(
            fontSize: 20,
            color: gameState == "win" ? darkCyan : const Color(0xFF8B0000),
          ),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onPressed, double iconSize) {
    const double hitBox = 52.0;
    return Material(
      color: Colors.black.withOpacity(0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints.tightFor(
            width: hitBox,
            height: hitBox,
          ),
          child: Center(
            child: Icon(icon, size: iconSize, color: darkCyan),
          ),
        ),
      ),
    );
  }

  Widget _dpad(double iconSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circleButton(
          Icons.keyboard_arrow_up,
          () => movePlayer(0, -1),
          iconSize,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _circleButton(
              Icons.keyboard_arrow_left,
              () => movePlayer(-1, 0),
              iconSize,
            ),
            const SizedBox(width: 16),
            _circleButton(
              Icons.keyboard_arrow_right,
              () => movePlayer(1, 0),
              iconSize,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _circleButton(
          Icons.keyboard_arrow_down,
          () => movePlayer(0, 1),
          iconSize,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final double arrowIconSize = (screenWidth * 0.08)
        .clamp(22.0, 28.0)
        .toDouble();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: Image.asset(_bgPath, fit: BoxFit.cover)),
            RawKeyboardListener(
              focusNode: _focusNode..requestFocus(),
              autofocus: true,
              onKey: (RawKeyEvent event) {
                if (event is RawKeyDownEvent && gameState == "playing") {
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                      event.logicalKey == LogicalKeyboardKey.keyW) {
                    movePlayer(0, -1);
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                      event.logicalKey == LogicalKeyboardKey.keyS) {
                    movePlayer(0, 1);
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                      event.logicalKey == LogicalKeyboardKey.keyA) {
                    movePlayer(-1, 0);
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                      event.logicalKey == LogicalKeyboardKey.keyD) {
                    movePlayer(1, 0);
                  }
                }
              },
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final usableHeight = constraints.maxHeight * 0.75;
                          final boardSize = min(
                            constraints.maxWidth,
                            usableHeight,
                          );
                          cellSize = boardSize / gridSize;

                          return SizedBox(
                            width: boardSize,
                            height: boardSize,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: gridSize,
                                    childAspectRatio: 1.0,
                                  ),
                              itemBuilder: (_, i) {
                                final x = i % gridSize;
                                final y = i ~/ gridSize;
                                return buildCell(x, y);
                              },
                              itemCount: gridSize * gridSize,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (gameState != "playing")
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: restartGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkCyan,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Again?"),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Run!"),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            if (gameState == "playing")
              Positioned(
                right: 24,
                bottom: screenHeight * 0.05,
                child: _dpad(arrowIconSize),
              ),
            _statusOverlay(),
          ],
        ),
      ),
    );
  }
}
