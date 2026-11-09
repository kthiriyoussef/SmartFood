import 'package:flutter/material.dart';
import 'package:smartfood/features/auth/services/auth_service.dart';

class RestaurantAccessStatusScreen extends StatefulWidget {
  const RestaurantAccessStatusScreen({
    super.key,
    required this.userId,
  });

  final int userId;

  @override
  State<RestaurantAccessStatusScreen> createState() =>
      _RestaurantAccessStatusScreenState();
}

class _RestaurantAccessStatusScreenState
    extends State<RestaurantAccessStatusScreen> {
  Map<String, Object?>? _request;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request =
          await AuthService.instance.getRestoRequestStatus(widget.userId);
      if (!mounted) return;
      setState(() => _request = request);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitRequest() async {
    setState(() => _submitting = true);
    try {
      await AuthService.instance.submitRestaurantAccessRequest(
        userId: widget.userId,
      );
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _message(String? status) {
    switch (status) {
      case 'pending':
        return 'Your restaurant access request is awaiting administrator '
            'review. You can continue using your customer account.';
      case 'approved':
        return 'Your request was approved. Sign out and sign in again to '
            'start restaurant onboarding.';
      case 'rejected':
        return 'Your request was rejected. You may submit a new request.';
      default:
        return 'You have not requested restaurant access.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _request?['status'] as String?;
    final canRequest = status == null || status == 'rejected';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant access'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                status == 'approved'
                                    ? Icons.verified_outlined
                                    : status == 'rejected'
                                        ? Icons.cancel_outlined
                                        : status == 'pending'
                                            ? Icons.hourglass_top
                                            : Icons.storefront_outlined,
                                size: 40,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                status?.toUpperCase() ?? 'NO REQUEST',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _message(status),
                                textAlign: TextAlign.center,
                              ),
                              if (_request?['submitted_at']
                                  case final String date)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text('Submitted: $date'),
                                ),
                              if (_request?['reviewed_at']
                                  case final String date)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Reviewed: $date'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (canRequest) ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _submitting ? null : _submitRequest,
                          child: Text(
                            _submitting ? 'Submitting...' : 'Request access',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
