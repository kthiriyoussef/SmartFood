import 'package:flutter/material.dart';
import 'package:smartfood/features/users/services/user_management_service.dart';

class AdminUserFormScreen extends StatefulWidget {
  const AdminUserFormScreen({
    super.key, required this.actorId, this.user,
  });
  final int actorId;
  final Map<String, Object?>? user;

  @override
  State<AdminUserFormScreen> createState() => _AdminUserFormScreenState();
}

class _AdminUserFormScreenState extends State<AdminUserFormScreen> {
  final _form = GlobalKey<FormState>();
  final _service = UserManagementService();
  late final TextEditingController _nom;
  late final TextEditingController _prenom;
  late final TextEditingController _email;
  final _password = TextEditingController();
  String _role = 'CLIENT';
  int? _restaurantId;
  List<Map<String, Object?>> _restaurants = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nom = TextEditingController(text: u?['nom'] as String? ?? '');
    _prenom = TextEditingController(text: u?['prenom'] as String? ?? '');
    _email = TextEditingController(text: u?['email'] as String? ?? '');
    _role = u?['role'] as String? ?? 'CLIENT';
    _restaurantId = u?['restaurant_id'] as int?;
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      final result = await _service.restaurants(actorId: widget.actorId);
      if (mounted) setState(() => _restaurants = result);
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  @override
  void dispose() {
    _nom.dispose(); _prenom.dispose(); _email.dispose(); _password.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error')));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final user = widget.user;
      if (user == null) {
        await _service.createUser(
          actorId: widget.actorId, nom: _nom.text, prenom: _prenom.text,
          email: _email.text, password: _password.text,
          role: _role, restaurantId: _restaurantId);
      } else {
        await _service.updateUser(
          actorId: widget.actorId, userId: user['id'] as int,
          nom: _nom.text, prenom: _prenom.text, email: _email.text,
          role: _role, restaurantId: _restaurantId);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.user != null;
    final selectedRestaurant = _restaurants.any(
      (r) => r['id'] == _restaurantId) ? _restaurantId : null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Modifier utilisateur' : 'Ajouter utilisateur')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(controller: _nom,
            decoration: const InputDecoration(labelText: 'Nom'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null),
          TextFormField(controller: _prenom,
            decoration: const InputDecoration(labelText: 'Prénom'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null),
          TextFormField(controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null),
          if (!editing) TextFormField(controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mot de passe (10 caractères min.)'),
            validator: (v) => v == null || v.length < 10 ? '10 caractères minimum' : null),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Rôle'),
            items: const [
              DropdownMenuItem(value: 'CLIENT', child: Text('CLIENT')),
              DropdownMenuItem(value: 'RESTO', child: Text('RESTO')),
              DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
            ],
            onChanged: (value) => setState(() {
              _role = value ?? 'CLIENT';
              if (_role != 'RESTO') _restaurantId = null;
            }),
          ),
          if (_role == 'RESTO') DropdownButtonFormField<int>(
            initialValue: selectedRestaurant,
            decoration: const InputDecoration(labelText: 'Restaurant associé'),
            items: [
              for (final r in _restaurants)
                DropdownMenuItem(value: r['id'] as int,
                  child: Text(r['nom'] as String)),
            ],
            onChanged: (value) => setState(() => _restaurantId = value),
            validator: (v) => v == null ? 'Sélectionnez un restaurant' : null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Enregistrement...' :
                editing ? 'Enregistrer les modifications' : 'Créer le compte'),
          ),
        ]),
      ),
    );
  }
}
