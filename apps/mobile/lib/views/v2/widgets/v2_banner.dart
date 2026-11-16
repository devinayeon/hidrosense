import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

enum V2BannerTone { offline, sync, bmkg, ai, success }

/// Banner informasi dari component set `Banner`.
class V2Banner extends StatelessWidget {
  const V2Banner({
    super.key,
    required this.message,
    this.tone = V2BannerTone.offline,
    this.action,
  });

  final String message;
  final V2BannerTone tone;
  final Widget? action;

  Color get _background => switch (tone) {
    V2BannerTone.offline ||
    V2BannerTone.sync ||
    V2BannerTone.ai => V2Colors.blue50,
    V2BannerTone.bmkg => V2Colors.amber100,
    V2BannerTone.success => V2Colors.green100,
  };

  Color get _foreground => switch (tone) {
    V2BannerTone.offline ||
    V2BannerTone.sync ||
    V2BannerTone.ai => V2Colors.blue700,
    V2BannerTone.bmkg => V2Colors.amber800,
    V2BannerTone.success => V2Colors.green700,
  };

  V2IconName get _icon => switch (tone) {
    V2BannerTone.offline || V2BannerTone.bmkg => V2IconName.cloud,
    V2BannerTone.sync => V2IconName.sync,
    V2BannerTone.ai => V2IconName.care,
    V2BannerTone.success => V2IconName.check,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.all(V2Space.lg),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: Row(
        children: [
          V2Icon(_icon, color: _foreground),
          const SizedBox(width: V2Space.sm),
          Expanded(
            child: Text(
              message,
              style: V2Type.label.copyWith(color: _foreground),
            ),
          ),
          if (action != null) ...[const SizedBox(width: V2Space.sm), action!],
        ],
      ),
    );
  }
}

enum V2ToastTone { success, error, info }

/// Toast mengambang dari component set `Toast` (pill charcoal).
class V2Toast extends StatelessWidget {
  const V2Toast({
    super.key,
    required this.message,
    this.tone = V2ToastTone.success,
  });

  final String message;
  final V2ToastTone tone;

  V2IconName get _icon => switch (tone) {
    V2ToastTone.success => V2IconName.check,
    V2ToastTone.error => V2IconName.close,
    V2ToastTone.info => V2IconName.info,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.all(V2Space.lg),
      decoration: BoxDecoration(
        color: V2Colors.ink,
        borderRadius: BorderRadius.circular(V2Radius.pill),
      ),
      child: Row(
        children: [
          V2Icon(_icon, color: V2Colors.white),
          const SizedBox(width: V2Space.sm),
          Expanded(
            child: Text(
              message,
              style: V2Type.bodyStrong.copyWith(color: V2Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
