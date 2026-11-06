import 'package:flutter/material.dart';
import 'package:smartfood/features/auth/services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onAuthenticated});
  final void Function(Map<String, Object?> user) onAuthenticated;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool hidden = true;
  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      final user = await AuthService.instance.login(email.text, password.text);
      if (mounted) widget.onAuthenticated(user);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5FAF6),
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.eco, size: 72, color: Color(0xFF21834B)),
        const SizedBox(height: 14),
        const Text('SmartFood', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF21834B))),
        const SizedBox(height: 8),
        const Text('Bienvenue ! Connectez-vous à votre compte.', textAlign: TextAlign.center),
        const SizedBox(height: 38),
        TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Adresse email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()), validator: (v) => v == null || !v.contains('@') ? 'Saisissez un email valide' : null),
        const SizedBox(height: 16),
        TextFormField(controller: password, obscureText: hidden, decoration: InputDecoration(labelText: 'Mot de passe', prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(hidden ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hidden = !hidden))), validator: (v) => v == null || v.isEmpty ? 'Mot de passe obligatoire' : null),
        const SizedBox(height: 24),
        FilledButton(onPressed: loading ? null : submit, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF21834B), padding: const EdgeInsets.all(16)), child: Text(loading ? 'Connexion...' : 'Se connecter')),
        TextButton(onPressed: loading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(onAuthenticated: widget.onAuthenticated))), child: const Text('Pas encore de compte ? S’inscrire')),
      ])),
    )))),
  );
}
