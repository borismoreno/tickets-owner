import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellersTab extends StatefulWidget {
  final String eventId;
  final String eventStatus; // 👈 nuevo

  const SellersTab({
    super.key,
    required this.eventId,
    required this.eventStatus,
  });

  @override
  State<SellersTab> createState() => _SellersTabState();
}

class _SellersTabState extends State<SellersTab> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> sellers = [];

  bool get _canCreateSeller =>
      widget.eventStatus == 'draft' || widget.eventStatus == 'published';

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
      final res = await Supabase.instance.client
          .from('sellers')
          .select('id, name, phone, email, status, created_at')
          .eq('event_id', widget.eventId)
          .order('created_at', ascending: false);

      sellers = (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ===============================
  // 🎨 STATUS CHIP
  // ===============================
  Widget _statusChip(String status) {
    late Color bg;
    late Color textColor;
    late String text;

    switch (status) {
      case 'active':
        bg = Colors.green.shade100;
        textColor = Colors.green.shade800;
        text = 'Activo';
        break;
      case 'closed':
        bg = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        text = 'Cerrado';
        break;
      case 'blocked':
        bg = Colors.red.shade100;
        textColor = Colors.red.shade800;
        text = 'Bloqueado';
        break;
      default:
        bg = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  // ===============================
  // 🎨 SELLER CARD
  // ===============================
  Widget _sellerCard(Map<String, dynamic> s) {
    final name = s['name'] ?? '';
    final phone = (s['phone'] ?? '').toString();
    final email = (s['email'] ?? '').toString();
    final status = (s['status'] ?? '').toString();

    return InkWell(
      onTap: () async {
        await context.push(
          '/events/${widget.eventId}/sellers/${s['id']}',
          extra: widget.eventStatus,
        );
        if (mounted) _load();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (phone.isNotEmpty)
                    Text(phone, style: const TextStyle(color: Colors.grey)),
                  if (email.isNotEmpty)
                    Text(email, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            _statusChip(status),
          ],
        ),
      ),
    );
  }

  // ===============================
  // 🧱 BUILD
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            if (widget.eventStatus == 'closed')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade50,
                child: const Text(
                  'El evento está cerrado. No se pueden crear nuevos vendedores.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
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
                    : sellers.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'Aún no hay vendedores.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: sellers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => _sellerCard(sellers[i]),
                      ),
              ),
            ),
          ],
        ),

        // ===============================
        // 🔵 FAB CON RESTRICCIÓN
        // ===============================
        if (_canCreateSeller)
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/events/${widget.eventId}/sellers/new');
                if (mounted) _load();
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nuevo'),
            ),
          ),
      ],
    );
  }
}
