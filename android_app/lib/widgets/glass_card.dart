import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? customBorderColor;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 20,
    this.customBorderColor,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = customBorderColor ?? (isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder);

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? (isDark ? AppTheme.darkCard : AppTheme.lightCard) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}

class TactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool isToggled;

  const TactileButton({
    super.key,
    required this.child,
    this.onPressed,
    this.gradient,
    this.backgroundColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.borderRadius = 16,
    this.isToggled = false,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.onPressed != null;

    final baseBg = widget.backgroundColor ??
        (widget.isToggled
            ? AppTheme.primary.withOpacity(0.3)
            : (isDark ? AppTheme.darkCardElevated : const Color(0xFFF1F5F9)));

    final baseBorder = widget.borderColor ??
        (widget.isToggled
            ? AppTheme.primary
            : (isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder));

    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 90),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: widget.padding,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            color: widget.gradient == null ? baseBg.withOpacity(enabled ? 1.0 : 0.4) : null,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: baseBorder.withOpacity(enabled ? 1.0 : 0.3),
              width: widget.isToggled ? 1.8 : 1.0,
            ),
            boxShadow: enabled && !_isPressed && (widget.isToggled || widget.gradient != null)
                ? [
                    BoxShadow(
                      color: (widget.gradient != null ? AppTheme.primary : AppTheme.primary)
                          .withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: enabled
                  ? (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)
                  : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
              fontWeight: FontWeight.w600,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
