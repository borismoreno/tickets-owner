import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/copy_share_row.dart';

class SellerDetailPage extends StatefulWidget {
  final String eventId;
  final String sellerId;
  final String eventStatus;

  const SellerDetailPage({
    super.key,
    required this.eventId,
    required this.sellerId,
    required this.eventStatus,
  });

  @override
  State<SellerDetailPage> createState() => _SellerDetailPageState();
}

class _SellerDetailPageState extends State<SellerDetailPage> {
  bool loading = true;
  String? error;

  Map<String, dynamic>? seller;
  Map<String, dynamic>? sellerPack;
  List<Map<String, dynamic>> allocations = [];
  Map<String, int> metrics = {'total': 0, 'used': 0, 'void': 0, 'available': 0};

  bool get _canModify =>
      widget.eventStatus == 'draft' || widget.eventStatus == 'published';

  bool get _isClosed => widget.eventStatus == 'closed';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final sb = Supabase.instance.client;

      final s = await sb
          .from('sellers')
          .select('id, name, phone, email, status, created_at')
          .eq('id', widget.sellerId)
          .single();
      seller = Map<String, dynamic>.from(s);

      final p = await sb
          .from('seller_packs')
          .select('status, expires_at, revoked_at')
          .eq('event_id', widget.eventId)
          .eq('seller_id', widget.sellerId)
          .maybeSingle();

      sellerPack = p;

      final a = await sb
          .from('allocations')
          .select('id, quantity, status, note, created_at')
          .eq('event_id', widget.eventId)
          .eq('seller_id', widget.sellerId)
          .order('created_at', ascending: false);

      allocations = (a as List).cast<Map<String, dynamic>>();

