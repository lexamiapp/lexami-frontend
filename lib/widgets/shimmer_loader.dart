import 'package:flutter/material.dart';

class ShimmerLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoader({
    super.key,
    this.width = double.infinity,
    this.height = 20.0,
    this.borderRadius = 8.0,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                0.1,
                0.5,
                0.9,
              ],
              colors: [
                widget.baseColor ?? Colors.grey.shade200,
                widget.highlightColor ?? Colors.grey.shade100,
                widget.baseColor ?? Colors.grey.shade200,
              ],
              transform: _SlidingGradientTransform(_animation.value),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slideValue;
  const _SlidingGradientTransform(this.slideValue);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slideValue, 0, 0);
  }
}

class SkeletonResult extends StatelessWidget {
  const SkeletonResult({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShimmerLoader(width: 150, height: 24),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerLoader(height: 20),
              SizedBox(height: 12),
              ShimmerLoader(height: 20),
              SizedBox(height: 12),
              ShimmerLoader(width: 200, height: 20),
              SizedBox(height: 32),
              ShimmerLoader(width: 120, height: 16),
              SizedBox(height: 12),
              ShimmerLoader(height: 20),
              SizedBox(height: 12),
              ShimmerLoader(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class SkeletonAdvisorList extends StatelessWidget {
  const SkeletonAdvisorList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const ShimmerLoader(width: 60, height: 60, borderRadius: 30),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoader(width: 150, height: 18),
                  SizedBox(height: 8),
                  ShimmerLoader(width: 100, height: 14),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      ShimmerLoader(width: 40, height: 14),
                      SizedBox(width: 12),
                      ShimmerLoader(width: 40, height: 14),
                    ],
                  ),
                ],
              ),
            ),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ShimmerLoader(width: 60, height: 20),
                SizedBox(height: 12),
                ShimmerLoader(width: 40, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
