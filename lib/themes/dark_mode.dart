import 'package:flutter/material.dart';

ThemeData darkMode = ThemeData(
  colorScheme: ColorScheme.dark(
    surface: Colors.black,// Darker background
    primary: Colors.white,
    secondary: Colors.grey.shade800,
    tertiary: Colors.grey.shade700,
    inversePrimary: Colors.grey.shade300,
  ),
  scaffoldBackgroundColor: Colors.black,
);
