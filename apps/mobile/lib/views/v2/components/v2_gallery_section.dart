import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Blok bagian pada halaman review widget v2.
class V2GallerySection extends StatelessWidget {
  const V2GallerySection({
    super.key,
    required this.title,
    this.description,
    required this.children,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: V2Type.h2),
        if (description != null) ...[
          const SizedBox(height: V2Space.xs),
          Text(
            description!,
            style: V2Type.label.copyWith(color: V2Colors.muted),
          ),
        ],
        const SizedBox(height: V2Space.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(V2Space.lg),
          decoration: BoxDecoration(
            color: V2Colors.white,
            borderRadius: BorderRadius.circular(V2Radius.card),
            border: Border.all(color: V2Colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(height: V2Space.md),
                children[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Satu contoh warna beserta nama token.
class V2ColorSwatch extends StatelessWidget {
  const V2ColorSwatch({
    super.key,
    required this.name,
    required this.color,
    this.caption,
  });

  final String name;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 64,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(V2Radius.sm),
            border: Border.all(color: V2Colors.border),
          ),
        ),
        const SizedBox(height: V2Space.sm),
        Text(name, style: V2Type.label.copyWith(fontWeight: FontWeight.w600)),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(caption!, style: V2Type.caption.copyWith(color: V2Colors.muted)),
        ],
      ],
    );
  }
}

/// Satu baris spesimen tipografi.
class V2TypeRow extends StatelessWidget {
  const V2TypeRow({
    super.key,
    required this.name,
    required this.sample,
    required this.spec,
    required this.style,
  });

  final String name;
  final String sample;
  final String spec;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(
                name,
                style: V2Type.caption.copyWith(color: V2Colors.muted),
              ),
            ),
            Expanded(
              child: Text(
                sample,
                style: style,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 88),
          child: Text(
            spec,
            style: V2Type.caption.copyWith(color: V2Colors.slate400),
          ),
        ),
        const SizedBox(height: V2Space.md),
      ],
    );
  }
}
