import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouvre le composeur téléphonique avec [phone] (ex. « +216 22345678 »).
/// Affiche un message si l'appareil ne peut pas passer d'appel (émulateur
/// sans téléphonie, tablette…).
Future<void> callPhone(BuildContext context, String phone) async {
  final number = phone.replaceAll(RegExp(r'[^\d+]'), '');
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(Uri(scheme: 'tel', path: number));
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Impossible d’ouvrir le téléphone. Numéro : $phone'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
