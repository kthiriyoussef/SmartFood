import 'package:flutter/material.dart';
import 'package:smartfood/features/auth/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.onAuthenticated});
  final void Function(Map<String, Object?> user) onAuthenticated;
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final nom = TextEditingController();
  final prenom = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool loading = false;
  @override
  void dispose() { for (final c in [nom, prenom, email, password, confirm]) { c.dispose(); } super.dispose(); }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      final user = await AuthService.instance.register(nom: nom.text, prenom: prenom.text, email: email.text, password: password.text);
      if (mounted) widget.onAuthenticated(user);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => loading = false); }
  }

  Widget field(TextEditingController c, String label, {bool secret = false, String? Function(String?)? validate}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(controller: c, obscureText: secret, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), validator: validate ?? (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Créer un compte')),
    backgroundColor: const Color(0xFFF5FAF6),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.person_add_alt_1, size: 64, color: Color(0xFF21834B)),
        const SizedBox(height: 12),
        const Text('Rejoignez SmartFood', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        field(prenom, 'Prénom'), field(nom, 'Nom'),
        field(email, 'Adresse email', validate: (v) => v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? 'Email invalide' : null),
        field(password, 'Mot de passe (10 caractères minimum)', secret: true, validate: (v) => v == null || v.length < 10 ? 'Au moins 10 caractères' : null),
        field(confirm, 'Confirmer le mot de passe', secret: true, validate: (v) => v != password.text ? 'Les mots de passe ne correspondent pas' : null),
        const Text('L’inscription crée un compte CLIENT.', textAlign: TextAlign.center),
        const SizedBox(height: 18),
        FilledButton(onPressed: loading ? null : submit, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF21834B), padding: const EdgeInsets.all(16)), child: Text(loading ? 'Création...' : 'Créer mon compte')),
      ])),
    ))),
  );
}
