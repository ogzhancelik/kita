import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A graphical circular countdown timer that depletes clockwise as time runs out.
///
/// Designed to visually indicate time remaining without displaying numeric text.
class CountdownCircleTimer extends StatefulWidget {
  final DateTime startTime;
  final DateTime? expiresAt;
  final Duration totalDuration;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color? backgroundColor;
  final Widget? child;
  final VoidCallback? onTimeout;

  const CountdownCircleTimer({
    super.key,
    required this.startTime,
    this.expiresAt,
    this.totalDuration = const Duration(seconds: 60),
    this.size = 22.0,
    this.strokeWidth = 2.5,
    required this.color,
    this.backgroundColor,
    this.child,
    this.onTimeout,
  });

  @override
  State<CountdownCircleTimer> createState() => _CountdownCircleTimerState();
}

class _CountdownCircleTimerState extends State<CountdownCircleTimer> {
  Timer? _timer;
  double _progress = 1.0;
  bool _hasTimedOut = false;

  @override
  void initState() {
    super.initState();
    _updateProgress();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant CountdownCircleTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime ||
        oldWidget.expiresAt != widget.expiresAt ||
        oldWidget.totalDuration != widget.totalDuration) {
      _hasTimedOut = false;
      _updateProgress();
      _startTimer();
    }
  }

  void _updateProgress() {
    final now = DateTime.now();
    final end = widget.expiresAt ?? widget.startTime.add(widget.totalDuration);
    final totalMs = widget.expiresAt != null
        ? widget.expiresAt!.difference(widget.startTime).inMilliseconds
        : widget.totalDuration.inMilliseconds;

    if (totalMs <= 0) {
      _progress = 0.0;
      _checkTimeout();
      return;
    }

    final remainingMs = end.difference(now).inMilliseconds;
    if (remainingMs <= 0) {
      _progress = 0.0;
      _checkTimeout();
    } else {
      _progress = (remainingMs / totalMs).clamp(0.0, 1.0);
    }
  }

  void _checkTimeout() {
    if (!_hasTimedOut) {
      _hasTimedOut = true;
      _timer?.cancel();
      widget.onTimeout?.call();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_hasTimedOut) return;

    // 100ms interval provides smooth visual circular depletion with minimal CPU overhead
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _updateProgress();
      });
      if (_hasTimedOut) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _CountdownCirclePainter(
          progress: _progress,
          color: widget.color,
          backgroundColor: widget.backgroundColor ??
              widget.color.withValues(alpha: 0.18),
          strokeWidth: widget.strokeWidth,
        ),
        child: widget.child != null ? Center(child: widget.child) : null,
      ),
    );
  }
}

class _CountdownCirclePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _CountdownCirclePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    if (radius <= 0) return;

    // 1. Background full track circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Foreground countdown arc (starts at 12 o'clock and sweeps clockwise)
    if (progress > 0.0) {
      final fgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2; // 12 o'clock
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CountdownCirclePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
