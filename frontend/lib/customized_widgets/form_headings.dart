import 'package:flutter/material.dart';

class FormHeadings extends StatelessWidget {
  final String title;
  final String? subtitle;

  const FormHeadings({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          height: 2,
          color: primaryColor,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
