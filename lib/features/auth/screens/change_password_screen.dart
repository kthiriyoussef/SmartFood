import 'package:flutter/material.dart';
import 'package:smartfood/features/auth/services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.userId});
  final int userId;
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _visible = false;

  @override
  void dispose() {
    _old.dispose(); _next.dispose(); _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AuthService.instance.changePassword(
        userId: widget.userId,
        currentPassword: _old.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe modifié avec succès.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Modifier le mot de passe')),
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Form(key: _form, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _old,
              obscureText: !_visible,
              decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
              validator: (v) => v == null || v.isEmpty ? 'Champ obligatoire' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _next,
              obscureText: !_visible,
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
              validator: (v) => AuthService.validatePassword(v ?? ''),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: !_visible,
              decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
              validator: (v) => v != _next.text ? 'Confirmation différente' : null,
            ),
            SwitchListTile(
              title: const Text('Afficher les mots de passe'),
              value: _visible,
              onChanged: (value) => setState(() => _visible = value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Enregistrement...' : 'Enregistrer'),
            ),
          ],
        )),
      ),
    )),
  );
}
