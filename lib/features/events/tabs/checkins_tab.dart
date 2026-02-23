import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/qr_scanner_sheet.dart';

class CheckinsTab extends StatefulWidget {
  final String eventId;
  final String eventStatus;

  const CheckinsTab({
    super.key,
    required this.eventId,
    required this.eventStatus,
  });

  @override
  State<CheckinsTab> createState() => _CheckinsTabState();
}

class _CheckinsTabState extends State<CheckinsTab> {
  bool loading = true;
  String? error;

  bool get _canScannTicket => widget.eventStatus == 'published';

  List<Map<String, dynamic>> checkins = [];
  int total = 0;
  int checked = 0;
  int available = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _showScanResult(Map result) {
    final reason = result['reason'];

    String title;
    String message;
    Color color;

    switch (reason) {
      case 'valid':
        title = 'Ingreso válido';
        message = 'Acceso concedido';
        color = Colors.green;
        break;
      case 'duplicated':
        title = 'Ticket ya usado';
        message = 'Este QR ya fue registrado';
        color = Colors.orange;
        break;
      case 'revoked':
        title = 'Acceso revocado';
        message = 'Vendedor bloqueado';
        color = Colors.red;
        break;
      default:
        title = 'No válido';
        message = 'Ticket inválido';
        color = Colors.red;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: color.withValues(alpha: 0.9),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final sb = Supabase.instance.client;

      final res = await sb
          .from('tickets')
          .select('status, checked_in_at, buyer_name, public_code_hash')
          .eq('event_id', widget.eventId)
          .order('checked_in_at', ascending: false)
          .limit(50);

      checkins = (res as List).cast<Map<String, dynamic>>();

      final stats = await sb
          .from('tickets')
          .select('status')
          .eq('event_id', widget.eventId);

      final all = (stats as List).cast<Map<String, dynamic>>();
      total = all.length;
      checked = all.where((x) => x['status'] == 'checked_in').length;
      available = total - checked;
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _statusChip(String status) {
    late Color bg;
    late Color textColor;
    late String text;

    switch (status) {
      case 'checked_in':
        bg = Colors.green.shade100;
        textColor = Colors.green.shade800;
        text = 'Ingresó';
        break;

      case 'duplicated':
        bg = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        text = 'Duplicado';
        break;

      case 'issued':
        bg = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        text = 'Disponible';
        break;

      case 'void':
        bg = Colors.red.shade100;
        textColor = Colors.red.shade800;
        text = 'Anulado';
        break;

      default:
        bg = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        text = 'Inválido';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  Widget _metricCard(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'checked_in':
        return Colors.green;
      case 'void':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_canScannTicket)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.red.shade50,
            child: const Text(
              'El evento no está publicado. No se pueden escanear nuevos códigos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        if (_canScannTicket)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Escanear ticket'),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QrScannerSheet(eventId: widget.eventId),
                        ),
                      );

                      if (result != null) {
                        _showScanResult(result);
                        _load();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        // métricas
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _metricCard(
                'Total',
                total,
                Icons.confirmation_number,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _metricCard(
                'Ingresaron',
                checked,
                Icons.check_circle,
                Colors.green,
              ),
              const SizedBox(width: 12),
              _metricCard(
                'Disponibles',
                available,
                Icons.pending,
                Colors.orange,
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: $error'),
                      ),
                    ],
                  )
                : checkins.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Sin check-ins aún'),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: checkins.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = checkins[i];
                      final status = c['status'] ?? '';
                      return ListTile(
                        leading: Icon(
                          Icons.circle,
                          color: _statusColor(status),
                          size: 12,
                        ),
                        title: Text(c['buyer_name'] ?? 'Sin nombre'),
                        subtitle: Text(c['checked_in_at'] ?? ''),
                        trailing: _statusChip(status),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
