import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventsListPage extends StatefulWidget {
  const EventsListPage({super.key});

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends State<EventsListPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> events = [];

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
          .from('events')
          .select('id, name, starts_at, venue_name, status, created_at')
          .order('starts_at', ascending: false);

      events = (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ===============================
  // 🔄 STATUS UPDATE
  // ===============================
  Future<void> _updateStatus(String eventId, String status) async {
    await Supabase.instance.client
        .from('events')
        .update({'status': status})
        .eq('id', eventId);

    await _load();
  }

  // ===============================
  // 🗑 DELETE
  // ===============================
  Future<void> _deleteEvent(String eventId) async {
    await Supabase.instance.client.from('events').delete().eq('id', eventId);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Evento eliminado')));

    await _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> event) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Eliminar evento'),
        content: Text(
          '¿Estás seguro de eliminar "${event['name']}"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            // style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteEvent(event['id']);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ===============================
  // 📅 FORMAT
  // ===============================
  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  // ===============================
  // 🎨 STATUS CHIP
  // ===============================
  Widget _statusChip(String status) {
    late Color bg;
    late Color textColor;
    late String text;

    switch (status) {
      case 'draft':
        bg = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        text = 'Borrador';
        break;
      case 'published':
        bg = Colors.green.shade100;
        textColor = Colors.green.shade800;
        text = 'Publicado';
        break;
      case 'closed':
        bg = Colors.red.shade100;
        textColor = Colors.red.shade800;
        text = 'Cerrado';
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
  // 📌 EVENT CARD
  // ===============================
  Widget _eventCard(Map<String, dynamic> e) {
    final name = e['name'] ?? '';
    final venue = e['venue_name'] ?? '';
    final status = (e['status'] ?? '').toString();
    final id = e['id'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // ===============================
              // 🎯 MENU DINÁMICO
              // ===============================
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'edit':
                      final updated = await context.push('/events/$id/edit');
                      if (updated == true) {
                        await _load();
                      }
                      break;

                    case 'publish':
                      await _updateStatus(id, 'published');
                      break;

                    case 'close':
                      await _updateStatus(id, 'closed');
                      break;

                    case 'metrics':
                      context.push('/events/$id');
                      break;

                    case 'delete':
                      _confirmDelete(e);
                      break;
                  }
                },
                itemBuilder: (_) {
                  List<PopupMenuEntry<String>> items = [];

                  if (status == 'draft') {
                    items.addAll([
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'publish',
                        child: Row(
                          children: [
                            Icon(Icons.public),
                            SizedBox(width: 8),
                            Text('Publicar'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar'),
                          ],
                        ),
                      ),
                    ]);
                  }

                  if (status == 'published') {
                    items.addAll([
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'close',
                        child: Row(
                          children: [
                            Icon(Icons.lock),
                            SizedBox(width: 8),
                            Text('Cerrar evento'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'metrics',
                        child: Row(
                          children: [
                            Icon(Icons.bar_chart),
                            SizedBox(width: 8),
                            Text('Ver métricas'),
                          ],
                        ),
                      ),
                    ]);
                  }

                  if (status == 'closed') {
                    items.add(
                      const PopupMenuItem(
                        value: 'metrics',
                        child: Row(
                          children: [
                            Icon(Icons.bar_chart),
                            SizedBox(width: 8),
                            Text('Ver métricas'),
                          ],
                        ),
                      ),
                    );
                  }

                  return items;
                },
              ),
            ],
          ),

          const SizedBox(height: 6),

          InkWell(
            onTap: () async {
              final updated = await context.push('/events/$id');
              if (updated == true) {
                await _load();
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_fmtDate(e['starts_at'])} • $venue',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statusChip(status),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===============================
  // 🏗 BUILD
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis eventos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push('/events/new');
          if (created == true) {
            _load();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo evento'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : events.isEmpty
            ? const Center(
                child: Text(
                  'Aún no tienes eventos.\nCrea uno con el botón "Nuevo evento".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) => _eventCard(events[i]),
              ),
      ),
    );
  }
}
