import '../app/branding.dart';
export '../app/branding.dart' show appName;
import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The full CONE logo: symbol, wordmark and
/// "Conference Operations & Networking Environment".
class ConeLogo extends StatelessWidget {
  const ConeLogo({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    final branding = BrandingScope.of(context);
    Widget fallback() => branding.applicationName == 'CONE'
        ? Image.asset(
            'assets/images/cone_logo.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _initial(branding.applicationName),
          )
        : _initial(branding.applicationName);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.16),
      child: branding.logoUrl != null
          ? Image.network(
              branding.logoUrl!,
              width: size,
              height: size,
              fit: BoxFit.contain,
              semanticLabel: '${branding.applicationName} logo',
              errorBuilder: (_, _, _) => fallback(),
            )
          : fallback(),
    );
  }

  Widget _initial(String name) => Container(
    width: size,
    height: size,
    color: AppColors.navy,
    alignment: Alignment.center,
    child: Text(
      name.substring(0, 1).toUpperCase(),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: size * .4,
      ),
    ),
  );
}

/// The abbreviation's expansion, shown wherever the app is introduced.
const coneFullName = 'Conference Operations & Networking Environment';

enum NoticeTone { warning, info }

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = NoticeTone.info,
    this.icon,
    this.action,
  });

  final String? title;
  final String message;
  final NoticeTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border, defaultIcon) = switch (tone) {
      NoticeTone.warning => (
        AppColors.warningBg,
        AppColors.warningFg,
        AppColors.warningFg,
        Icons.gpp_maybe_outlined,
      ),
      NoticeTone.info => (
        const Color(0xFFE8F4FB),
        AppColors.navyLight,
        const Color(0xFFB9D7EA),
        Icons.info_outline,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, color: fg, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  message,
                  style: TextStyle(color: fg, fontSize: 13.5, height: 1.4),
                ),
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled white card.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(16),
  });

  final String? title;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Label/value row.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded chip used for category / presentation labels.
class LabelChip extends StatelessWidget {
  const LabelChip({
    super.key,
    required this.label,
    this.icon,
    this.background = const Color(0xFFE6F6F4),
    this.foreground = AppColors.teal,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen error with a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.warningFg,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Conference title, from the workbook's MAIN sheet (cell A1).
const conferenceName =
    '21st Uttarakhand State Science & Technology Congress 2026-27';
