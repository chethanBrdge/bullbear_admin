import 'package:flutter/material.dart';
import '../../utils/theme.dart';
class CustomButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed; // nullable to handle disabled state
  final bool loading;

  const CustomButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !loading;

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.7, // 70% width
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? AppTheme.primaryColor : Colors.grey, // conditional color
          foregroundColor: AppTheme.secondaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(title),
      ),
    );
  }
}
