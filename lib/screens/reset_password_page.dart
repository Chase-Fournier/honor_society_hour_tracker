import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'loginpage.dart'; // Or your desired page after successful reset

// Helper class for passing arguments
class ResetPasswordPageArguments {
  final String accessToken;
  ResetPasswordPageArguments({required this.accessToken});
}

class ResetPasswordPage extends StatefulWidget {
  final String? accessToken;
  final VoidCallback? onPasswordResetFlowComplete; // Callback

  const ResetPasswordPage({
    super.key,
    this.accessToken,
    this.onPasswordResetFlowComplete,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  @override
  void dispose() {
    widget.onPasswordResetFlowComplete?.call(); // Call callback on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.accessToken;

    if (token == null || token.isEmpty) {

      
      // This can happen if the page is accessed directly or token is missing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onPasswordResetFlowComplete?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid or missing password reset token.')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SupaResetPassword(
            accessToken: token,
            onSuccess: (UserResponse response) {
              widget.onPasswordResetFlowComplete?.call();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset successfully! Please sign in.')),
                );
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Password reset failed: ${error.toString()}')),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}