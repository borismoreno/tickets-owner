import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class CopyShareRow extends StatelessWidget {
  final String label;
  final String value;
  final String? shareLabel; // texto para compartir (si es distinto al value)
  final bool allowShare;

  const CopyShareRow({
    super.key,
    required this.label,
    required this.value,
    this.shareLabel,
    this.allowShare = true,
  });

  Future<void> _copy(BuildContext context, String text, String okMsg) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMsg)));
  }

  Future<void> _share(BuildContext context, GlobalKey key, String text) async {
    try {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) throw Exception("No render box");

      await Share.share(
        text,
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo compartir: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shareText = shareLabel ?? value;
    final shareKey = GlobalKey();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                SelectableText(value),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Copiar',
            onPressed: () => _copy(context, value, 'Copiado: $label'),
            icon: const Icon(Icons.copy),
          ),
          if (allowShare)
            IconButton(
              key: shareKey,
              tooltip: 'Compartir',
              onPressed: () => _share(context, shareKey, shareText),
              icon: const Icon(Icons.ios_share),
            ),
        ],
      ),
    );
  }
}
