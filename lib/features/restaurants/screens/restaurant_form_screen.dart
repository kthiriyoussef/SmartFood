import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/services/restaurant_service.dart';
import 'package:smartfood/features/restaurants/widgets/gradient_action_button.dart';

/// Création / modification d'un restaurant.
/// Renvoie l'id du restaurant enregistré via `Navigator.pop`.
class RestaurantFormScreen extends StatefulWidget {
  const RestaurantFormScreen({
    super.key,
    this.restaurant,
    this.ownerUserId,
    this.onOwnerRestaurantCreated,
  })  : assert(
          (ownerUserId == null) == (onOwnerRestaurantCreated == null),
        ),
        assert(ownerUserId == null || restaurant == null);

  final Restaurant? restaurant;
  final int? ownerUserId;
  final void Function(int restaurantId)? onOwnerRestaurantCreated;

  @override
  State<RestaurantFormScreen> createState() => _RestaurantFormScreenState();
}

class _RestaurantFormScreenState extends State<RestaurantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = RestaurantService();
  late final _nom = TextEditingController(text: widget.restaurant?.nom);
  late final _adresse = TextEditingController(text: widget.restaurant?.adresse);
  late final _ville = TextEditingController(text: widget.restaurant?.ville);
  late final _telephone =
      TextEditingController(text: widget.restaurant?.telephone ?? '+216 ');
  bool _saving = false;

  bool get _editing => widget.restaurant != null;

  @override
  void dispose() {
    _nom.dispose();
    _adresse.dispose();
    _ville.dispose();
    _telephone.dispose();
    super.dispose();
  }

  String? _required(String? value, String label, {int min = 2}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label obligatoire';
    if (text.length < min) return '$label trop court';
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final base = widget.restaurant;
    final restaurant = base == null
        ? Restaurant(
            nom: _nom.text,
            adresse: _adresse.text,
            ville: _ville.text,
            telephone: _telephone.text,
            dateCreation: DateTime.now(),
          )
        : base.copyWith(
            nom: _nom.text,
            adresse: _adresse.text,
            ville: _ville.text,
            telephone: _telephone.text,
          );
    try {
      final ownerUserId = widget.ownerUserId;
      final id = ownerUserId == null
          ? await _service.sauvegarderRestaurant(restaurant)
          : await _service.sauvegarderRestaurantPourProprietaire(
              restaurant,
              ownerUserId,
            );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editing ? 'Restaurant mis à jour' : 'Restaurant créé',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final onOwnerRestaurantCreated = widget.onOwnerRestaurantCreated;
      if (onOwnerRestaurantCreated == null) {
        Navigator.of(context).pop(id);
      } else {
        onOwnerRestaurantCreated(id);
      }
    } on RestaurantValidationException catch (e) {
      _error(e.message);
    } catch (_) {
      _error('Enregistrement impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editing ? 'Modifier le restaurant' : 'Nouveau restaurant'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              _editing
                  ? 'Mettez à jour la fiche de votre établissement.'
                  : 'Ces informations seront visibles par les clients.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nom,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: 'Nom du restaurant',
                        hintText: 'Ex. Le Jardin Gourmand',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) => _required(v, 'Nom'),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _adresse,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Adresse',
                        hintText: 'Rue, quartier',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) => _required(v, 'Adresse', min: 3),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _ville,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Ville',
                        hintText: 'Ex. Tunis',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      validator: (v) => _required(v, 'Ville'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _telephone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+().\s-]'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        hintText: '+216 71 123 456',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 7 || digits.length > 15) {
                          return 'Numéro invalide (7 à 15 chiffres)';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_editing) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.warning),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'L’archivage et la réactivation se font depuis la '
                        'fiche du restaurant.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: _saving
              ? const SizedBox(
                  height: 52,
                  child: Center(child: CircularProgressIndicator()),
                )
              : GradientActionButton(
                  onPressed: _save,
                  icon: Icons.check_rounded,
                  label: _editing
                      ? 'Enregistrer les modifications'
                      : 'Créer le restaurant',
                  expand: true,
                ),
        ),
      ),
    );
  }
}
