import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';

class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.expand = false,
    this.height = 52,
    this.borderRadius = 16,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool expand;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final content = Ink(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: expand ? 18 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary, AppColors.activeBackground],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 9),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: expand ? SizedBox(width: double.infinity, child: content) : content,
      ),
    );
  }
}
