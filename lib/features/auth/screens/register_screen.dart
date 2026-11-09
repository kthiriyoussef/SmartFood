import 'package:flutter/material.dart';
import 'package:smartfood/features/auth/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.onAuthenticated,
  });

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
  bool showPassword = false;
  bool requestRestaurantAccess = false;

  static const Color primaryColor = Color(0xFF21834B);
  static const Color backgroundColor = Color(0xFFF5FAF6);

  // ============================================================
  // MESSAGES
  // ============================================================

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // INSCRIPTION
  // ============================================================

  Future<void> submit() async {
    if (loading) return;

    if (!form.currentState!.validate()) {
      return;
    }

    setState(() => loading = true);

    try {
      final user = await AuthService.instance.register(
        nom: nom.text,
        prenom: prenom.text,
        email: email.text,
        password: password.text,
        requestRestaurantAccess: requestRestaurantAccess,
      );

      if (!mounted) return;

      if (requestRestaurantAccess) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Request submitted'),
            content: const Text(
              'Your account was created as a customer. Your request to become '
              'a restaurant owner is pending administrator approval. No '
              'restaurant has been created.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }

      if (!mounted) return;
      widget.onAuthenticated(user);
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  // ============================================================
  // CHAMP DE SAISIE
  // ============================================================

  Widget field(
    TextEditingController controller,
    String label, {
    bool secret = false,
    TextInputType? keyboardType,
    IconData? icon,
    String? Function(String?)? validate,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: secret && !showPassword,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          border: const OutlineInputBorder(),
          suffixIcon: secret
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      showPassword = !showPassword;
                    });
                  },
                  icon: Icon(
                    showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                )
              : null,
        ),
        validator: validate ??
            (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Champ obligatoire';
              }
              return null;
            },
      ),
    );
  }

  Widget _roleOption({
    required bool restaurantOwner,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = requestRestaurantAccess == restaurantOwner;
    return InkWell(
      onTap: loading
          ? null
          : () => setState(
                () => requestRestaurantAccess = restaurantOwner,
              ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withAlpha(18) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? primaryColor : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? primaryColor : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LIBERATION DES CONTROLLERS
  // ============================================================

  @override
  void dispose() {
    nom.dispose();
    prenom.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  // ============================================================
  // INTERFACE SIGN UP
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Créer un compte'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1,
                      size: 64,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Rejoignez SmartFood',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Créez votre compte en quelques étapes',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    field(
                      prenom,
                      'Prénom',
                      icon: Icons.person_outline,
                    ),
                    field(
                      nom,
                      'Nom',
                      icon: Icons.person_outline,
                    ),
                    field(
                      email,
                      'Adresse email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validate: (value) {
                        if (value == null ||
                            !RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(value.trim())) {
                          return 'Adresse email invalide';
                        }
                        return null;
                      },
                    ),
                    field(
                      password,
                      'Mot de passe (10 caractères minimum)',
                      secret: true,
                      icon: Icons.lock_outline,
                      validate: (value) {
                        return AuthService.validatePassword(
                          value ?? '',
                        );
                      },
                    ),
                    field(
                      confirm,
                      'Confirmer le mot de passe',
                      secret: true,
                      icon: Icons.lock_reset,
                      validate: (value) {
                        if (value != password.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'What type of account would you like?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _roleOption(
                      restaurantOwner: false,
                      title: 'Customer / Normal User',
                      subtitle: 'Browse restaurants and make reservations.',
                      icon: Icons.person_outline,
                    ),
                    _roleOption(
                      restaurantOwner: true,
                      title: 'Restaurant Owner',
                      subtitle:
                          'Request administrator approval to manage a restaurant.',
                      icon: Icons.storefront_outlined,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: loading ? null : submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: const Icon(Icons.person_add),
                      label: Text(
                        loading ? 'Création en cours...' : 'Créer mon compte',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed:
                          loading ? null : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Déjà un compte ? Se connecter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
