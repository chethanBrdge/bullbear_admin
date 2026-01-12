import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Colors.black;
  static const Color secondaryColor = Colors.white;
  static const Color formColor = Color(0xFFFDF5E6); // light cream

  static ThemeData get themeData {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: secondaryColor,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: formColor,
        labelStyle: TextStyle(color: primaryColor),
        hintStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primaryColor,
      ),
    );
  }
}
