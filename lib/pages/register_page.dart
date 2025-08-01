import 'package:echospace/services/auth/auth_service.dart';
import 'package:echospace/components/my_button.dart';
import 'package:echospace/components/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/icon.dart';
import '../themes/theme_provider.dart';
import 'otp_page.dart';

class RegisterPage extends StatefulWidget {
  final void Function()? onTap;

  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nckController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _confirmPwController = TextEditingController();

  // Create FocusNode instances for each field
  final FocusNode _nckFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _pwFocusNode = FocusNode();
  final FocusNode _confirmPwFocusNode = FocusNode();

  Future<void> register(BuildContext context) async {
  final auth = AuthService();
  final email = _emailController.text.trim();
  final password = _pwController.text;
  final nickname = _nckController.text;

  if (_pwController.text != _confirmPwController.text) {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text("Passwords do not match!"),
      ),
    );
    return;
  }

  try {
    // First send OTP
    await auth.sendOTP(email);

    // Navigate to OTP verification page
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPVerificationPage(
            email: email,
            password: password,
            nickname: nickname,
            isLogin: false,
          ),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(e.toString()),
        ),
      );
    }
  }
}

  @override
  void dispose() {
    // Dispose of FocusNode instances to avoid memory leaks
    _nckFocusNode.dispose();
    _emailFocusNode.dispose();
    _pwFocusNode.dispose();
    _confirmPwFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: SvgIcon(
                size: 150,
                color: Provider.of<ThemeProvider>(context).accentColor,
              ),
            ),

            const SizedBox(height: 50),

            Text(
              "Let's create an account for you!",
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),

            const SizedBox(height: 25),

            MyTextField(
              hintText: "Nickname",
              obscureText: false,
              controller: _nckController,
              focusNode: _nckFocusNode, // Pass FocusNode
              textInputAction: TextInputAction.next,
              onSubmitted: (_) {
                // Move focus to the email field
                _emailFocusNode.requestFocus();
              },
            ),

            const SizedBox(height: 10),

            MyTextField(
              hintText: "Email",
              obscureText: false,
              controller: _emailController,
              focusNode: _emailFocusNode, // Pass FocusNode
              textInputAction: TextInputAction.next,
              onSubmitted: (_) {
                // Move focus to the password field
                _pwFocusNode.requestFocus();
              },
            ),

            const SizedBox(height: 25),

            MyTextField(
              hintText: "Password",
              obscureText: true,
              controller: _pwController,
              focusNode: _pwFocusNode, // Pass FocusNode
              textInputAction: TextInputAction.next,
              onSubmitted: (_) {
                // Move focus to the confirm password field
                _confirmPwFocusNode.requestFocus();
              },
            ),

            const SizedBox(height: 10),

            MyTextField(
              hintText: "Confirm Password",
              obscureText: true,
              controller: _confirmPwController,
              focusNode: _confirmPwFocusNode, // Pass FocusNode
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                // Submit the form
                register(context);
              },
            ),

            const SizedBox(height: 25),

            MyButton(
              text: "Register",
              onTap: () => register(context),
            ),

            const SizedBox(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Already have an account?",
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
                GestureDetector(
                  onTap: widget.onTap,
                  child: Text(
                    " Login Now",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Provider.of<ThemeProvider>(context).accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}