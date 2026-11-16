import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Jenis bentuk placeholder.
enum V2SkeletonShape { line, block, circle }

/// Placeholder pemuatan dari component set `Skeleton`.
class V2Skeleton extends StatefulWidget {
  const V2Skeleton.line({super.key, this.width, this.height = 16})
    : shape = V2SkeletonShape.line,
      radius = 8;

  const V2Skeleton.block({
    super.key,
    this.width,
    required this.height,
    this.radius = V2Radius.card,
  }) : shape = V2SkeletonShape.block;

  const V2Skeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      shape = V2SkeletonShape.circle,
      radius = 0;

  final double? width;
  final double height;
  final double radius;
  final V2SkeletonShape shape;

  @override
  State<V2Skeleton> createState() => _V2SkeletonState();
}

class _V2SkeletonState extends State<V2Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: V2Colors.gray200,
          shape: widget.shape == V2SkeletonShape.circle
              ? BoxShape.circle
              : BoxShape.rectangle,
          borderRadius: widget.shape == V2SkeletonShape.line
              ? BorderRadius.circular(8)
              : widget.shape == V2SkeletonShape.block
              ? BorderRadius.circular(widget.radius)
              : null,
        ),
      ),
    );
  }
}
