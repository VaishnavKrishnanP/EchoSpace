import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  final String text;
  final void Function()? onTap;
  final bool isLoading;  // New: Add loading state
  final bool isDisabled; // New: Add disabled state

  const MyButton({
    super.key,
    required this.text,
    required this.onTap,
    this.isLoading = false,  // Default to false for backward compatibility
    this.isDisabled = false, // Default to false for backward compatibility
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (isDisabled || isLoading) ? null : onTap, // Disable if loading or disabled
      child: Container(
        decoration: BoxDecoration(
          color:  Theme.of(context).colorScheme.secondary,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(25),
        margin: const EdgeInsets.symmetric(horizontal: 25.0),
        child: Center(
          child: isLoading
              ?  SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.inversePrimary),
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),
        ),
      ),
    );
  }
}