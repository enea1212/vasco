import 'package:flutter/material.dart';
import 'package:vasco/presentation/providers/infrastructure/auth_provider.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }


String? _validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter an email';
  }
  // Expresie regulată pentru un format de email valid
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  if (!emailRegex.hasMatch(value)) {
    return 'Invalid email format (e.g. name@email.com)';
  }
  return null;
}

// Aceasta este "puntea" dintre buton și Provider
Future<void> _register() async {
  // 1. Verificăm dacă datele introduse sunt valide (Regex email, lungime parolă)
  if (!_formKey.currentState!.validate()) return;

  // 2. Apelăm metoda 'register' care există deja în AuthViewModel
  try {
    await context.read<AuthViewModel>().register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
    );

    if (!mounted) return;

    // 3. Dacă a reușit, afișăm un mesaj și închidem pagina
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created successfully')),
    );
    Navigator.of(context).pop();

  } catch (e) {
    if (!mounted) return;
    
    // 4. Dacă a apărut o eroare, o afișăm într-un pop-up
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registration Error'),
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



@override
Widget build(BuildContext context) {
  // 1. Ascultăm starea din AuthViewModel (Provider) pentru a detecta loading-ul [cite: 7, 14]
  final authVM = context.watch<AuthViewModel>();

  return Scaffold(
    appBar: AppBar(title: const Text('Register')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey, // Folosit pentru validarea locală Regex [cite: 17]
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Câmp Nume
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: UnderlineInputBorder(), // Uniformizare design
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter your username' : null,
            ),
            const SizedBox(height: 16),

            // Câmp Email cu validare Regex locală [cite: 17]
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: UnderlineInputBorder(),
              ),
              validator: _validateEmail,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Câmp Parolă cu vizibilitate (ochi) 
            TextFormField( // Schimbat din TextField în TextFormField pentru consistență
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: const UnderlineInputBorder(),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              validator: (value) => (value?.length ?? 0) < 6 
                  ? 'Password must be at least 6 characters' 
                  : null,
            ),
            const SizedBox(height: 16),

            // Câmp Confirmare Parolă
            TextFormField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: UnderlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) => value != _passwordController.text
                  ? 'Passwords do not match'
                  : null,
            ),
            const SizedBox(height: 24),

            // 2. Butonul reparat care folosește authVM.isLoading 
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Dezactivăm butonul dacă procesul de înregistrare este în curs 
                onPressed: authVM.isLoading ? null : _register,
                child: authVM.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.deepPurple,
                        ),
                      )
                    : const Text('Register'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}}