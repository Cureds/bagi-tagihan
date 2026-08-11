// lib/screens/history_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class HistoryDetailScreen extends StatelessWidget {
  final HistoryEntry entry;
  const HistoryDetailScreen({super.key, required this.entry});

  String _buildShareText() {
    final buf = StringBuffer('🧾 *${entry.title}*\n');
    buf.writeln('📅 ${entry.formattedDate}\n');

    if (entry.notaGroups.isNotEmpty) {
      for (final nota in entry.notaGroups) {
        buf.writeln('📋 *${nota.title}*');
        for (final item in nota.items) {
          buf.writeln('  • ${item.name}: ${formatRupiah(item.price)}');
        }
        buf.writeln('  Subtotal: ${formatRupiah(nota.subtotal)}\n');
      }
    }

    buf.writeln('💰 *Tagihan Masing-masing:*');
    for (final p in entry.participants) {
      buf.writeln('• ${p.name}: ${formatRupiah(p.amount)}');
    }
    buf.writeln();
    buf.writeln('📊 *Rincian:*');
    if (entry.subtotal > 0)
      buf.writeln('Subtotal: ${formatRupiah(entry.subtotal)}');
    if (entry.taxAmount > 0)
      buf.writeln('Pajak: ${formatRupiah(entry.taxAmount)}');
    if (entry.serviceAmount > 0)
      buf.writeln('Service: ${formatRupiah(entry.serviceAmount)}');
    buf.writeln('*Total: ${formatRupiah(entry.totalAmount)}*');
    buf.writeln('\nDibagi menggunakan Bagi 🤝');
    return buf.toString();
  }

  Future<void> _shareWhatsApp() async {
    final text = Uri.encodeComponent(_buildShareText());
    final url = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await SharePlus.instance.share(ShareParams(text: _buildShareText()));
    }
  }

  Future<void> _shareEmail() async {
    final subject = Uri.encodeComponent(entry.title);
    final body = Uri.encodeComponent(_buildShareText());
    final url = Uri.parse('mailto:?subject=$subject&body=$body');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      await SharePlus.instance.share(ShareParams(text: _buildShareText()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Image.asset('assets/branding/logo.png', height: 28),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // Title & Date
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, left: 4),
                  child: Text(
                    entry.formattedDate,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ),

                // ── Per Nota Cards ──
                if (entry.notaGroups.isNotEmpty)
                  ...entry.notaGroups.map((nota) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: AppTheme.cardDecoration,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.receipt_outlined,
                                    size: 16, color: Color(0xFF4169E1)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    nota.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4169E1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...nota.items.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textSecondary),
                                        ),
                                      ),
                                      Text(
                                        formatRupiah(item.price),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textPrimary),
                                      ),
                                    ],
                                  ),
                                )),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Subtotal Nota',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  formatRupiah(nota.subtotal),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),

                // ── Total Card ──
                Container(
                  decoration: AppTheme.cardDecoration,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (entry.subtotal > 0)
                        _SummaryRow('Subtotal', formatRupiah(entry.subtotal)),
                      if (entry.serviceAmount > 0) ...[
                        const SizedBox(height: 12),
                        _SummaryRow(
                            'Biaya Layanan', formatRupiah(entry.serviceAmount)),
                      ],
                      if (entry.taxAmount > 0) ...[
                        const SizedBox(height: 12),
                        _SummaryRow('Pajak', formatRupiah(entry.taxAmount)),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary),
                          ),
                          Text(
                            formatRupiah(entry.totalAmount),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Tagihan Per Orang ──
                if (entry.participants.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12, left: 4),
                    child: Text(
                      'TAGIHAN MASING-MASING',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Container(
                    decoration: AppTheme.cardDecoration,
                    child: Column(
                      children: entry.participants.asMap().entries.map((e) {
                        final p = e.value;
                        final isLast = e.key == entry.participants.length - 1;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              child: Row(
                                children: [
                                  // Avatar circle
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.avatarColors[
                                          p.colorIndex %
                                              AppTheme.avatarColors.length],
                                    ),
                                    child: Center(
                                      child: Text(
                                        p.name.isNotEmpty
                                            ? p.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatRupiah(p.amount),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child:
                                    Divider(height: 1, color: AppTheme.divider),
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Share Buttons ──
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(context).padding.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.scaffoldBg,
              border:
                  Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.whatsappGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _shareWhatsApp,
                    icon: const Icon(Icons.share_outlined, size: 20),
                    label: const Text(
                      'Bagikan ke WhatsApp',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _shareEmail,
                    icon: const Icon(Icons.mail_outline, size: 20),
                    label: const Text(
                      'Kirim via Email',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
        Text(value,
            style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
      ],
    );
  }
}
