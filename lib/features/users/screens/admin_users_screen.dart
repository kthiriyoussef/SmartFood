import 'package:flutter/material.dart';

import 'package:smartfood/features/users/screens/admin_user_form_screen.dart';
import 'package:smartfood/features/users/services/user_management_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({
    super.key,
    required this.actorId,
  });

  final int actorId;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final UserManagementService _service = UserManagementService();
  final TextEditingController _search = TextEditingController();

  List<Map<String, Object?>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final users = await _service.listUsers(
        actorId: widget.actorId,
        search: _search.text,
      );

      if (!mounted) return;

      setState(() => _users = users);
    } catch (e) {
      _showMessage('Erreur de chargement : $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _open([Map<String, Object?>? user]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminUserFormScreen(
          actorId: widget.actorId,
          user: user,
        ),
      ),
    );

    if (!mounted) return;

    if (changed == true) {
      await _load();
    }
  }

  Future<void> _toggle(Map<String, Object?> user) async {
    try {
      await _service.setActive(
        actorId: widget.actorId,
        userId: user['id'] as int,
        active: user['actif'] != 1,
      );

      if (!mounted) return;

      _showMessage('État du compte modifié.');
      await _load();
    } catch (e) {
      _showMessage('Erreur : $e', error: true);
    }
  }

  Future<void> _changeRole(Map<String, Object?> user) async {
    final userId = user['id'] as int;
    final currentRole = user['role'] as String? ?? 'CLIENT';

    if (userId == widget.actorId) {
      _showMessage(
        'Vous ne pouvez pas modifier votre propre rôle ADMIN.',
        error: true,
      );
      return;
    }

    // Ce dialogue gère uniquement ADMIN et CLIENT.
    // Les comptes RESTO restent modifiables via
    // le formulaire existant.
    if (currentRole == 'RESTO') {
      _showMessage(
        'Pour modifier un compte RESTO, utilisez Modifier.',
        error: true,
      );
      return;
    }

    String selectedRole = currentRole;

    final newRole = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Modifier le rôle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${user['prenom']} ${user['nom']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${user['email']}'),
                  const SizedBox(height: 20),
                  const Text('Sélectionnez le nouveau rôle :'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Rôle',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.admin_panel_settings),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'CLIENT',
                        child: Text('CLIENT'),
                      ),
                      DropdownMenuItem(
                        value: 'ADMIN',
                        child: Text('ADMIN'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedRole = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: selectedRole == currentRole
                      ? null
                      : () => Navigator.pop(
                            dialogContext,
                            selectedRole,
                          ),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newRole == null || newRole == currentRole) return;

    try {
      await _service.updateUser(
        actorId: widget.actorId,
        userId: userId,
        nom: user['nom'] as String,
        prenom: user['prenom'] as String,
        email: user['email'] as String,
        role: newRole,
        restaurantId: null,
      );

      if (!mounted) return;

      _showMessage('Rôle modifié avec succès : $newRole');
      await _load();
    } catch (e) {
      _showMessage(
        'Impossible de modifier le rôle : $e',
        error: true,
      );
    }
  }

  Widget _userTile(Map<String, Object?> user) {
    final active = user['actif'] == 1;
    final role = user['role']?.toString() ?? 'CLIENT';
    final userId = user['id'] as int;
    final isCurrentAdmin = userId == widget.actorId;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              active ? Colors.green.shade100 : Colors.grey.shade200,
          child: Icon(
            role == 'ADMIN' ? Icons.admin_panel_settings : Icons.person,
            color: active ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(
          '${user['prenom']} ${user['nom']}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${user['email']}'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(role),
                  backgroundColor: role == 'ADMIN'
                      ? Colors.blue.shade100
                      : Colors.green.shade100,
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  active ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    color: active ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'edit':
                _open(user);
                break;
              case 'role':
                _changeRole(user);
                break;
              case 'toggle':
                _toggle(user);
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Modifier'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (!isCurrentAdmin && role != 'RESTO')
              const PopupMenuItem(
                value: 'role',
                child: ListTile(
                  leading: Icon(Icons.admin_panel_settings),
                  title: Text('Modifier le rôle'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if (!isCurrentAdmin)
              PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                  leading: Icon(
                    active ? Icons.block : Icons.check_circle,
                  ),
                  title: Text(
                    active ? 'Désactiver' : 'Activer',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              onChanged: (_) => _load(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Rechercher un utilisateur',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _users.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 100),
                              Center(
                                child: Text(
                                  'Aucun utilisateur trouvé.',
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              return _userTile(_users[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
