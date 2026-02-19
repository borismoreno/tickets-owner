import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellersListPage extends StatefulWidget {
  final String eventId;
  const SellersListPage({super.key, required this.eventId});

  @override
  State<SellersListPage> createState() => _SellersListPageState();
}

class _SellersListPageState extends State<SellersListPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> sellers = [];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendedores'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final sellerId = await context.push<String>(
            '/events/${widget.eventId}/sellers/new',
          );

          if (!mounted) return;

          if (sellerId != null) {
            await _load(); // ✅ refresca la lista
            if (!mounted) return;
            context.push(
              '/events/${widget.eventId}/sellers/$sellerId',
            ); // ✅ ir al detalle
          }
        },
        child: const Icon(Icons.person_add),
      ),
      body: RefreshIndicator(
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
                    padding: EdgeInsets.all(16),
                    child: Text('No hay vendedores. Agrega uno con el botón +'),
                  ),
                ],
              )
            : ListView.separated(
                itemCount: sellers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = sellers[i];
                  return ListTile(
                    title: Text(s['name'] ?? ''),
                    subtitle: Text(
                      [
                        if ((s['phone'] ?? '').toString().isNotEmpty)
                          s['phone'],
                        if ((s['email'] ?? '').toString().isNotEmpty)
                          s['email'],
                      ].whereType<String>().join(' • '),
                    ),
                    trailing: Text(_statusEs((s['status'] ?? '').toString())),
                    onTap: () => context.push(
                      '/events/${widget.eventId}/sellers/${s['id']}',
                    ),
                  );
                },
              ),
      ),
    );
  }
}
