import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

class MediaEditorScreen extends StatefulWidget {
  final File imageFile;

  const MediaEditorScreen({super.key, required this.imageFile});

  @override
  State<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends State<MediaEditorScreen> {
  final GlobalKey _globalKey = GlobalKey();
  List<DrawnLine> lines = [];
  DrawnLine? currentLine;
  Color selectedColor = Colors.red;
  double strokeWidth = 5.0;
<<<<<<< HEAD
=======
  bool isViewOnce = false;
  bool isBlurMode = false;
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75

  Future<void> _saveAndReturn() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/edited_image_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(pngBytes);

<<<<<<< HEAD
      if (mounted) Navigator.pop(context, file);
    } catch (e) {
      if (mounted) Navigator.pop(context, widget.imageFile); // Fallback to original
=======
      if (mounted) Navigator.pop(context, {'file': file, 'isViewOnce': isViewOnce, 'caption': _captionController.text});
    } catch (e) {
      if (mounted) Navigator.pop(context, {'file': widget.imageFile, 'isViewOnce': isViewOnce, 'caption': _captionController.text}); // Fallback to original
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
    }
  }

  void onPanStart(DragStartDetails details) {
    RenderBox box = context.findRenderObject() as RenderBox;
    Offset point = box.globalToLocal(details.globalPosition);
    setState(() {
<<<<<<< HEAD
      currentLine = DrawnLine([point], selectedColor, strokeWidth);
=======
      currentLine = DrawnLine([point], selectedColor, strokeWidth, isBlur: isBlurMode);
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
    });
  }

  void onPanUpdate(DragUpdateDetails details) {
    RenderBox box = context.findRenderObject() as RenderBox;
    Offset point = box.globalToLocal(details.globalPosition);
    setState(() {
      currentLine?.path.add(point);
    });
  }

  void onPanEnd(DragEndDetails details) {
    setState(() {
      if (currentLine != null) {
        lines.add(currentLine!);
        currentLine = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
<<<<<<< HEAD
=======
            icon: Icon(Icons.blur_on, color: isBlurMode ? Colors.blue : Colors.white),
            onPressed: () => setState(() => isBlurMode = !isBlurMode),
          ),
          IconButton(
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
            icon: const Icon(Icons.undo),
            onPressed: () {
              setState(() {
                if (lines.isNotEmpty) lines.removeLast();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.blue),
            onPressed: _saveAndReturn,
          )
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: RepaintBoundary(
              key: _globalKey,
              child: Stack(
                children: [
                  Image.file(widget.imageFile, fit: BoxFit.contain),
                  Positioned.fill(
                    child: GestureDetector(
                      onPanStart: onPanStart,
                      onPanUpdate: onPanUpdate,
                      onPanEnd: onPanEnd,
                      child: CustomPaint(
                        painter: DrawingPainter(lines, currentLine),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
<<<<<<< HEAD
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _colorWidget(Colors.red),
                  _colorWidget(Colors.blue),
                  _colorWidget(Colors.green),
                  _colorWidget(Colors.yellow),
                  _colorWidget(Colors.white),
                  _colorWidget(Colors.black),
                ],
              ),
=======
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => isViewOnce = !isViewOnce),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isViewOnce ? Colors.blue : Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.looks_one, color: isViewOnce ? Colors.white : Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isViewOnce ? "Одноразовый просмотр ВКЛ" : "Одноразовый просмотр",
                          style: TextStyle(color: isViewOnce ? Colors.white : Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _captionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Добавьте подпись...",
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black45,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _colorWidget(Colors.red),
                      _colorWidget(Colors.blue),
                      _colorWidget(Colors.green),
                      _colorWidget(Colors.yellow),
                      _colorWidget(Colors.white),
                      _colorWidget(Colors.black),
                    ],
                  ),
                ),
              ],
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
            ),
          )
        ],
      ),
    );
  }

  Widget _colorWidget(Color color) {
    bool isSelected = selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => selectedColor = color),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
        ),
      ),
    );
  }
}

class DrawnLine {
  final List<Offset> path;
  final Color color;
  final double width;
<<<<<<< HEAD
  DrawnLine(this.path, this.color, this.width);
=======
  final bool isBlur;
  DrawnLine(this.path, this.color, this.width, {this.isBlur = false});
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
}

class DrawingPainter extends CustomPainter {
  final List<DrawnLine> lines;
  final DrawnLine? currentLine;

  DrawingPainter(this.lines, this.currentLine);

  @override
  void paint(Canvas canvas, Size size) {
    for (var line in lines) {
      _drawLine(canvas, line);
    }
    if (currentLine != null) {
      _drawLine(canvas, currentLine!);
    }
  }

  void _drawLine(Canvas canvas, DrawnLine line) {
    if (line.path.isEmpty) return;
    final paint = Paint()
<<<<<<< HEAD
      ..color = line.color
=======
      ..color = line.isBlur ? Colors.white.withValues(alpha: 0.1) : line.color
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
      ..strokeWidth = line.width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

<<<<<<< HEAD
=======
    if (line.isBlur) {
      paint.imageFilter = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10);
    }

>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
    final path = Path();
    path.moveTo(line.path.first.dx, line.path.first.dy);
    for (int i = 1; i < line.path.length; i++) {
      path.lineTo(line.path[i].dx, line.path[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
