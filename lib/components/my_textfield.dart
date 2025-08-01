import 'package:flutter/material.dart';

class MyTextField extends StatelessWidget {
  final dynamic edgePadding;
  final String hintText;
  final bool obscureText;
  final TextEditingController controller;
  final FocusNode? focusNode; // Add FocusNode parameter
  final TextInputAction textInputAction;
  final Function(String)? onSubmitted;
  final bool isMultiline;

  const MyTextField({
    super.key,
    this.edgePadding = 25.0,
    required this.hintText,
    required this.obscureText,
    required this.controller,
    this.focusNode,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.isMultiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: edgePadding),
      child: TextField(
        obscureText: obscureText,
        controller: controller,
        focusNode: focusNode,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        onChanged: isMultiline ? (value) {} : null,
        minLines: isMultiline && !obscureText ? 1 : null,
        maxLines: isMultiline && !obscureText ? 6 : 1,
        keyboardType: isMultiline && !obscureText ? TextInputType.multiline : null,
        decoration: InputDecoration(
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).colorScheme.tertiary),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
          ),
          fillColor: Theme.of(context).colorScheme.secondary,
          filled: true,
          hintText: hintText,
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
          contentPadding: const EdgeInsets.all(10),
        ),
      ),
    );
  }
}