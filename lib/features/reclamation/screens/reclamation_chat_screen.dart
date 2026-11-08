import 'package:flutter/material.dart';

import 'package:smartfood/features/auth/services/session_service.dart';
import 'package:smartfood/features/reclamation/repositories/reclamation_message_repository.dart';
import 'package:smartfood/features/reclamation/services/reclamation_ai_service.dart';

class ReclamationChatScreen extends StatefulWidget {
  const ReclamationChatScreen({
    super.key,
    required this.reclamationId,
    this.motif,
    this.description,
    this.initialMessage,
  });

  final int reclamationId;
  final String? motif;
  final String? description;
  final String? initialMessage;

  @override
  State<ReclamationChatScreen> createState() => _ReclamationChatScreenState();
}

class _ReclamationChatScreenState extends State<ReclamationChatScreen> {
  final _repository = ReclamationMessageRepository();
  final _aiService = ReclamationAiService();

  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, Object?>> _messages = [];

  int? _userId;
  String? _role;

  bool _loading = true;
  bool _sending = false;
  bool _generating = false;

  String? _error;

  bool get _isAdmin => _role == 'ADMIN';

  @override
  void initState() {
    super.initState();

    if (widget.initialMessage != null &&
        widget.initialMessage!.trim().isNotEmpty) {
      _controller.text = widget.initialMessage!.trim();
    }

    _load();
  }
  // ==========================================
  // CHARGEMENT DES MESSAGES
  // ==========================================

  Future<void> _load() async {
    try {
      final user = await SessionService.instance.restoreUser();

      if (user == null || user['id'] is! int) {
        throw StateError('Veuillez vous connecter.');
      }

      final id = user['id'] as int;
      final role = user['role']?.toString() ?? '';

      final rows = await _repository.messages(
        userId: id,
        reclamationId: widget.reclamationId,
      );

      await _repository.markRead(
        userId: id,
        reclamationId: widget.reclamationId,
      );

      if (!mounted) return;

      setState(() {
        _userId = id;
        _role = role;
        _messages = rows;
        _error = null;
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }

        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ==========================================
  // GENERATION DE REPONSE AVEC GEMINI
  // ==========================================

  Future<void> _genererReponseIA() async {
    if (!_isAdmin || _generating || _sending) return;

    final motif = widget.motif?.trim() ?? '';
    final description = widget.description?.trim() ?? '';

    if (motif.isEmpty && description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le sujet et la description de la réclamation '
            'sont nécessaires pour générer une réponse IA.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _generating = true;
    });

    try {
      final resultat = await _aiService.analyser(
        motif: motif,
        description: description,
      );

      if (!mounted) return;

      final reponse = resultat.reponseSuggeree.trim();

      if (reponse.isEmpty) {
        throw StateError(
          'Gemini n’a proposé aucune réponse.',
        );
      }

      // Respecter la limite de 2000 caractères
      // imposée par ReclamationMessageRepository.
      final texte =
          reponse.length > 2000 ? reponse.substring(0, 2000) : reponse;

      // Ne pas écraser un message déjà rédigé.
      if (_controller.text.trim().isNotEmpty) {
        final remplacer = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Remplacer le brouillon ?'),
              content: const Text(
                'Une réponse est déjà présente dans le champ. '
                'Voulez-vous la remplacer par la suggestion Gemini ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Remplacer'),
                ),
              ],
            );
          },
        );

        if (!mounted || remplacer != true) return;
      }

      _controller.text = texte;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Réponse Gemini générée. '
            'Vérifiez et modifiez le texte avant de l’envoyer.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur Gemini : $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  // ==========================================
  // ENVOI DU MESSAGE
  // ==========================================

  Future<void> _send() async {
    final content = _controller.text.trim();

    if (content.isEmpty || _sending || _generating || _userId == null) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await _repository.send(
        userId: _userId!,
        reclamationId: widget.reclamationId,
        message: content,
      );

      if (!mounted) return;

      _controller.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  // ==========================================
  // LIBERATION DES RESSOURCES
  // ==========================================

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==========================================
  // INTERFACE DE DISCUSSION
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Discussion T-${widget.reclamationId}',
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // ==================================
          // LISTE DES MESSAGES
          // ==================================

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _error != null
                    ? Center(
                        child: Text(_error!),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final row = _messages[index];

                            final mine = row['sender_id'] == _userId;

                            final role = row['sender_role']?.toString() ?? '';

                            final date = DateTime.tryParse(
                              row['date_envoi']?.toString() ?? '',
                            );

                            final time = date == null
                                ? ''
                                : '${date.day.toString().padLeft(2, '0')}/'
                                    '${date.month.toString().padLeft(2, '0')} '
                                    '${date.hour.toString().padLeft(2, '0')}:'
                                    '${date.minute.toString().padLeft(2, '0')}';

                            return Align(
                              alignment: mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 300,
                                ),
                                margin: const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: mine
                                      ? Colors.green.shade100
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      role == 'ADMIN' ? 'ADMIN' : 'CLIENT',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      row['message']?.toString() ?? '',
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      time,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),

          // ==================================
          // BOUTON GEMINI (ADMIN SEULEMENT)
          // ==================================

          if (_isAdmin && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generating || _sending ? null : _genererReponseIA,
                  icon: _generating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome,
                        ),
                  label: Text(
                    _generating
                        ? 'Gemini prépare une réponse...'
                        : 'Suggérer une réponse IA',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

          // ==================================
          // CHAMP DE SAISIE ET ENVOI
          // ==================================

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending &&
                          !_generating &&
                          _error == null &&
                          !_loading,
                      maxLength: 2000,
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Écrire un message...',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _sending || _generating || _loading || _error != null
                            ? null
                            : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send),
                    tooltip: 'Envoyer',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
