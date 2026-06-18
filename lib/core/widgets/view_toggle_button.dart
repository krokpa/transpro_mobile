import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Segmented toggle button switching between list and grid view.
/// Drop it into any AppBar's `actions` list.
class ViewToggleButton extends StatelessWidget {
  final bool isGrid;
  final ValueChanged<bool> onToggle;

  const ViewToggleButton({
    super.key,
    required this.isGrid,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.divider),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Btn(
          icon: Icons.view_list_rounded,
          active: !isGrid,
          onTap: () => onToggle(false),
          tooltip: 'Vue liste',
        ),
        const SizedBox(width: 2),
        _Btn(
          icon: Icons.grid_view_rounded,
          active: isGrid,
          onTap: () => onToggle(true),
          tooltip: 'Vue grille',
        ),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;

  const _Btn({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          width: 30,
          height: 28,
          decoration: BoxDecoration(
            color: active ? brandOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            icon,
            size: 16,
            color: active ? Colors.white : context.textMuted,
          ),
        ),
      ),
    );
  }
}
