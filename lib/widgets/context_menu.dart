import 'package:flutter/material.dart';

class ContextMenu extends StatelessWidget {
  final Rect iconBounds;
  final VoidCallback onRemove;
  final VoidCallback onInfo;
  final double opacity;

  const ContextMenu({
    super.key,
    required this.iconBounds,
    required this.onRemove,
    required this.onInfo,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    const menuWidth = 200.0;
    const menuHeight = 90.0;

    // Default: align left edge, below icon
    double left = iconBounds.left;
    double top = iconBounds.bottom + 8;

    // If not enough space on right → right-align
    if (left + menuWidth > screenWidth) {
      left = iconBounds.right - menuWidth;
    }

    // If not enough space below → open above
    if (top + menuHeight > screenHeight) {
      top = iconBounds.top - menuHeight - 8;
    }

    // Safety clamp
    left = left.clamp(8.0, screenWidth - menuWidth - 8);
    top = top.clamp(8.0, screenHeight - menuHeight - 8);

    return Positioned(
      left: left,
      top: top,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: SizedBox(
          width: menuWidth,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MenuItem(
                    icon: Icons.info_outline,
                    label: 'App info',
                    onTap: onInfo,
                  ),
                  _MenuItem(
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    onTap: onRemove,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[700]),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}