import 'package:flutter/material.dart';

class CanvasViewport extends StatefulWidget {
  const CanvasViewport({super.key});

  @override
  State<CanvasViewport> createState() => _CanvasViewportState();
}

class _CanvasViewportState extends State<CanvasViewport> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: isDark ? const Color(0xFF202124) : const Color(0xFFE8E8EC),
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.2,
        maxScale: 4,
        boundaryMargin: const EdgeInsets.all(100000),
        constrained: false,
        child: SizedBox(
          width: 4000,
          height: 4000,
          child: CustomPaint(
            painter: _CanvasGridPainter(
              backgroundColor:
                  isDark ? const Color(0xFF202124) : const Color(0xFFFCFCFD),
              dotColor: isDark
                  ? const Color(0xFF41434A)
                  : const Color(0xFFD5D6DC),
            ),
          ),
        ),
      ),
    );
  }
}

class _CanvasGridPainter extends CustomPainter {
  const _CanvasGridPainter({
    required this.backgroundColor,
    required this.dotColor,
  });

  final Color backgroundColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(backgroundColor, BlendMode.src);

    const spacing = 24.0;
    final paint = Paint()..color = dotColor;

    for (var x = 0.0; x <= size.width; x += spacing) {
      for (var y = 0.0; y <= size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasGridPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.dotColor != dotColor;
  }
}
