import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../utils/api.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../customized_widgets/custom_button.dart';
import '../../customized_widgets/custom_password_field.dart';
import '../../customized_widgets/custom_textfield.dart';
import '../../customized_widgets/loading_dailog.dart';
 
import '../../customized_widgets/form_headings.dart';
import '../../utils/theme.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  String? usernameError;
  String? passwordError;

 Future<void> _login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;

    setState(() {
      usernameError = username.isEmpty ? 'Username is required' : null;
      passwordError = password.isEmpty ? 'Password is required' : null;
    });

    if (usernameError != null || passwordError != null) return;

    CustomLoadingDialog.show(context, message: "Logging in...");

    try {
      final res = await API().sendRequest.post(
        "/admin_panel/login/",
        data: {
          "username": username,
          "password": password,
        },
      );

      final response = res.data; // Already a Map<String, dynamic>

      print("Chethan Status code: ${res.statusCode}");
      print("Chethan Response: $response");

      if (response.containsKey('error')) {
        CustomLoadingDialog.hide(context);
        _showError(response['error']);
      } else {
        CustomLoadingDialog.hide(context);
        print("Login Success: $response");
        // ✅ Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', response['access']);
        await prefs.setString('refresh_token', response['refresh']);
        await prefs.setInt('admin_id', response['profile']['id']);
        await prefs.setString('email', response['profile']['email']);

         print("Login Success & Tokens Saved ✅");

        // Navigate to dashboard
        context.go('/dashboard/overview');

        // Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      CustomLoadingDialog.hide(context);
      _showError("Something went wrong");
    }
}




  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
Widget build(BuildContext context) {
  final primary = Theme.of(context).primaryColor;
  final screenWidth = MediaQuery.of(context).size.width;

  return Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: screenWidth * 0.5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FormHeadings(
                title: "Login",
                subtitle: "Enter your credentials",
              ),
              CustomTextField(
                controller: usernameController,
                hintText: "Username",
                prefixIcon: Icon(Icons.person, color: primary),
                errorText: usernameError,
              ),
              const SizedBox(height: 16),
              CustomPasswordField(
                controller: passwordController,
                labelText: "Password",
                color: primary,
                errorText: passwordError,
              ),
              const SizedBox(height: 24),
              CustomButton(
                title: "Login",
                onPressed: _login,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

}
