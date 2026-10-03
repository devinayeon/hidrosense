import 'package:flutter/material.dart';

class ItemImagePlaceholder extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final String placeholderText;

  const ItemImagePlaceholder({
    super.key,
    this.imageUrl,
    this.height = 140.0,
    this.placeholderText = 'FOTO BARANG / KEMASAN',
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromRGBO(57, 198, 195, 1);
    const bgColor = Color.fromRGBO(240, 251, 251, 1);

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                width: double.infinity,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholderContent(primaryColor),
              )
            : CustomPaint(
                painter: DashedBorderPainter(
                  color: primaryColor,
                  strokeWidth: 1.5,
                  dashWidth: 6,
                  dashSpace: 4,
                  borderRadius: 16,
                ),
                child: _buildPlaceholderContent(primaryColor),
              ),
      ),
    );
  }

  Widget _buildPlaceholderContent(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.image_outlined, color: primaryColor, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            placeholderText,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter untuk Menggambar Border Putus-putus (Dashed Border)
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 6,
    this.dashSpace = 4,
    this.borderRadius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path metricsPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double length = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        metricsPath.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(metricsPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) => false;
}
