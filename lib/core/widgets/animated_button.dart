import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';

class AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? textColor;
  final double borderRadius;
  final bool isOutlined;

  const AnimatedButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.width,
    this.height,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = AppTheme.radiusLarge,
    this.isOutlined = false,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        width: widget.width,
        height: widget.height ?? 56,
        decoration: BoxDecoration(
          gradient: widget.isOutlined
              ? null
              : (widget.backgroundColor != null
                  ? LinearGradient(
                      colors: [widget.backgroundColor!, widget.backgroundColor!],
                    )
                  : AppTheme.orangeGradient),
          color: widget.isOutlined ? Colors.white : null,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.isOutlined
              ? Border.all(
                  color: widget.backgroundColor ?? AppTheme.primaryOrange,
                  width: 2,
                )
              : null,
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: (widget.backgroundColor ?? AppTheme.primaryOrange)
                        .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            onTap: widget.onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLarge,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      color: widget.isOutlined
                          ? (widget.backgroundColor ?? AppTheme.primaryOrange)
                          : (widget.textColor ?? Colors.white),
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingSmall),
                  ],
                  Text(
                    widget.text,
                    style: TextStyle(
                      color: widget.isOutlined
                          ? (widget.backgroundColor ?? AppTheme.primaryOrange)
                          : (widget.textColor ?? Colors.white),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      )
          .animate(target: _isPressed ? 1 : 0)
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(0.95, 0.95),
            duration: 150.ms,
          ),
    );
  }
}
