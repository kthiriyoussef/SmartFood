
import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reclamation/screens/profile_client_screen.dart';
import 'package:smartfood/features/reclamation/screens/reclamation_form_client.dart';
import 'package:smartfood/features/reclamation/screens/reclamation_history_client_screen.dart';

class SupportNavigationScreen extends StatelessWidget {
  const SupportNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SmartFood • Support'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Centre de support',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Déposez une réclamation et suivez son traitement.',
          ),
          const SizedBox(height: 24),
          _navigationCard(
            context,
            title: 'Déposer une réclamation',
            subtitle: 'Motif, description et justificatif',
            icon: Icons.add_circle_outline,
            screen: const ReclamationFormScreen(),
          ),
          _navigationCard(
            context,
            title: 'Mes réclamations',
            subtitle: 'Historique et suivi des statuts',
            icon: Icons.history,
            screen: const ReclamationHistoryClientScreen(),
          ),
          _navigationCard(
            context,
            title: 'Mon profil',
            subtitle: 'Informations personnelles',
            icon: Icons.person_outline,
            screen: const ProfileClientScreen(),
          ),
        ],
      ),
    );
  }

  Widget _navigationCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Widget screen,
      }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(
          icon,
          size: 30,
          color: AppColors.primary,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => screen),
          );
        },
      ),
    );
  }
}