      // Métricas (MVP): contar tickets del seller via allocations
      final allocIds = allocations.map((x) => x['id']).toList();
      if (allocIds.isEmpty) {
        metrics = {'total': 0, 'used': 0, 'void': 0, 'available': 0};
      } else {
        final t = await sb
            .from('tickets')
            .select('status, allocation_id')
            .eq('event_id', widget.eventId)
            .inFilter('allocation_id', allocIds);

        final tickets = (t as List).cast<Map<String, dynamic>>();
        final total = tickets.length;
        final used = tickets.where((x) => x['status'] == 'checked_in').length;
        final voided = tickets.where((x) => x['status'] == 'void').length;
        final available = total - used - voided;

        metrics = {
          'total': total,
          'used': used,
          'void': voided,
          'available': available,
        };
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _revokeSellerPack() async {
    try {
      await Supabase.instance.client
          .from('seller_packs')
          .update({
            'status': 'revoked',
            'revoked_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('event_id', widget.eventId)
          .eq('seller_id', widget.sellerId);

      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showPackAccessDialog({
    required String packLink,
    required String pin,
    String title = 'Acceso generado',
  }) {
    final shareText =
        '''
        Hola 👋
        Aquí tienes tus tickets para el evento.

        Link: $packLink
        PIN: $pin

        Abre el link e ingresa el PIN para ver y distribuir los tickets.
        ''';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CopyShareRow(
              label: 'Link del vendedor',
              value: packLink,
              shareLabel: shareText,
              allowShare: false,
            ),
            const SizedBox(height: 12),
            CopyShareRow(label: 'PIN', value: pin, allowShare: false),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: shareText));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copiado: Link + PIN')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_all),
                    label: const Text('Copiar todo'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showExistingAccessDialog(String packLink) {
    final message =
        '''
⚠️ Este vendedor ya tenía acceso previamente.
Se mantiene el mismo link y PIN.

Link: $packLink
''';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Acceso existente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⚠️ Este vendedor ya tenía acceso previamente.\n\n'
              'Se mantiene el mismo link y PIN.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            CopyShareRow(
              label: 'Link del vendedor',
              value: packLink,
              shareLabel: message,
              allowShare: false,
            ),
            const SizedBox(height: 12),
            const Text(
              'El PIN sigue siendo el mismo.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _statusEs(String s) {
    switch (s) {
      case 'active':
        return 'Activo';
      case 'closed':
        return 'Cerrado';
      case 'blocked':
        return 'Bloqueado';
      default:
        return s;
    }
  }

  Future<void> _resendSellerPack() async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'rotate_seller_pack',
        body: {'eventId': widget.eventId, 'sellerId': widget.sellerId},
      );

      if (res.status != 200) {
        throw Exception(res.data.toString());
      }

      final packLink = res.data['packLink'];
      final pin = res.data['pin'];

      _showPackAccessDialog(
        packLink: packLink,
        pin: pin,
        title: 'Acceso regenerado',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showAssignTicketsModal() async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignTicketsSheet(
        eventId: widget.eventId,
        sellerId: widget.sellerId,
      ),
    );

    // if (result != null) {
    //   // Muestra info del pack para copiar/compartir (sin plugins por ahora)
    //   final packLink = result['packLink'];
    //   final pin = result['pin'];

    //   _showPackAccessDialog(
    //     packLink: packLink,
    //     pin: pin,
    //     title: 'Paquete generado',
    //   );

    //   await _load();
    // }
    if (result != null) {
      final packLink = result['packLink'];
      final pin = result['pin'];
      final isNew = result['isNew'] == true;

      if (isNew) {
        _showPackAccessDialog(
          packLink: packLink,
          pin: pin,
          title: 'Paquete generado',
        );
      } else {
        _showExistingAccessDialog(packLink);
      }

      await _load();
    }
  }

  Widget _buildPackStatus() {
    if (sellerPack == null) {
      return const Text('Sin acceso generado aún');
    }

    final status = sellerPack!['status'];
    final expiresAtStr = sellerPack!['expires_at'];
    final expiresAt = DateTime.tryParse(expiresAtStr ?? '');
    final now = DateTime.now().toUtc();

    bool expired = expiresAt != null && now.isAfter(expiresAt);

    Color color;
    String label;

    if (status == 'revoked') {
      color = Colors.red;
      label = 'Revocado';
    } else if (expired) {
      color = Colors.orange;
      label = 'Expirado';
    } else {
      color = Colors.green;
      final days = expiresAt!.difference(now).inDays;
      label = 'Activo — vence en $days días';
    }

    return Row(
      children: [
        Icon(Icons.circle, size: 12, color: color),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = seller?['name'] ?? 'Vendedor';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: _canModify
          ? FloatingActionButton.extended(
              onPressed: _showAssignTicketsModal,
              icon: const Icon(Icons.confirmation_num),
              label: const Text('Asignar tickets'),
            )
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorBanner(message: error!),
            )
          : Column(
              children: [
                if (_isClosed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.shade50,
                    child: const Text(
                      'Evento cerrado. No se pueden modificar asignaciones ni accesos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Estado: ${_statusEs((seller?['status'] ?? '').toString())}',
                      ),
                      const SizedBox(height: 12),
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Acceso del vendedor',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              _buildPackStatus(),
                              const SizedBox(height: 12),
                              if (_canModify)
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _resendSellerPack,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Regenerar acceso'),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      onPressed: _revokeSellerPack,
                                      icon: const Icon(Icons.block),
                                      label: const Text('Revocar'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      _MetricsRow(metrics: metrics),
                      const SizedBox(height: 24),
                      const Text(
                        'Asignaciones (lotes)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (allocations.isEmpty)
                        const Text('Este vendedor aún no tiene asignaciones.')
                      else
                        ...allocations.map(
                          (a) => Card(
                            child: ListTile(
                              title: Text(
                                'Cantidad: ${a['quantity']} • ${_allocStatusEs(a['status']?.toString() ?? '')}',
                              ),
                              subtitle: Text(a['note']?.toString() ?? ''),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 8),
                                  Text(
                                    a['created_at']?.toString().substring(
                                          0,
                                          10,
                                        ) ??
                                        '',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _allocStatusEs(String s) {
    switch (s) {
      case 'active':
        return 'Activo';
      case 'closed':
        return 'Cerrado';
      case 'revoked':
        return 'Revocado';
      default:
        return s;
    }
  }
}

class _MetricsRow extends StatelessWidget {
  final Map<String, int> metrics;
  const _MetricsRow({required this.metrics});

  @override
  Widget build(BuildContext context) {
    Widget box(String label, int value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(label),
          ],
        ),
      ),
    );

    return Row(
      children: [
        box('Total', metrics['total'] ?? 0),
        const SizedBox(width: 10),
        box('Disponibles', metrics['available'] ?? 0),
        const SizedBox(width: 10),
        box('Usados', metrics['used'] ?? 0),
      ],
    );
  }
}

class _AssignTicketsSheet extends StatefulWidget {
  final String eventId;
  final String sellerId;

  const _AssignTicketsSheet({required this.eventId, required this.sellerId});

  @override
  State<_AssignTicketsSheet> createState() => _AssignTicketsSheetState();
}

class _AssignTicketsSheetState extends State<_AssignTicketsSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final qty = TextEditingController(text: '10');
  final note = TextEditingController();

  bool loading = false;
  bool success = false;
  String? error;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fade);

    _controller.forward();
  }

  @override
  void dispose() {
    qty.dispose();
    note.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    final q = int.parse(qty.text.trim());

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final sb = Supabase.instance.client;

      final res = await sb.functions.invoke(
        'create_allocation_and_pack',
        body: {
          'eventId': widget.eventId,
          'sellerId': widget.sellerId,
          'quantity': q,
          'note': note.text.trim().isEmpty ? null : note.text.trim(),
        },
      );

      if (res.status != 200) {
        throw Exception(res.data);
      }

      setState(() => success = true);

      await Future.delayed(const Duration(milliseconds: 800));

      final data = res.data as Map;
      final pack = (data['pack'] as Map?) ?? {};

      final isNew = pack['isNew'] == true;

      if (!mounted) return;

      Navigator.pop(context, {
        'packLink': pack['packLink'],
        'pin': pack['pin'],
        'isNew': isNew,
      });
    } catch (e) {
      setState(() => error = 'No se pudo generar el paquete');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _gradientButton() {
    return GestureDetector(
      onTap: loading ? null : submit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const CircularProgressIndicator(color: Colors.white)
              : success
              ? const Icon(Icons.check, color: Colors.white)
              : const Text(
                  'Generar paquete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottom + 20,
      ),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Header visual
                  Row(
                    children: const [
                      Icon(
                        Icons.confirmation_number_outlined,
                        color: Color(0xFF6366F1),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Asignar tickets',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Genera un paquete para este vendedor',
                    style: TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 24),

                  if (error != null) ...[
                    ErrorBanner(message: error!),
                    const SizedBox(height: 16),
                  ],

                  /// Cantidad
                  TextFormField(
                    controller: qty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      prefixIcon: Icon(Icons.numbers_outlined),
                    ),
                    validator: (v) {
                      final q = int.tryParse(v ?? '');
                      if (q == null || q <= 0 || q > 5000) {
                        return 'Debe estar entre 1 y 5000';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  /// Nota
                  TextFormField(
                    controller: note,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opcional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),

                  const SizedBox(height: 28),

                  _gradientButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
