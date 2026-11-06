import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/services/reservation_service.dart';
import 'package:smartfood/features/users/models/client_profile.dart';
import 'package:smartfood/features/users/repositories/client_profile_repository.dart';

/// Onglet « Profil » : coordonnées du client (pré-remplissent les
/// réservations) et statistiques de ses réservations.
class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _repository = ClientProfileRepository();
  final _reservationService = ReservationService();

  ClientProfile? _profile;
  CountryOption _country = CountryOption.all.first;
  List<Reservation> _reservations = const [];
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
    ReservationService.changes.addListener(_load);
    ClientProfileRepository.changes.addListener(_load);
  }

  @override
  void dispose() {
    ReservationService.changes.removeListener(_load);
    ClientProfileRepository.changes.removeListener(_load);
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await _repository.get();
    final reservations = await _reservationService.getReservations();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _reservations = reservations;
      _loading = false;
      // Sans profil, on affiche directement le formulaire.
      _editing = _editing || profile == null;
      // Ne pas écraser une saisie en cours.
      if (!_editing) _fillControllers(profile);
    });
  }

  void _fillControllers(ClientProfile? profile) {
    _firstName.text = profile?.firstName ?? '';
    _lastName.text = profile?.lastName ?? '';
    _phone.text = profile?.phone ?? '';
    _country = CountryOption.byCode(profile?.dialCode ?? '+216');
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await _repository.save(
      ClientProfile(
        firstName: _capitalize(_firstName.text),
        lastName: _capitalize(_lastName.text),
        dialCode: _country.code,
        phone: _phone.text.replaceAll(RegExp(r'\s'), ''),
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profil enregistré'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Effacer mes informations ?'),
        content: const Text(
          'Vos coordonnées ne seront plus pré-remplies. '
          'Vos réservations sont conservées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _editing = true;
      _fillControllers(null);
    });
    await _repository.clear();
  }

  static String _capitalize(String value) => value
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) =>
          w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Mon profil'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _ProfileHeader(profile: _profile),
                const SizedBox(height: 16),
                _StatsGrid(reservations: _reservations),
                const SizedBox(height: 16),
                _editing ? _buildForm(context) : _buildInfo(context),
                const SizedBox(height: 16),
                const _PickupInfoCard(),
                if (_profile != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _confirmClear,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Effacer mes informations'),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    final profile = _profile!;
    return _Card(
      title: 'Mes informations',
      trailing: TextButton.icon(
        onPressed: () => setState(() {
          _fillControllers(profile);
          _editing = true;
        }),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('Modifier'),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Nom complet',
            value: profile.fullName,
          ),
          const Divider(height: 20),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Téléphone',
            value:
                '${CountryOption.byCode(profile.dialCode).flag}  ${profile.fullPhone}',
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    InputDecoration decoration(String label) => InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        );

    return _Card(
      title: _profile == null
          ? 'Complétez votre profil'
          : 'Modifier mes informations',
      subtitle: _profile == null
          ? 'Vos coordonnées seront pré-remplies à chaque réservation.'
          : null,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _firstName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: decoration('Prénom'),
              validator: (v) => ReservationService.validateName(v, 'Prénom'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: decoration('Nom'),
              validator: (v) => ReservationService.validateName(v, 'Nom'),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<CountryOption>(
                    initialValue: _country,
                    isExpanded: true,
                    decoration: decoration('Pays'),
                    items: [
                      for (final c in CountryOption.all)
                        DropdownMenuItem(
                          value: c,
                          child: Text('${c.flag} ${c.code}'),
                        ),
                    ],
                    onChanged: (c) {
                      if (c == null) return;
                      setState(() => _country = c);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
                      LengthLimitingTextInputFormatter(15),
                    ],
                    decoration: decoration('Téléphone'),
                    validator: (v) =>
                        ReservationService.validatePhone(v, _country.code),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_profile != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _fillControllers(_profile);
                        _editing = false;
                      }),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================ Widgets

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final ClientProfile? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C4E25), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: profile == null
                ? const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 34)
                : Text(
                    profile!.initials,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.fullName ?? 'Bienvenue !',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.fullPhone ?? 'Ajoutez vos coordonnées',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withAlpha(215),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.reservations});

  final List<Reservation> reservations;

  @override
  Widget build(BuildContext context) {
    final active = reservations.where((r) => r.isActive).length;
    final picked = reservations
        .where((r) => r.status == ReservationStatus.recuperee)
        .toList();
    final spent = picked.fold<double>(0, (sum, r) => sum + r.total);

    return Row(
      children: [
        _Stat(
          value: '${reservations.length}',
          label: 'Réservations',
          icon: Icons.receipt_long_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        _Stat(
          value: '$active',
          label: 'En cours',
          icon: Icons.timelapse_rounded,
          color: AppColors.secondary,
        ),
        const SizedBox(width: 10),
        _Stat(
          value: spent.toStringAsFixed(spent % 1 == 0 ? 0 : 1),
          label: 'DT dépensés',
          icon: Icons.payments_outlined,
          color: const Color(0xFF0F766E),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: AppColors.muted, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PickupInfoCard extends StatelessWidget {
  const _PickupInfoCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      title: 'Comment ça marche',
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.restaurant_menu_rounded,
            label: 'Réservation',
            value: 'Aujourd’hui ou demain',
          ),
          Divider(height: 20),
          _InfoRow(
            icon: Icons.schedule_rounded,
            label: 'Retrait',
            value:
                '${ReservationService.openingHour}h00 – ${ReservationService.closingHour}h00',
          ),
          Divider(height: 20),
          _InfoRow(
            icon: Icons.qr_code_2_rounded,
            label: 'Au comptoir',
            value: 'QR code ou code PIN',
          ),
          Divider(height: 20),
          _InfoRow(
            icon: Icons.payments_outlined,
            label: 'Paiement',
            value: 'Sur place',
          ),
        ],
      ),
    );
  }
}
