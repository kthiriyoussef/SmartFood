import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/screens/reservation_details_client.dart';
import 'package:smartfood/features/reservations/widgets/reservation_card.dart';

class ReservationHistoryClientScreen extends StatefulWidget {
  const ReservationHistoryClientScreen({super.key});

  @override
  State<ReservationHistoryClientScreen> createState() =>
      _ReservationHistoryClientScreenState();
}

class _ReservationHistoryClientScreenState
    extends State<ReservationHistoryClientScreen> {
  ReservationFilter _selectedFilter = ReservationFilter.inProgress;

  static const List<Reservation> _mockReservations = [
    Reservation(
      id: 'res -201',
      clientName: 'Sonia Ben Ali',
      pickupTime: 'Aujourd’hui · 18h30',
      status: 'EN_ATTENTE',
      pinCode: '8451',
      phoneNumber: '+21622345678',
      restaurantName: 'Le Petit Jardin',
      dishNames: 'Wrap végétal, salade de saison, jus maison fresh.',
      importantNote: 'Votre repas est en préparation et sera prêt à l’heure indiquée.',
    ),
    Reservation(
      id: 'res -202',
      clientName: 'Sonia Ben Ali',
      pickupTime: 'Aujourd’hui · 19h15',
      status: 'CONFIRMEE',
      pinCode: '5712',
      phoneNumber: '+21622345678',
      restaurantName: 'Boulangerie Bio & Co',
      dishNames: 'Bowl protein, quinoa, légumes grillés.',
      importantNote: 'Réservation confirmée. Vous pouvez récupérer votre commande à l’heure prévue.',
    ),
    Reservation(
      id: 'res -203',
      clientName: 'Sonia Ben Ali',
      pickupTime: 'Demain · 12h00',
      status: 'PREPARATION',
      pinCode: '3478',
      phoneNumber: '+21622345678',
      restaurantName: 'Green Bowl',
      dishNames: 'Pasta anti-gaspi, légumes croquants et sauce maison.',
      importantNote: 'Votre plat est en cours de préparation. Merci pour votre patience.',
    ),
    Reservation(
      id: 'res -204',
      clientName: 'Sonia Ben Ali',
      pickupTime: 'Hier · 18h10',
      status: 'PRETE',
      pinCode: '9284',
      phoneNumber: '+21622345678',
      restaurantName: 'Le Petit Jardin',
      dishNames: 'Bento végétal, riz, avocat, légumes cuits et petit dessert.',
      importantNote: 'Votre commande est prête à être récupérée. Présentez votre QR ou votre code PIN.',
    ),
    Reservation(
      id: 'res -205',
      clientName: 'Sonia Ben Ali',
      pickupTime: 'Vendredi · 17h45',
      status: 'RECUPEREE',
      pinCode: '6610',
      phoneNumber: '+21622345678',
      restaurantName: 'Cocotte & Co',
      dishNames: 'Salade chaude, poulet grillé, pommes de terre rôties.',
      importantNote: 'Cette réservation a déjà été récupérée. Aucun code de retrait n’est actif.',
    ),
    Reservation(
      id: 'res -206',
      clientName: 'Sonia Ben Ali',
      pickupTime: 'Lundi · 16h00',
      status: 'ANNULEE',
      pinCode: '1902',
      phoneNumber: '+21622345678',
      restaurantName: 'Maison de la Cuisine',
      dishNames: 'Plateau anti-gaspi, légumes de saison et soupçon de persil.',
      importantNote: 'Cette réservation a été annulée. Aucun PIN ni QR n’est disponible.',
    ),
  ];

  List<Reservation> get _filteredReservations {
    switch (_selectedFilter) {
      case ReservationFilter.inProgress:
        return _mockReservations
            .where(
              (reservation) => {
                'EN_ATTENTE',
                'CONFIRMEE',
                'PREPARATION',
                'PRETE',
              }.contains(reservation.status),
            )
            .toList();
      case ReservationFilter.recovered:
        return _mockReservations
            .where((reservation) => reservation.status == 'RECUPEREE')
            .toList();
      case ReservationFilter.cancelled:
        return _mockReservations
            .where((reservation) => reservation.status == 'ANNULEE')
            .toList();
      case ReservationFilter.all:
        return _mockReservations;
    }
  }

  int get _inProgressCount => _mockReservations
      .where(
        (reservation) => {
          'EN_ATTENTE',
          'CONFIRMEE',
          'PREPARATION',
          'PRETE',
        }.contains(reservation.status),
      )
      .length;

  int get _recoveredCount => _mockReservations
      .where((reservation) => reservation.status == 'RECUPEREE')
      .length;

  int get _cancelledCount => _mockReservations
      .where((reservation) => reservation.status == 'ANNULEE')
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Mes réservations'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GlassSummaryCard(
                  inProgressCount: _inProgressCount,
                  recoveredCount: _recoveredCount,
                  cancelledCount: _cancelledCount,
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    'Filtres',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ReservationFilter.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final filter = ReservationFilter.values[index];
                      final isSelected = filter == _selectedFilter;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          AppColors.primary.withValues(alpha: 0.18),
                                          AppColors.secondary.withValues(alpha: 0.16),
                                        ],
                                      )
                                    : LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.74),
                                          Colors.white.withValues(alpha: 0.56),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.28)
                                      : Colors.white.withValues(alpha: 0.7),
                                  width: 1.1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isSelected
                                            ? AppColors.primary
                                            : Colors.black)
                                        .withValues(alpha: isSelected ? 0.12 : 0.05),
                                    blurRadius: isSelected ? 16 : 10,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => setState(() => _selectedFilter = filter),
                                child: Center(
                                  child: Text(
                                    filter.label,
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: isSelected ? AppColors.primary : AppColors.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.separated(
                    itemCount: _filteredReservations.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final reservation = _filteredReservations[index];
                      return ReservationCard(
                        reservation: reservation,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReservationDetailScreen(
                                reservation: reservation,
                              ),
                            ),
                          );
                        },
                      );
                    },
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

class _GlassSummaryCard extends StatelessWidget {
  const _GlassSummaryCard({
    required this.inProgressCount,
    required this.recoveredCount,
    required this.cancelledCount,
  });

  final int inProgressCount;
  final int recoveredCount;
  final int cancelledCount;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF102A12),
                Color(0xFF235A30),
                Color(0xFF2E7032),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.34),
                blurRadius: 22,
                spreadRadius: 0,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sonia Ben Ali',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Historique et réservations actives',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      label: 'En cours',
                      value: '$inProgressCount',
                      color: const Color(0xFFFFE7B3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryItem(
                      label: 'Récupérées',
                      value: '$recoveredCount',
                      color: const Color(0xFFE6F8E5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryItem(
                      label: 'Annulées',
                      value: '$cancelledCount',
                      color: const Color(0xFFFFE2E2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum ReservationFilter {
  inProgress,
  recovered,
  cancelled,
  all,
}

extension ReservationFilterExtension on ReservationFilter {
  String get label {
    switch (this) {
      case ReservationFilter.inProgress:
        return 'En cours';
      case ReservationFilter.recovered:
        return 'Récupérées';
      case ReservationFilter.cancelled:
        return 'Annulées';
      case ReservationFilter.all:
        return 'Tous';
    }
  }
}
