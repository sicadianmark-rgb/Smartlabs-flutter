import 'dart:convert';
import 'package:flutter/material.dart';

// Note: Signature is stored as base64-encoded JSON string
// Format: {"points": [{"x": number, "y": number, "isNewStroke": boolean}], "strokeWidth": number}

class SignaturePad extends StatefulWidget {
  final Function(String?) onSignatureComplete;

  const SignaturePad({super.key, required this.onSignatureComplete});

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<Point> _points = [];
  final double _strokeWidth = 3.0;

  void _onPanStart(DragStartDetails details) {
    final RenderBox? box =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(details.globalPosition);
    debugPrint('PanStart: ${localPosition.dx}, ${localPosition.dy}');
    setState(() {
      _points.add(Point(localPosition.dx, localPosition.dy, true));
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final RenderBox? box =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(details.globalPosition);
    setState(() {
      _points.add(Point(localPosition.dx, localPosition.dy, false));
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      if (_points.isNotEmpty) {
        _points.add(Point(_points.last.x, _points.last.y, true));
      }
    });
  }

  void _clearSignature() {
    setState(() {
      _points.clear();
    });
  }

  void _submitSignature() {
    if (_points.isEmpty) {
      // Ask for confirmation
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('No Signature'),
              content: const Text('Please sign to confirm your request'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    } else {
      // Convert points to base64
      final signature = _convertToBase64();
      widget.onSignatureComplete(signature);
    }
  }

  String _convertToBase64() {
    final signatureData = {
      'points':
          _points
              .map((p) => {'x': p.x, 'y': p.y, 'isNewStroke': p.isNewStroke})
              .toList(),
      'strokeWidth': _strokeWidth,
    };
    // Encode as base64 JSON string as per documented format
    // Format: {"points": [{"x": number, "y": number, "isNewStroke": boolean}], "strokeWidth": number}
    final jsonString = jsonEncode(signatureData);
    final bytes = utf8.encode(jsonString);
    return base64.encode(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isLandscape = screenSize.width > screenSize.height;
    
    // Calculate dynamic dimensions based on screen size
    double dialogWidth = screenSize.width * 0.9;
    double dialogHeight = screenSize.height * 0.8;
    
    // Adjust for larger screens
    if (isTablet) {
      dialogWidth = screenSize.width * 0.7;
      dialogHeight = screenSize.height * 0.7;
    }
    
    // Adjust for landscape orientation
    if (isLandscape) {
      dialogHeight = screenSize.height * 0.9;
    }
    
    // Ensure maximum dimensions for very large screens
    dialogWidth = dialogWidth > 500 ? 500 : dialogWidth;
    dialogHeight = dialogHeight > 700 ? 700 : dialogHeight;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.05,
        vertical: screenSize.height * 0.05,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: EdgeInsets.all(screenSize.width * 0.04),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'E-Signature',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: screenSize.height * 0.01),
            Text(
              'Please sign below to confirm your request',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenSize.height * 0.02),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: RepaintBoundary(
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: CustomPaint(
                        key: _canvasKey,
                        painter: SignaturePainter(_points),
                        size: Size.infinite,
                        child: Container(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: screenSize.height * 0.02),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearSignature,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size.fromHeight(50),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: screenSize.width * 0.03),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _submitSignature,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Confirm & Submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2AA39F),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: screenSize.height * 0.02),
            Center(
              child: TextButton(
                onPressed: () => widget.onSignatureComplete(null),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Point> points;

  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.black
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;

    if (points.isEmpty) {
      // Draw placeholder text when empty
      final placeholder = TextPainter(
        text: TextSpan(
          text: 'Draw your signature here',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      );
      placeholder.layout();
      placeholder.paint(
        canvas,
        Offset(
          (size.width - placeholder.width) / 2,
          (size.height - placeholder.height) / 2,
        ),
      );
      return;
    }

    // Draw all lines between consecutive points
    for (int i = 0; i < points.length - 1; i++) {
      final currentPoint = points[i];
      final nextPoint = points[i + 1];

      // Draw the line connecting these points (ignore isNewStroke for simplicity)
      canvas.drawLine(
        Offset(currentPoint.x, currentPoint.y),
        Offset(nextPoint.x, nextPoint.y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) {
    return true; // Always repaint to ensure smooth drawing
  }
}

class Point {
  final double x;
  final double y;
  final bool isNewStroke;

  Point(this.x, this.y, this.isNewStroke);
}
