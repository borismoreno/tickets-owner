import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventEditPage extends StatefulWidget {
  final String eventId;

  const EventEditPage({super.key, required this.eventId});

  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends State<EventEditPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final name = TextEditingController();
  final venue = TextEditingController();

  DateTime? startsAt;
  String status = '';

  bool loading = true;
  bool saving = false;
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
      duration: const Duration(milliseconds: 500),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fade);

    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Supabase.instance.client
          .from('events')
          .select('name, venue_name, starts_at, status')
          .eq('id', widget.eventId)
          .single();

      status = res['status'];

      // ❌ No permitir closed
      if (status == 'closed') {
        if (!mounted) return;
        context.pop();
        return;
      }

      name.text = res['name'] ?? '';
      venue.text = res['venue_name'] ?? '';

      if (res['starts_at'] != null) {
        startsAt = DateTime.tryParse(res['starts_at'])?.toLocal();
      }

      _controller.forward();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    venue.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (status == 'published') return; // 🔒 bloquear fecha

    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: startsAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(startsAt ?? now),
    );

    if (time == null) return;

    setState(() {
      startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await Supabase.instance.client
          .from('events')
          .update({
            'name': name.text.trim(),
            'venue_name': venue.text.trim(),
            if (status == 'draft')
              'starts_at': startsAt?.toUtc().toIso8601String(),
          })
          .eq('id', widget.eventId);

      setState(() => success = true);

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      setState(() => error = 'No se pudo actualizar el evento');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return 'Seleccionar fecha';
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isPublished = status == 'published';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Editar evento',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF1F5F9), Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Actualizar información',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Modifica los datos de tu evento',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 32),

                            if (error != null) ...[
                              Text(
                                error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 20),
                            ],

                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  /// Nombre
                                  TextFormField(
                                    controller: name,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre del evento',
                                      prefixIcon: Icon(Icons.event_outlined),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'El nombre es requerido';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 20),

                                  /// Lugar
                                  TextFormField(
                                    controller: venue,
                                    decoration: const InputDecoration(
                                      labelText: 'Lugar',
                                      prefixIcon: Icon(
                                        Icons.location_on_outlined,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  /// Fecha (bloqueada si published)
                                  InkWell(
                                    onTap: isPublished ? null : _pickDate,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        color: isPublished
                                            ? Colors.grey.shade100
                                            : Colors.transparent,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_month,
                                            color: isPublished
                                                ? Colors.grey
                                                : Colors.black,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _fmt(startsAt),
                                              style: TextStyle(
                                                color: isPublished
                                                    ? Colors.grey
                                                    : Colors.black,
                                              ),
                                            ),
                                          ),
                                          if (isPublished)
                                            const Text(
                                              'Bloqueado',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 30),

                                  GestureDetector(
                                    onTap: saving ? null : _save,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      height: 54,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF6366F1),
                                            Color(0xFF8B5CF6),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.purple.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 18,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: saving
                                            ? const CircularProgressIndicator(
                                                color: Colors.white,
                                              )
                                            : success
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                              )
                                            : const Text(
                                                'Guardar cambios',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
