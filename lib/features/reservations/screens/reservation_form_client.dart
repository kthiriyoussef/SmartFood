import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/screens/menu_detail_client_screen.dart';
import 'package:smartfood/features/reservations/screens/reservation_confirmation_screen.dart';
import 'package:smartfood/features/reservations/services/reservation_service.dart';
import 'package:smartfood/features/restaurants/models/menu.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/users/models/client_profile.dart';
import 'package:smartfood/features/users/repositories/client_profile_repository.dart';

/// Création d'une réservation pour un plat précis.
///
/// Le plat et le restaurant sont imposés par l'écran appelant (carte ou
/// détail du plat) : le client choisit seulement la quantité, le créneau de
/// retrait et renseigne ses coordonnées.
class ReservationFormScreen extends StatefulWidget {
  const ReservationFormScreen({
    super.key,
    required this.menu,
    required this.restaurant,
  });

  final Menu menu;
  final Restaurant restaurant;

  @override
  State<ReservationFormScreen> createState() => _ReservationFormScreenState();
}

class _ReservationFormScreenState extends State<ReservationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  final _service = ReservationService();

  static const List<CountryOption> _countries = CountryOption.all;
  final _profileRepository = ClientProfileRepository();

  CountryOption _country = _countries.first;

  /// Vrai si le formulaire a été pré-rempli depuis le profil.
  bool _prefilled = false;
  int _quantity = 1;
  late DateTime _today;
  late DateTime _day;
  late TimeOfDay _time;
  String? _pickupError;
  bool _submitting = false;

  int get _maxQuantity => ReservationService.maxQuantityFor(widget.menu);

  DateTime get _pickupAt =>
      DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);

  double get _total => widget.menu.prix * _quantity;

  /// Aujourd'hui n'est proposé que s'il reste un créneau avant la fermeture.
  bool get _todayAvailable {
    final earliest = ReservationService.earliestPickup();
    return earliest != null && DateUtils.isSameDay(earliest, _today);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateUtils.dateOnly(now);
    final earliest = ReservationService.earliestPickup(now: now) ??
        _today.add(
          const Duration(days: 1, hours: ReservationService.openingHour),
        );
    _day = DateUtils.dateOnly(earliest);
    _time = TimeOfDay.fromDateTime(earliest);
    _prefillFromProfile();
  }

  Future<void> _prefillFromProfile() async {
    final profile = await _profileRepository.get();
    if (profile == null || !mounted) return;
    setState(() {
      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
      _phoneController.text = profile.phone;
      _country = CountryOption.byCode(profile.dialCode);
      _prefilled = true;
    });
  }

  /// Après la première réservation, le profil est créé automatiquement
  /// pour ne plus avoir à ressaisir ses coordonnées.
  Future<void> _saveProfileIfMissing() async {
    if (await _profileRepository.get() != null) return;
    await _profileRepository.save(
      ClientProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        dialCode: _country.code,
        phone: _phoneController.text.replaceAll(RegExp(r'\s'), ''),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- Créneau

  void _selectDay(DateTime day) {
    setState(() {
      _day = day;
      // Si l'heure choisie est déjà passée pour aujourd'hui, on avance
      // automatiquement au premier créneau possible.
      final earliest = ReservationService.earliestPickup();
      if (earliest != null &&
          DateUtils.isSameDay(day, earliest) &&
          _pickupAt.isBefore(earliest)) {
        _time = TimeOfDay.fromDateTime(earliest);
      }
      _pickupError = ReservationService.validatePickup(_pickupAt);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Heure de retrait',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _time = picked;
      _pickupError = ReservationService.validatePickup(_pickupAt);
    });
  }

  // -------------------------------------------------------------- Submit

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    final pickupError = ReservationService.validatePickup(_pickupAt);
    final formValid = _formKey.currentState!.validate();
    setState(() => _pickupError = pickupError);
    if (!formValid || pickupError != null) return;

    setState(() => _submitting = true);
    try {
      final reservation = await _service.createReservation(
        menu: widget.menu,
        restaurant: widget.restaurant,
        quantity: _quantity,
        pickupAt: _pickupAt,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        dialCode: _country.code,
        phone: _phoneController.text,
        note: _noteController.text,
      );
      await _saveProfileIfMissing();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReservationConfirmationScreen(
            reservation: reservation,
          ),
        ),
      );
    } on ReservationException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Une erreur est survenue. Réessayez.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
  }

  // --------------------------------------------------------------- Build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tomorrow = _today.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Nouvelle réservation'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _DishSummary(menu: widget.menu, restaurant: widget.restaurant),
            const SizedBox(height: 16),

            // ------------------------------------------------ Quantité
            _Section(
              icon: Icons.shopping_basket_outlined,
              title: 'Quantité',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _quantity >= _maxQuantity
                          ? (_maxQuantity == widget.menu.quantite
                              ? 'Stock maximum atteint'
                              : 'Maximum $_maxQuantity par réservation')
                          : '${widget.menu.quantite} portion(s) disponible(s)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _quantity >= _maxQuantity
                            ? AppColors.warning
                            : AppColors.muted,
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.remove_rounded,
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add_rounded,
                    onPressed: _quantity < _maxQuantity
                        ? () => setState(() => _quantity++)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ------------------------------------------------- Retrait
            _Section(
              icon: Icons.schedule_rounded,
              title: 'Retrait',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DayChip(
                          label: 'Aujourd’hui',
                          selected: DateUtils.isSameDay(_day, _today),
                          enabled: _todayAvailable,
                          onTap: () => _selectDay(_today),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DayChip(
                          label: 'Demain',
                          selected: DateUtils.isSameDay(_day, tomorrow),
                          enabled: true,
                          onTap: () => _selectDay(tomorrow),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Heure de retrait',
                        prefixIcon: const Icon(Icons.access_time_rounded),
                        suffixIcon: const Icon(Icons.edit_outlined, size: 20),
                        errorText: _pickupError,
                        errorMaxLines: 2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        Reservation.formatPickup(_pickupAt),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ouvert de ${ReservationService.openingHour}h00 à '
                    '${ReservationService.closingHour}h00 · préparation '
                    '${ReservationService.preparationDelay.inMinutes} min minimum',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --------------------------------------------- Coordonnées
            _Section(
              icon: Icons.person_outline_rounded,
              title: 'Vos coordonnées',
              child: Column(
                children: [
                  if (_prefilled)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rempli depuis votre profil',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration('Prénom'),
                          validator: (v) =>
                              ReservationService.validateName(v, 'Prénom'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration('Nom'),
                          validator: (v) =>
                              ReservationService.validateName(v, 'Nom'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
                      LengthLimitingTextInputFormatter(15),
                    ],
                    decoration: _inputDecoration('Téléphone').copyWith(
                      hintText: _country.code == '+216' ? '22 345 678' : null,
                      prefixIcon: InkWell(
                        onTap: _showCountryPicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_country.flag,
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 6),
                              Text(
                                _country.code,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded),
                            ],
                          ),
                        ),
                      ),
                    ),
                    validator: (v) =>
                        ReservationService.validatePhone(v, _country.code),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 2,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      'Note pour le restaurant (facultatif)',
                    ).copyWith(hintText: 'Allergies, sans piment…'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ------------------------------------------------ Récap
            _Section(
              icon: Icons.receipt_long_outlined,
              title: 'Récapitulatif',
              child: Column(
                children: [
                  _RecapRow(
                    label: '${widget.menu.nom} × $_quantity',
                    value: formatPrice(_total),
                  ),
                  const SizedBox(height: 6),
                  _RecapRow(
                    label: 'Paiement',
                    value: 'Sur place au retrait',
                    muted: true,
                  ),
                  const Divider(height: 24),
                  _RecapRow(
                    label: 'Total',
                    value: formatPrice(_total),
                    bold: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Confirmer la réservation · ${formatPrice(_total)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  void _showCountryPicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final country in _countries)
              ListTile(
                leading:
                    Text(country.flag, style: const TextStyle(fontSize: 26)),
                title: Text(country.label),
                trailing: Text(
                  country.code,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                selected: country == _country,
                onTap: () {
                  setState(() => _country = country);
                  Navigator.of(sheetContext).pop();
                  // Revalide le numéro avec la règle du nouveau pays.
                  _formKey.currentState?.validate();
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ================================================================ Widgets

class _DishSummary extends StatelessWidget {
  const _DishSummary({required this.menu, required this.restaurant});

  final Menu menu;
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C4E25), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              categoryIcon(menu.categorie),
              color: AppColors.secondary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menu.nom,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${restaurant.nom} · ${menu.categorie}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withAlpha(215),
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatPrice(menu.prix),
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = !enabled
        ? AppColors.muted
        : selected
            ? Colors.white
            : AppColors.text;
    return Material(
      color: selected ? AppColors.primary : AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            enabled ? label : '$label (fermé)',
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final style = (bold
            ? Theme.of(context).textTheme.titleMedium
            : Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: muted ? AppColors.muted : null,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(
          value,
          style: style?.copyWith(color: bold ? AppColors.primary : null),
        ),
      ],
    );
  }
}
