import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/screens/reservation_details_client.dart';
import 'package:smartfood/features/reservations/screens/reservation_form_client.dart';
import 'package:smartfood/features/reservations/widgets/reservation_card.dart';

class ReservationListScreen extends StatelessWidget {
  const ReservationListScreen({super.key});

  static const List<Reservation> _mockReservations = [
    Reservation(
      id: 'R-101',
      clientName: 'Sofia Martin',
      pickupTime: 'Aujourd’hui · 18h30',
      status: 'EN_ATTENTE',
      pinCode: '8492',
      phoneNumber: '+33612345678',
    ),
    Reservation(
      id: 'R-102',
      clientName: 'Nicolas Dupont',
      pickupTime: 'Aujourd’hui · 19h00',
      status: 'PRETE',
      pinCode: '2714',
      phoneNumber: '+33623456789',
    ),
    Reservation(
      id: 'R-103',
      clientName: 'Amélie Bernard',
      pickupTime: 'Demain · 12h15',
      status: 'RECUPEREE',
      pinCode: '5608',
      phoneNumber: '+33634567890',
    ),
    Reservation(
      id: 'R-104',
      clientName: 'Thomas Morel',
      pickupTime: 'Demain · 18h45',
      status: 'ANNULEE',
      pinCode: '1936',
      phoneNumber: '+33645678901',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Réservations',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ListView.builder(
          itemCount: _mockReservations.length,
          itemBuilder: (context, index) {
            final reservation = _mockReservations[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ReservationCard(
                reservation: reservation,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ReservationDetailScreen(reservation: reservation),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ReservationFormScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
