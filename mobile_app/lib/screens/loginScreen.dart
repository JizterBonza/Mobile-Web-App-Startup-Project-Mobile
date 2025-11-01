import 'package:flutter/material.dart';
import 'signUpScreen.dart';
import 'forgotPasswordScreen.dart';
import '../widgets/form_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            FormHeader(
              icon: Icons.shopping_cart,
              title: 'AgrifyConnect',
              subtitle: 'Your Agricultural Marketplace',
            ),
            FormCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FormSectionHeader(
                      title: 'Welcome',
                      description: 'Login to your account',
                    ),
                    CustomTextFormField(
                      controller: _emailController,
                      labelText: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    PasswordField(
                      controller: _passwordController,
                      labelText: 'Password',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 10),
                    ForgotPasswordLink(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ForgotPasswordScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 15),
                    CustomElevatedButton(
                      text: 'Login',
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          // Navigate to dashboard using named route
                          Navigator.pushReplacementNamed(
                              context, '/customerDashboard');
                        }
                      },
                    ),
                    SizedBox(height: 15),
                    NavigationLink(
                      leadingText: "Don't have an account? ",
                      linkText: 'Sign Up',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SignUpScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
