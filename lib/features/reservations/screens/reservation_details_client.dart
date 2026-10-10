import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';

class ReservationDetailScreen extends StatefulWidget {
  const ReservationDetailScreen({super.key, required this.reservation});

  final Reservation reservation;

  @override
  State<ReservationDetailScreen> createState() => _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  late Reservation _reservation;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _reservation = widget.reservation;
  }

  bool get _isCancelled => _reservation.status == 'ANNULEE';

  @override
  Widget build(BuildContext context) {
    final restaurantName = _reservation.restaurantName ?? 'Restaurant SmartFood';
    final dishNames = _reservation.dishNames ?? 'Plat du jour';
    final importantNote =
        _reservation.importantNote ?? 'Votre commande est en cours de préparation.';
    final hasAccessCode =
        _reservation.status != 'ANNULEE' && _reservation.status != 'RECUPEREE';

    final statusSteps = [
      _StatusStep(title: 'Réservée', isDone: true),
      _StatusStep(title: 'Confirmée', isDone: _reservation.status != 'EN_ATTENTE'),
      _StatusStep(
        title: 'Prête',
        isDone: _reservation.status == 'PRETE' || _reservation.status == 'RECUPEREE',
      ),
      _StatusStep(title: 'Récupérée', isDone: _reservation.status == 'RECUPEREE'),
    ];

    final sliderWidth = 300.0;
    final handleSize = 52.0;
    final maxDrag = sliderWidth - handleSize - 18;
    final actualOffset = _isCancelled ? maxDrag : _dragOffset.clamp(0.0, maxDrag);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Détails réservation'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF4F8F2),
              Color(0xFFF9F9F7),
              Color(0xFFF3F3F0),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF102A12),
                        Color(0xFF1C4E25),
                        Color(0xFF2E7032),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 22,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Réf. ${_reservation.id}',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.76),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _reservation.clientName,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _statusLabel(_reservation.status),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _detailRow(
                        context,
                        Icons.store_mall_directory_outlined,
                        restaurantName,
                      ),
                      const SizedBox(height: 10),
                      _detailRow(
                        context,
                        Icons.restaurant_menu_rounded,
                        dishNames,
                      ),
                      const SizedBox(height: 10),
                      _detailRow(
                        context,
                        Icons.access_time_outlined,
                        _reservation.pickupTime,
                      ),
                      const SizedBox(height: 10),
                      _detailRow(
                        context,
                        Icons.phone_outlined,
                        _reservation.phoneNumber ?? '+33 6 00 00 00 00',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Important',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        importantNote,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.text,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progression',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...statusSteps.asMap().entries.map((entry) {
                        final index = entry.key;
                        final step = entry.value;
                        final isLast = index == statusSteps.length - 1;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: step.isDone
                                        ? AppColors.primary
                                        : Colors.grey.shade300,
                                    shape: BoxShape.circle,
                                  ),
                                  child: step.isDone
                                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                                      : null,
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2,
                                    height: 24,
                                    color: Colors.grey.shade300,
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: 2, bottom: isLast ? 0 : 12),
                                child: Text(
                                  step.title,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: step.isDone ? FontWeight.w700 : FontWeight.w500,
                                    color: step.isDone ? AppColors.text : AppColors.muted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (hasAccessCode)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Code PIN',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: AppColors.muted),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _reservation.pinCode,
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Code QR',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: AppColors.muted),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: 90,
                                height: 90,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: GridView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 3,
                                      mainAxisSpacing: 3,
                                    ),
                                    itemCount: 16,
                                    itemBuilder: (context, index) {
                                      final isDark = (index + (index ~/ 4)) % 2 == 0;
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.primary : Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      'Cette réservation a été annulée. Aucun code PIN ni QR n’est actif.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                if (_isCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_outlined, color: AppColors.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Réservation annulée avec succès.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _dragOffset += details.delta.dx;
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (_dragOffset >= maxDrag * 0.9) {
                        setState(() {
                          _reservation = Reservation(
                            id: _reservation.id,
                            clientName: _reservation.clientName,
                            pickupTime: _reservation.pickupTime,
                            status: 'ANNULEE',
                            pinCode: '',
                            phoneNumber: _reservation.phoneNumber,
                            restaurantName: _reservation.restaurantName,
                            dishNames: _reservation.dishNames,
                            importantNote: _reservation.importantNote,
                          );
                          _dragOffset = maxDrag;
                        });
                      } else {
                        setState(() => _dragOffset = 0);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: sliderWidth,
                      height: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 1.2,
                        ),
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFFFFB067),
                            Color(0xFF4CAF50),
                            Color(0xFFE53935),
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Positioned.fill(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.center,
                                child: Text(
                                  'Glisser pour annuler',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              left: 8,
                              top: 6,
                              bottom: 6,
                              width: handleSize,
                              child: Transform.translate(
                                offset: Offset(actualOffset, 0),
                                child: Container(
                                  width: handleSize,
                                  height: handleSize,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.12),
                                        blurRadius: 10,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _detailRow(BuildContext context, IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.82)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PRETE':
        return 'Prête';
      case 'RECUPEREE':
        return 'Récupérée';
      case 'ANNULEE':
        return 'Annulée';
      case 'CONFIRMEE':
        return 'Confirmée';
      case 'PREPARATION':
        return 'Préparation';
      case 'EN_ATTENTE':
      default:
        return 'En attente';
    }
  }
}

class _StatusStep {
  const _StatusStep({required this.title, required this.isDone});

  final String title;
  final bool isDone;
}
