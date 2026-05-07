import 'package:flutter/material.dart';
import 'package:vasco/providers/auth_provider.dart';
import 'package:vasco/features/auth/screens/register_screen.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

final TextEditingController _emailController = TextEditingController();
final TextEditingController _passwordController = TextEditingController();
bool _isPasswordVisible = false; 
  

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Notă: Metoda _handleEmailAuth ar trebui acum să facă doar Sign In.
  // Logica de Sign Up se mută în register_screen.dart.

 @override
Widget build(BuildContext context) {
  // Ascultăm starea din AuthViewModel
  final authVM = context.watch<AuthViewModel>();

  return Scaffold(
    appBar: AppBar(
      title: const Text('Login'),
      centerTitle: true,
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'VascoApp',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 40),
            // Email Field
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            // Password Field
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Sign In Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Dezactivăm butonul dacă se încarcă deja ceva
                onPressed: authVM.isLoading ? null : () async {
                  try {
                    await authVM.signInWithEmail(
                      _emailController.text.trim(),
                      _passwordController.text,
                    );
                  } catch (e) {
                    // Afișăm eroarea într-un mod prietenos
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Error'),
                          content: Text(e.toString()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
                child: authVM.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign In'),
              ),
            ),
            const SizedBox(height: 16),
            // Register Link
            TextButton(
              onPressed: authVM.isLoading ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              },
              child: const Text('Don\'t have an account? Sign Up'),
            ),
            const SizedBox(height: 24),
            const Text('Or continue with'),
            const SizedBox(height: 16),
            // Google Sign In Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: authVM.isLoading ? null : () async {
                  try {
                    await authVM.signInWithGoogle();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                },
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Sign in with Google'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}}