import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';

/// Badges issus de l'analyse IA de la note client :
/// rouge = allergie, orange = modification, bleu = retard annoncé.
class NoteAnalysisBadges extends StatelessWidget {
  const NoteAnalysisBadges({
    super.key,
    required this.reservation,
    this.compact = false,
  });

  final Reservation reservation;

  /// Version réduite pour les cartes du Suivi (2 modifications max).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final analysis = reservation.noteAnalysis;
    if (analysis == null) {
      if (!reservation.awaitsNoteAnalysis) return const SizedBox.shrink();
      return const _Badge(
        icon: Icons.auto_awesome_rounded,
        label: 'Analyse de la note…',
        foreground: AppColors.muted,
        background: AppColors.inactiveBackground,
      );
    }

    final modifications = compact
        ? analysis.modifications.take(2).toList()
        : analysis.modifications;
    final hidden = analysis.modifications.length - modifications.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (analysis.hasAllergy)
          _Badge(
            icon: Icons.warning_amber_rounded,
            label: 'Allergie : ${analysis.allergies.join(', ')}',
            foreground: Colors.white,
            background: AppColors.error,
            bold: true,
          ),
        for (final m in modifications)
          _Badge(
            icon: Icons.edit_note_rounded,
            label: m,
            foreground: const Color(0xFFB35F00),
            background: AppColors.warningBackground,
          ),
        if (hidden > 0)
          _Badge(
            label: '+$hidden',
            foreground: const Color(0xFFB35F00),
            background: AppColors.warningBackground,
          ),
        if (analysis.lateMinutes != null)
          _Badge(
            icon: Icons.directions_run_rounded,
            label: 'Retard ${analysis.lateMinutes} min',
            foreground: const Color(0xFF1D4ED8),
            background: const Color(0xFFE0E7FF),
          ),
      ],
    );
  }
}

/// Encadré « Instructions cuisine » (détail de la réservation).
class KitchenInstructionsCard extends StatelessWidget {
  const KitchenInstructionsCard({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = reservation.note;
    final analysis = reservation.noteAnalysis;
    final allergy = analysis?.hasAllergy ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: allergy ? AppColors.archivedBackground : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: allergy ? AppColors.error : AppColors.border,
          width: allergy ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allergy
                    ? Icons.warning_amber_rounded
                    : Icons.restaurant_rounded,
                color: allergy ? AppColors.error : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Instructions cuisine',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (analysis != null)
                Tooltip(
                  message: analysis.source == NoteAnalysisSource.gemini
                      ? 'Analysée par Gemini'
                      : 'Analyse locale (mots-clés)',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          size: 14, color: AppColors.muted),
                      const SizedBox(width: 3),
                      Text(
                        analysis.source == NoteAnalysisSource.gemini
                            ? 'Gemini'
                            : 'Local',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (note == null)
            Text(
              'Aucune note du client.',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            )
          else ...[
            if (analysis != null && analysis.kitchenSummary.isNotEmpty) ...[
              Text(
                analysis.kitchenSummary,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: allergy ? AppColors.error : AppColors.text,
                ),
              ),
              const SizedBox(height: 10),
            ],
            NoteAnalysisBadges(reservation: reservation),
            const SizedBox(height: 10),
            Text(
              'Note du client : « $note »',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    this.bold = false,
  });

  final IconData? icon;
  final String label;
  final Color foreground;
  final Color background;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
