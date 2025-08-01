import 'package:cloud_functions/cloud_functions.dart';
import 'package:echospace/services/auth/auth_service.dart';
import 'package:echospace/components/my_button.dart';
import 'package:echospace/components/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:echospace/themes/theme_provider.dart';

class OTPVerificationPage extends StatefulWidget {
  final String email;
  final String? password;
  final String? nickname;
  final bool isLogin;

  const OTPVerificationPage({
    super.key,
    required this.email,
    this.password,
    this.nickname,
    required this.isLogin,
  });

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  bool _isLoading = false;
  bool _resending = false;

  Future<void> _verifyOTP() async {
    setState(() => _isLoading = true);

    try {
      final HttpsCallable verifyOTP = FirebaseFunctions.instance.httpsCallable('verifyOTP');
      await verifyOTP.call({
        'email': widget.email,
        'otp': _otpController.text.trim(),
      });

      if (widget.isLogin) {
        // Complete login process
        await AuthService().signInWithEmailPassword(
          widget.email,
          widget.password!,
        );
      } else {
        // Complete registration process
        await AuthService().signUpWithEmailPassword(
          widget.email,
          widget.password!,
          widget.nickname!,
        );
      }

      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _resending = true);
    try {
      final HttpsCallable generateOTP = FirebaseFunctions.instance.httpsCallable('generateOTP');
      await generateOTP.call({'email': widget.email});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New OTP sent to your email')),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Failed to resend OTP: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email'),backgroundColor: Provider.of<ThemeProvider>(context).accentColor, ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(25.0),
            child: Text(
              'Enter the OTP sent to ${widget.email}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          MyTextField(
            hintText: '6-digit OTP',
            obscureText: false,
            controller: _otpController,
            focusNode: _otpFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verifyOTP(),
          ),
          const SizedBox(height: 20),
          MyButton(
            text: 'Verify',
            onTap: _verifyOTP,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _resending ? null : _resendOTP,
            child: _resending
                ? const CircularProgressIndicator()
                : const Text('Resend OTP'),
          ),
        ],
      ),
    );
  }
}