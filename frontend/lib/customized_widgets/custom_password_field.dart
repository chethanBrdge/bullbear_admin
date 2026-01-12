import 'package:flutter/material.dart';

class CustomPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? errorText;
  final void Function(String)? onChanged;
  final Color color;

  const CustomPasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.color,
    this.errorText,
    this.onChanged,
  });

  @override
  State<CustomPasswordField> createState() => _CustomPasswordFieldState();
}

class _CustomPasswordFieldState extends State<CustomPasswordField> {
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: obscure,
      onChanged: widget.onChanged,
      cursorColor: widget.color,
      style: TextStyle(color: widget.color),
      decoration: InputDecoration(
        labelText: widget.labelText,
        labelStyle: TextStyle(color: widget.color),
        errorText: widget.errorText,
        prefixIcon: Icon(Icons.lock, color: widget.color),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: widget.color,
          ),
          onPressed: () => setState(() => obscure = !obscure),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: widget.color),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: widget.color, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}
