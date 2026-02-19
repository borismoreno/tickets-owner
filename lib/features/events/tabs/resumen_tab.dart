import 'package:flutter/material.dart';
import '../../../core/utils/event_status_ext.dart';

class ResumenTab extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onPublish;
  final VoidCallback onClose;

  const ResumenTab({
    super.key,
    required this.event,
    required this.onPublish,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final status = (event['status'] ?? '').toString();
    final venue = event['venue_name'] ?? '-';
    final startsAt = event['starts_at'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _heroCard(context, status),
        const SizedBox(height: 20),
        _infoCard(Icons.location_on, 'Lugar', venue),
        const SizedBox(height: 12),
        _infoCard(Icons.schedule, 'Fecha', startsAt.toString()),
        const SizedBox(height: 24),
        _actionSection(context, status),
      ],
    );
  }

  // 🔷 HERO CARD
  Widget _heroCard(BuildContext context, String status) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [primary.withValues(alpha: 0.9), primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event['name'] ?? '',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.labelEs,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔷 INFO CARD
  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔷 ACTION SECTION
  Widget _actionSection(BuildContext context, String status) {
    if (status == 'draft') {
      return ElevatedButton.icon(
        onPressed: onPublish,
        icon: const Icon(Icons.public),
        label: const Text('Publicar evento'),
      );
    }

    if (status == 'published') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        onPressed: onClose,
        icon: const Icon(Icons.lock),
        label: const Text('Cerrar evento'),
      );
    }

    return const SizedBox();
  }
}
