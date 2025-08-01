import 'package:echospace/services/auth/auth_service.dart';
import 'package:echospace/components/my_button.dart';
import 'package:echospace/components/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:echospace/themes/theme_provider.dart';
import '../components/icon.dart';
import 'otp_page.dart';

class LoginPage extends StatefulWidget {
  final void Function()? onTap;

  const LoginPage({super.key, required this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  // Create FocusNode instances for each field
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _pwFocusNode = FocusNode();

  void login(BuildContext context) async {
  final authService = AuthService();
  final email = _emailController.text.trim();
  final password = _pwController.text;

  try {
    // First send OTP
    await authService.sendOTP(email);

    // Navigate to OTP verification page
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPVerificationPage(
            email: email,
            password: password,
            isLogin: true,
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
    _emailFocusNode.dispose();
    _pwFocusNode.dispose();
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
              "Welcome back, you've been missed.",
              style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary),
            ),

            const SizedBox(height: 25),

            MyTextField(
              hintText: "Email",
              obscureText: false,
              controller: _emailController,
              focusNode: _emailFocusNode, // Pass FocusNode
              textInputAction: TextInputAction.next,
              onSubmitted: (_) {
                _pwFocusNode.requestFocus();
              },
            ),

            const SizedBox(height: 10),

            MyTextField(
              hintText: "Password",
              obscureText: true,
              controller: _pwController,
              focusNode: _pwFocusNode, // Pass FocusNode
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                login(context);
              },
            ),

            const SizedBox(height: 25),

            MyButton(
              text: "Login",
              onTap: () => login(context),
            ),

            const SizedBox(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Not a Member?",
                  style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary),
                ),
                GestureDetector(
                  onTap: widget.onTap,
                  child: Text(
                    " Register Now",
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