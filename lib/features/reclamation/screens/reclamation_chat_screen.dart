import 'package:flutter/material.dart';
import 'package:smartfood/features/auth/services/session_service.dart';
import 'package:smartfood/features/reclamation/repositories/reclamation_message_repository.dart';

class ReclamationChatScreen extends StatefulWidget {
  const ReclamationChatScreen({
    super.key,
    required this.reclamationId,
  });

  final int reclamationId;

  @override
  State<ReclamationChatScreen> createState() => _ReclamationChatScreenState();
}

class _ReclamationChatScreenState extends State<ReclamationChatScreen> {
  final _repository = ReclamationMessageRepository();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, Object?>> _messages = [];
  int? _userId;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await SessionService.instance.restoreUser();

      if (user == null || user['id'] is! int) {
        throw StateError('Veuillez vous connecter.');
      }

      final id = user['id'] as int;

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
        _messages = rows;
        _error = null;
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final content = _controller.text.trim();

    if (content.isEmpty || _sending || _userId == null) return;

    setState(() => _sending = true);

    try {
      await _repository.send(
        userId: _userId!,
        reclamationId: widget.reclamationId,
        message: content,
      );

      _controller.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Discussion T-${widget.reclamationId}'),
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
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
                                constraints:
                                    const BoxConstraints(maxWidth: 300),
                                margin: const EdgeInsets.only(bottom: 12),
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending && _error == null,
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
                    onPressed: _sending || _error != null ? null : _send,
                    icon: const Icon(Icons.send),
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
