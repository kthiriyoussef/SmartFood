import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/restaurants/models/menu.dart' as model;
import 'package:smartfood/features/restaurants/services/menu_service.dart';
import 'package:smartfood/features/restaurants/widgets/gradient_action_button.dart';

/// Création / modification d'un plat. Renvoie l'id via `Navigator.pop`.
class MenuFormScreen extends StatefulWidget {
  const MenuFormScreen({
    super.key,
    required this.restaurantId,
    this.menu,
    this.restaurantArchived = false,
  });

  final int restaurantId;
  final model.Menu? menu;

  /// Un plat d'un restaurant archivé ne peut pas être remis en vente.
  final bool restaurantArchived;

  @override
  State<MenuFormScreen> createState() => _MenuFormScreenState();
}

class _MenuFormScreenState extends State<MenuFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = MenuService();
  late final _nom = TextEditingController(text: widget.menu?.nom);
  late final _description =
      TextEditingController(text: widget.menu?.description);
  late final _prix = TextEditingController(
    text: widget.menu == null ? '' : _formatPrice(widget.menu!.prix),
  );
  late final _quantite =
      TextEditingController(text: widget.menu?.quantite.toString() ?? '');
  late String _categorie =
      MenuService.categories.contains(widget.menu?.categorie)
          ? widget.menu!.categorie
          : MenuService.categories[1]; // « Plat » par défaut
  late bool _disponible =
      widget.restaurantArchived ? false : (widget.menu?.disponible ?? true);
  bool _saving = false;

  bool get _editing => widget.menu != null;

  static String _formatPrice(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  /// Accepte « 12,5 » comme « 12.5 ».
  static double? _parsePrice(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _nom.dispose();
    _description.dispose();
    _prix.dispose();
    _quantite.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final quantite = int.parse(_quantite.text.trim());
    final base = widget.menu;
    final menu = model.Menu(
      id: base?.id,
      restaurantId: widget.restaurantId,
      nom: _nom.text,
      description: _description.text,
      prix: _parsePrice(_prix.text)!,
      categorie: _categorie,
      quantite: quantite,
      // Sans stock, le plat ne peut pas être proposé aux clients.
      disponible: _disponible && quantite > 0,
      dateCreation: base?.dateCreation ?? DateTime.now(),
    );

    setState(() => _saving = true);
    try {
      final id = await _service.sauvegarderMenu(menu);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_editing ? 'Plat mis à jour' : 'Plat ajouté à la carte'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(id);
    } on MenuValidationException catch (e) {
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
      appBar:
          AppBar(title: Text(_editing ? 'Modifier le plat' : 'Nouveau plat')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nom,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: 'Nom du plat',
                        hintText: 'Ex. Couscous du chef',
                        prefixIcon: Icon(Icons.restaurant_menu_rounded),
                      ),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) return 'Nom obligatoire';
                        if (text.length < 2) return 'Nom trop court';
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _categorie,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        for (final c in MenuService.categories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) => setState(() => _categorie = v!),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _prix,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Prix',
                              prefixIcon: Icon(Icons.sell_outlined),
                              suffixText: 'DT',
                            ),
                            validator: (v) {
                              final price = _parsePrice(v ?? '');
                              if (price == null) return 'Prix invalide';
                              if (price <= 0) return 'Doit être > 0';
                              if (price > 1000) return 'Prix trop élevé';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _quantite,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Stock',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                              suffixText: 'portions',
                            ),
                            validator: (v) =>
                                int.tryParse(v?.trim() ?? '') == null
                                    ? 'Stock requis'
                                    : null,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 4,
                      maxLength: 250,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Ingrédients, accompagnements, allergènes…',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                value: _disponible,
                onChanged: widget.restaurantArchived
                    ? null
                    : (v) => setState(() => _disponible = v),
                title: Text(
                  _disponible ? 'En vente' : 'Retiré de la vente',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  widget.restaurantArchived
                      ? 'Restaurant archivé : remise en vente impossible.'
                      : (int.tryParse(_quantite.text.trim()) ?? 0) == 0 &&
                              _disponible
                          ? 'Stock à 0 : le plat sera enregistré hors vente.'
                          : 'Les clients peuvent le réserver s’il reste du stock.',
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
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
                  label:
                      _editing ? 'Enregistrer le plat' : 'Ajouter à la carte',
                  icon: Icons.check_rounded,
                  expand: true,
                  onPressed: _save,
                ),
        ),
      ),
    );
  }
}
