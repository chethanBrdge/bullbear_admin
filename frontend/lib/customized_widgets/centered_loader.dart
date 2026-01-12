import 'package:flutter/material.dart';
import '../../utils/theme.dart';

class CenteredLoader extends StatelessWidget {
  const CenteredLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppTheme.primaryColor,
        strokeWidth: 3,
      ),
    );
  }
}
