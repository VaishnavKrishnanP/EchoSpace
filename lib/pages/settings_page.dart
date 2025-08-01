import 'package:echospace/themes/theme_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});

  final List<Map<String, dynamic>> colors = [
    {"name": "Blue", "color": Colors.blue},
    {"name": "Red", "color": Colors.red},
    {"name": "Green", "color": Colors.green},
    {"name": "Purple", "color": Colors.purple},
    {"name": "Orange", "color": Colors.orange},
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Ensure selected accent color exists in the dropdown list
    Color selectedColor = themeProvider.accentColor;
    if (!colors.any((color) => color["color"] == selectedColor)) {
      selectedColor = colors.first["color"]; // Default to first color if invalid
      themeProvider.accentColor = selectedColor;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: themeProvider.accentColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Dark Mode Toggle
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(25),
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Dark Mode"),
                CupertinoSwitch(
                  value: themeProvider.isDarkMode,
                  onChanged: (value) => themeProvider.toggleTheme(),
                ),
              ],
            ),
          ),

          // Accent Color Dropdown
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(25),
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Accent Color"),
                DropdownButton<Color>(
                  value: selectedColor,
                  onChanged: (newColor) {
                    if (newColor != null) {
                      themeProvider.accentColor = newColor;
                    }
                  },
                  items: colors.map((colorData) {
                    return DropdownMenuItem<Color>(
                      value: colorData["color"],
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: colorData["color"],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(colorData["name"]),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
