import 'package:flutter/material.dart';

import 'package:simple_edge_detection/edge_detection.dart';

class EdgeDetectionPreview extends StatefulWidget {
  EdgeDetectionPreview({required this.edgeDetectionResult});

  final EdgeDetectionResult? edgeDetectionResult;

  @override
  _EdgeDetectionPreviewState createState() => _EdgeDetectionPreviewState();
}

class _EdgeDetectionPreviewState extends State<EdgeDetectionPreview>
    with SingleTickerProviderStateMixin {
  List<Offset>? points;

  late double renderedImageWidth;
  late double renderedImageHeight;
  late double top;
  late double left;

  late AnimationController _controller;
  Animation<EdgeDetectionResult>? _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(EdgeDetectionPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.edgeDetectionResult != null &&
        oldWidget.edgeDetectionResult == null) {
      _animation = EdgeDetectionResultTween(
              begin: widget.edgeDetectionResult!,
              end: widget.edgeDetectionResult!)
          .animate(_controller);
    } else if (widget.edgeDetectionResult == null ||
        oldWidget.edgeDetectionResult == null) {
    } else if (widget.edgeDetectionResult != oldWidget.edgeDetectionResult) {
      _animation = EdgeDetectionResultTween(
              begin: _animation?.value ?? oldWidget.edgeDetectionResult!,
              end: widget.edgeDetectionResult!)
          .animate(_controller);
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return AnimatedSwitcher(
          duration: Duration(milliseconds: 100),
          child: _animation == null || widget.edgeDetectionResult == null
              ? Container(
                  key: ValueKey('No Result'),
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                )
              : AnimatedBuilder(
                  animation: _animation!,
                  builder: (_, child) {
                    _calculateDimensionValues(constraints, _animation?.value);
                    return Container(
                        key: ValueKey('Result'),
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: CustomPaint(
                            painter: EdgePainter(
                                points: points!,
                                strokeColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.75),
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.25))));
                  }));
    });
  }

  void _calculateDimensionValues(
      BoxConstraints constraints, EdgeDetectionResult? edgeDetectionResult) {
    top = 0.0;
    left = 0.0;
    renderedImageHeight = constraints.maxHeight;
    renderedImageWidth = constraints.maxWidth;

    if (edgeDetectionResult == null) {
      return;
    }
    points = [
      Offset(left + edgeDetectionResult.topLeft.dx * renderedImageWidth,
          top + edgeDetectionResult.topLeft.dy * renderedImageHeight),
      Offset(left + edgeDetectionResult.topRight.dx * renderedImageWidth,
          top + edgeDetectionResult.topRight.dy * renderedImageHeight),
      Offset(left + edgeDetectionResult.bottomRight.dx * renderedImageWidth,
          top + (edgeDetectionResult.bottomRight.dy * renderedImageHeight)),
      Offset(left + edgeDetectionResult.bottomLeft.dx * renderedImageWidth,
          top + edgeDetectionResult.bottomLeft.dy * renderedImageHeight),
      Offset(left + edgeDetectionResult.topLeft.dx * renderedImageWidth,
          top + edgeDetectionResult.topLeft.dy * renderedImageHeight),
    ];
  }
}

class EdgePainter extends CustomPainter {
  EdgePainter({
    required this.points,
    required this.fillColor,
    required this.strokeColor,
    this.strokeWidth = 2.0,
  });

  final List<Offset> points;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..lineTo(points[0].dx, points[0].dy);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return true;
  }
}

class EdgeDetectionResultTween extends Tween<EdgeDetectionResult> {
  EdgeDetectionResultTween(
      {EdgeDetectionResult? begin, EdgeDetectionResult? end})
      : super(begin: begin, end: end);

  @override
  EdgeDetectionResult lerp(double t) {
    return EdgeDetectionResult(
      topLeft: Offset.lerp(begin!.topLeft, end!.topLeft, t)!,
      topRight: Offset.lerp(begin!.topRight, end!.topRight, t)!,
      bottomLeft: Offset.lerp(begin!.bottomLeft, end!.bottomLeft, t)!,
      bottomRight: Offset.lerp(begin!.bottomRight, end!.bottomRight, t)!,
    );
  }
}
