import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tabs/resumen_tab.dart';
import '../tabs/sellers_tab.dart';
import '../tabs/checkins_tab.dart';

class EventDetailPage extends StatefulWidget {
  final String eventId;
  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool loading = true;
  String? error;
  Map<String, dynamic>? event;
  int totalTickets = 0;
  int totalSellers = 0;
  int totalCheckins = 0;
  bool isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
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
          .select('id, name, starts_at, venue_name, status')
          .eq('id', widget.eventId)
          .single();

      event = Map<String, dynamic>.from(res);
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() => isLoadingStats = true);

    final supabase = Supabase.instance.client;

    // Total tickets
    final ticketsRes = await supabase
        .from('tickets')
        .select('id')
        .eq('event_id', widget.eventId);

    // Total sellers
    final sellersRes = await supabase
        .from('sellers')
        .select('id')
        .eq('event_id', widget.eventId);

    // Total check-ins
    final checkinsRes = await supabase
        .from('tickets')
        .select('id')
        .eq('event_id', widget.eventId)
        .eq('status', 'checked_in');

    setState(() {
      totalTickets = ticketsRes.length;
      totalSellers = sellersRes.length;
      totalCheckins = checkinsRes.length;
      isLoadingStats = false;
    });
  }

  Future<void> _updateStatus(String status) async {
    try {
      await Supabase.instance.client
          .from('events')
          .update({'status': status})
          .eq('id', widget.eventId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _eventStatusChip(String status) {
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

      default:
        bg = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        text = status;
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

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          color: Colors.white,
          child: const TabBar(
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Vendedores'),
              Tab(text: 'Check-In'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      children: [
        ResumenTab(
          event: event!,
          onPublish: () => _updateStatus('published'),
          onClose: () => _updateStatus('closed'),
        ),
        SellersTab(eventId: widget.eventId),
        CheckinsTab(eventId: widget.eventId),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = event?['name'] ?? 'Evento';
    final status = event?['status'] ?? 'Borrador';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _eventStatusChip(status),
            ),
          ],
          bottom: PreferredSize(
            // 👈 MOVER EL TABBAR AQUÍ
            preferredSize: const Size.fromHeight(60),
            child: _buildTabBar(),
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(child: Text('Error: $error'))
            : Column(
                children: [
                  // _buildHeaderSummary(),
                  Expanded(
                    child: _buildTabBarView(), // 👈 SOLO EL VIEW AQUÍ
                  ),
                ],
              ),
      ),
    );
  }
}
