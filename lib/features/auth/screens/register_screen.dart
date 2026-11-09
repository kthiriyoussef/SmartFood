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
  bool loadingRestaurants = false;
  bool requestResto = false;
  bool showPassword = false;

  int? restaurantId;

  List<Map<String, Object?>> restaurants = [];

  static const Color primaryColor = Color(0xFF21834B);
  static const Color backgroundColor = Color(0xFFF5FAF6);

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  // ============================================================
  // CHARGEMENT DES RESTAURANTS
  // ============================================================

  Future<void> _loadRestaurants() async {
    setState(() => loadingRestaurants = true);

    try {
      final result = await AuthService.instance.getActiveRestaurants();

      if (!mounted) return;

      setState(() {
        restaurants = result;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Impossible de charger les restaurants : $e',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => loadingRestaurants = false);
      }
    }
  }

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

    if (requestResto && restaurantId == null) {
      _showMessage(
        'Veuillez sélectionner un restaurant.',
        error: true,
      );
      return;
    }

    setState(() => loading = true);

    try {
      final user = await AuthService.instance.register(
        nom: nom.text,
        prenom: prenom.text,
        email: email.text,
        password: password.text,
        requestResto: requestResto,
        restaurantId: requestResto ? restaurantId : null,
      );

      if (!mounted) return;

      if (requestResto) {
        // La demande est créée, mais le rôle reste CLIENT
        // jusqu'à l'approbation par l'administrateur.
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.orange,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Demande envoyée'),
                ),
              ],
            ),
            content: const Text(
              'Votre compte a été créé avec succès.\n\n'
              'Votre demande pour devenir directeur de '
              'restaurant a été envoyée à l’administrateur.\n\n'
              'Vous pouvez utiliser votre compte Client '
              'en attendant la validation. Après acceptation, '
              'reconnectez-vous pour accéder à '
              'l’espace Restaurant.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Compris'),
              ),
            ],
          ),
        );
      }

      if (!mounted) return;

      // Connexion avec le rôle actuellement autorisé.
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

  // ============================================================
  // SELECTION DU TYPE DE COMPTE
  // ============================================================

  Widget _accountTypeCard({
    required bool isResto,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = requestResto == isResto;

    return InkWell(
      onTap: loading
          ? null
          : () {
              setState(() {
                requestResto = isResto;
                restaurantId = null;
              });
            },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withAlpha(18) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 30,
              color: selected ? primaryColor : Colors.grey,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? primaryColor : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SELECTION DU RESTAURANT
  // ============================================================

  Widget _restaurantSelection() {
    if (loadingRestaurants) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (restaurants.isEmpty) {
      return Column(
        children: [
          const Text(
            'Aucun restaurant disponible.',
            style: TextStyle(color: Colors.red),
          ),
          TextButton.icon(
            onPressed: _loadRestaurants,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey(restaurantId),
          initialValue: restaurantId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Votre restaurant',
            prefixIcon: Icon(Icons.restaurant),
            border: OutlineInputBorder(),
          ),
          items: restaurants.map((restaurant) {
            return DropdownMenuItem<int>(
              value: restaurant['id'] as int,
              child: Text(
                restaurant['nom'] as String,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: loading
              ? null
              : (value) {
                  setState(() => restaurantId = value);
                },
          validator: (value) {
            if (requestResto && value == null) {
              return 'Veuillez sélectionner un restaurant';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.orange,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Votre demande sera envoyée à '
                  'l’administrateur SmartFood. '
                  'Vous aurez accès à l’interface '
                  'Restaurant uniquement après '
                  'son approbation.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
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
                    const SizedBox(height: 12),
                    const Text(
                      'Choisissez votre type de compte',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _accountTypeCard(
                      isResto: false,
                      title: 'Client',
                      subtitle:
                          'Réserver des repas et déposer des réclamations',
                      icon: Icons.person,
                    ),
                    _accountTypeCard(
                      isResto: true,
                      title: 'Directeur de restaurant',
                      subtitle: 'Gérer un restaurant après validation admin',
                      icon: Icons.storefront,
                    ),
                    if (requestResto) ...[
                      const SizedBox(height: 12),
                      _restaurantSelection(),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: loading || (requestResto && loadingRestaurants)
                          ? null
                          : submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: Icon(
                        requestResto ? Icons.send_rounded : Icons.person_add,
                      ),
                      label: Text(
                        loading
                            ? 'Création en cours...'
                            : requestResto
                                ? 'Créer et envoyer ma demande'
                                : 'Créer mon compte',
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
