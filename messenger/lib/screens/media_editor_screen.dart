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

  Future<void> _saveAndReturn() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/edited_image_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(pngBytes);

      if (mounted) Navigator.pop(context, file);
    } catch (e) {
      if (mounted) Navigator.pop(context, widget.imageFile); // Fallback to original
    }
  }

  void onPanStart(DragStartDetails details) {
    RenderBox box = context.findRenderObject() as RenderBox;
    Offset point = box.globalToLocal(details.globalPosition);
    setState(() {
      currentLine = DrawnLine([point], selectedColor, strokeWidth);
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
  DrawnLine(this.path, this.color, this.width);
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
      ..color = line.color
      ..strokeWidth = line.width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

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
