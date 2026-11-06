
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:smartfood/app/theme.dart';
import 'package:smartfood/core/database/database_helper.dart';
import 'package:smartfood/features/auth/services/session_service.dart';

class ProfileClientScreen extends StatefulWidget {
  const ProfileClientScreen({super.key});

  @override
  State<ProfileClientScreen> createState() =>
      _ProfileClientScreenState();
}

class _ProfileClientScreenState extends State<ProfileClientScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  int? _userId;

  bool _loading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  String _savedFirstName = '';
  String _savedLastName = '';
  String _savedEmail = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final sessionUser =
      await SessionService.instance.restoreUser();

      if (sessionUser == null) {
        throw StateError('Aucun utilisateur connecté.');
      }

      final id = sessionUser['id'] as int;

      final db = await DatabaseHelper.instance.database;

      final users = await db.query(
        'users',
        columns: ['id', 'nom', 'prenom', 'email'],
        where: 'id = ? AND role = ? AND actif = ?',
        whereArgs: [id, 'CLIENT', 1],
        limit: 1,
      );

      if (users.isEmpty) {
        throw StateError('Profil client introuvable.');
      }

      final user = users.first;

      if (!mounted) return;

      setState(() {
        _userId = id;

        _savedFirstName = user['prenom'].toString();
        _savedLastName = user['nom'].toString();
        _savedEmail = user['email'].toString();

        _firstNameController.text = _savedFirstName;
        _lastNameController.text = _savedLastName;
        _emailController.text = _savedEmail;

        _loading = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement profil : $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Impossible de charger le profil : $e',
          isError: true);
    }
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _cancelEditing() {
    setState(() {
      _firstNameController.text = _savedFirstName;
      _lastNameController.text = _savedLastName;
      _emailController.text = _savedEmail;
      _isEditing = false;
    });
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final id = _userId;

    if (id == null) {
      _showMessage(
        'Utilisateur non connecté.',
        isError: true,
      );
      return;
    }

    final prenom = _firstNameController.text.trim();
    final nom = _lastNameController.text.trim();
    final email =
    _emailController.text.trim().toLowerCase();

    setState(() {
      _isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      final updated = await db.update(
        'users',
        {
          'prenom': prenom,
          'nom': nom,
          'email': email,
        },
        where: 'id = ? AND role = ? AND actif = ?',
        whereArgs: [id, 'CLIENT', 1],
      );

      if (updated == 0) {
        throw StateError(
          'Aucun compte client actif trouvé.',
        );
      }

      if (!mounted) return;

      setState(() {
        _savedFirstName = prenom;
        _savedLastName = nom;
        _savedEmail = email;
        _isEditing = false;
      });

      _showMessage('Profil mis à jour avec succès.');
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        _showMessage(
          'Cet e-mail est déjà utilisé par un autre compte.',
          isError: true,
        );
      } else {
        _showMessage(
          'Erreur SQLite : $e',
          isError: true,
        );
      }
    } catch (e) {
      _showMessage(
        'Impossible de sauvegarder : $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      await SessionService.instance.clear();

      if (!mounted) return;

      // Retour à AuthGate : la session est désormais vide.
      // On remplace la route actuelle pour éviter de
      // revenir sur le profil avec le bouton Retour.
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
            (route) => false,
      );
    } catch (e) {
      _showMessage(
        'Erreur de déconnexion : $e',
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mon profil'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: FilledButton(
            onPressed: _loadProfile,
            child: const Text('Réessayer'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Mon profil'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.primary,
                        Color(0xFF3F8D47),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                    BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary
                            .withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white
                            .withValues(alpha: 0.2),
                        child: Text(
                          '${_firstNameController.text.isNotEmpty ? _firstNameController.text[0] : ''}'
                              '${_lastNameController.text.isNotEmpty ? _lastNameController.text[0] : ''}'
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_firstNameController.text} '
                                  '${_lastNameController.text}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight:
                                FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Compte client',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                color: Colors.white
                                    .withValues(
                                    alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.black
                          .withValues(alpha: 0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Informations personnelles',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                color: AppColors.text,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _isSaving
                                ? null
                                : () {
                              if (_isEditing) {
                                _cancelEditing();
                              } else {
                                setState(() {
                                  _isEditing = true;
                                });
                              }
                            },
                            icon: Icon(
                              _isEditing
                                  ? Icons.close_rounded
                                  : Icons.edit_outlined,
                            ),
                            color: AppColors.primary,
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller:
                              _firstNameController,
                              enabled:
                              _isEditing && !_isSaving,
                              onChanged: (_) =>
                                  setState(() {}),
                              decoration:
                              const InputDecoration(
                                labelText: 'Prénom',
                                prefixIcon: Icon(
                                  Icons.person_outline_rounded,
                                ),
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.trim().isEmpty) {
                                  return 'Prénom requis.';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller:
                              _lastNameController,
                              enabled:
                              _isEditing && !_isSaving,
                              onChanged: (_) =>
                                  setState(() {}),
                              decoration:
                              const InputDecoration(
                                labelText: 'Nom',
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.trim().isEmpty) {
                                  return 'Nom requis.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _emailController,
                        enabled:
                        _isEditing && !_isSaving,
                        keyboardType:
                        TextInputType.emailAddress,
                        decoration:
                        const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              !RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(value.trim())) {
                            return 'Email invalide.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                if (_isEditing)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                      _isSaving ? null : _saveProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                        AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(
                        Icons.save_rounded,
                      ),
                      label: Text(
                        _isSaving
                            ? 'Enregistrement...'
                            : 'Enregistrer les modifications',
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                    _isSaving ? null : _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                      AppColors.error,
                      side: BorderSide(
                        color: AppColors.error
                            .withValues(alpha: 0.4),
                      ),
                      padding:
                      const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(
                      Icons.logout_rounded,
                    ),
                    label: const Text(
                      'Se déconnecter',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
