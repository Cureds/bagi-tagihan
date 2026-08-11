// lib/screens/final_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/participant_avatar.dart';
import 'home_screen.dart';

class FinalSummaryScreen extends StatefulWidget {
  const FinalSummaryScreen({super.key});
  @override
  State<FinalSummaryScreen> createState() => _FinalSummaryScreenState();
}

class _FinalSummaryScreenState extends State<FinalSummaryScreen> {
  final Map<String, int> _editedAmounts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<SessionProvider>();
      if (provider.customAmounts.isNotEmpty) {
        setState(() {
          _editedAmounts.addAll(provider.customAmounts);
        });
      }
      provider.addListener(_onProviderChange);
      provider.saveActiveSession();
    });
  }

  void _onProviderChange() {
    if (!mounted) return;
    final provider = context.read<SessionProvider>();
    // Sync edited amounts dari device lain
    if (provider.customAmounts.isNotEmpty) {
      bool changed = false;
      for (final entry in provider.customAmounts.entries) {
        if (_editedAmounts[entry.key] != entry.value) {
          changed = true;
          break;
        }
      }
      if (changed) {
        setState(() {
          _editedAmounts.addAll(provider.customAmounts);
        });
      }
    } else if (_editedAmounts.isNotEmpty && provider.customAmounts.isEmpty) {
      // Provider di-reset (dari device lain), ikut reset lokal juga
      setState(() {
        _editedAmounts.clear();
      });
    }
  }

  @override
  void dispose() {
    try {
      context.read<SessionProvider>().removeListener(_onProviderChange);
    } catch (_) {}
    super.dispose();
  }

  int _getAmount(String pid, BillSummary s) =>
      _editedAmounts[pid] ?? s.perParticipant[pid] ?? 0;

  int _getTotal(BillSummary s, List<Participant> ps) {
    if (_editedAmounts.isEmpty) return s.totalAmount;
    return ps.fold(0, (sum, p) => sum + _getAmount(p.id, s));
  }

  void _editAmount(BuildContext context, Participant p, int current) {
    final ctrl = TextEditingController(text: current.toString());
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('Edit Tagihan ${p.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              content: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                      prefixText: 'Rp ', labelText: 'Jumlah')),
              actions: [
                TextButton(
                    onPressed: () {
                      setState(() {
                        _editedAmounts.remove(p.id);
                      });
                      Navigator.pop(ctx);
                      context
                          .read<SessionProvider>()
                          .setCustomAmounts(Map.from(_editedAmounts));
                    },
                    child: const Text('Reset')),
                TextButton(
                    onPressed: () {
                      setState(() {
                        _editedAmounts[p.id] =
                            int.tryParse(ctrl.text.trim()) ?? current;
                      });
                      Navigator.pop(ctx);
                      context
                          .read<SessionProvider>()
                          .setCustomAmounts(Map.from(_editedAmounts));
                    },
                    child: const Text('Simpan',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4169E1)))),
              ],
            ));
  }

  void _showPhotoPopup(
      BuildContext context, String imageUrl, String notaTitle) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF4169E1),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child:
                          Image.asset('assets/branding/logo.png', height: 22),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Text(notaTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 20)),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20)),
                child: Image.network(imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Icon(Icons.broken_image_outlined,
                            size: 64, color: Color(0xFFCCCCCC))),
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()))),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _buildShareText(SessionProvider prov) {
    final s = prov.calculateBill();
    final buf = StringBuffer('🧾 *Ringkasan Tagihan Bersama*\n\n');
    final byNota = prov.itemsByNota;
    if (byNota.length > 1) {
      for (final e in byNota.entries) {
        final t = e.value.fold<int>(0, (sum, i) => sum + i.priceInRupiah);
        buf.writeln('📋 *${e.key}*');
        for (final i in e.value)
          buf.writeln('  • ${i.name}: ${formatRupiah(i.priceInRupiah)}');
        final disc = prov.getDiscountForNota(e.key);
        if (disc > 0) buf.writeln('  Diskon: -${formatRupiah(disc)}');
        buf.writeln('  Subtotal: ${formatRupiah(t)}\n');
      }
    }
    buf.writeln('💰 *Tagihan Masing-masing:*');
    for (final p in prov.participants)
      buf.writeln('• ${p.name}: ${formatRupiah(_getAmount(p.id, s))}');
    buf.writeln('\n📊 Subtotal: ${formatRupiah(s.subtotal)}');
    if (s.serviceAmount > 0)
      buf.writeln('Service: ${formatRupiah(s.serviceAmount)}');
    if (s.taxAmount > 0) buf.writeln('Pajak: ${formatRupiah(s.taxAmount)}');
    if (s.discountAmount > 0)
      buf.writeln('Diskon: -${formatRupiah(s.discountAmount)}');
    buf.writeln('*Total: ${formatRupiah(_getTotal(s, prov.participants))}*');
    if (_editedAmounts.isNotEmpty) buf.writeln('_(beberapa diedit manual)_');
    buf.writeln('\nDibagi menggunakan Bagi 🤝');
    return buf.toString();
  }

  Future<void> _share(SessionProvider prov, bool whatsapp) async {
    await prov.saveActiveSession();
    final text = _buildShareText(prov);
    if (whatsapp) {
      final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    } else {
      final url = Uri.parse(
          'mailto:?subject=${Uri.encodeComponent("Ringkasan Tagihan")}&body=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        return;
      }
    }
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _finish(BuildContext context, SessionProvider prov) async {
    final ctrl = TextEditingController();
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Beri Nama Sesi',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Nama ini muncul di riwayat.',
                    style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        hintText: 'Contoh: Makan di Zenbu')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Lewati')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Simpan',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4169E1)))),
              ],
            ));
    if (!context.mounted) return;
    await prov.finishSession(ctrl.text,
        editedAmounts:
            _editedAmounts.isNotEmpty ? Map.from(_editedAmounts) : null);
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
    }
  }

  String _schemeLabel(TaxScheme s) {
    switch (s) {
      case TaxScheme.serviceBeforeTax:
        return 'Service sebelum pajak';
      case TaxScheme.serviceAfterTax:
        return 'Pajak sebelum service';
      case TaxScheme.taxOnly:
        return 'Pajak saja';
      case TaxScheme.none:
        return 'Tanpa pajak';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(builder: (context, prov, _) {
      final s = prov.calculateBill();
      final byNota = prov.itemsByNota;
      final total = _getTotal(s, prov.participants);

      return Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 18),
                onPressed: () => Navigator.pop(context)),
            title: Image.asset('assets/branding/logo.png', height: 28),
            centerTitle: true),
        body: Column(children: [
          Expanded(
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                const Padding(
                    padding: EdgeInsets.only(bottom: 16, left: 4),
                    child: Text('Ringkasan Akhir',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary))),

                // ── Per Nota Cards ──
                ...byNota.entries.map((entry) {
                  final notaTitle = entry.key;
                  final items = entry.value;
                  final notaTotal =
                      items.fold<int>(0, (sum, i) => sum + i.priceInRupiah);
                  final notaDisc = prov.getDiscountForNota(notaTitle);
                  final imageUrl = prov.getImageUrlForNota(notaTitle);
                  final hasImg = imageUrl.isNotEmpty;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: AppTheme.cardDecoration,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: Row(children: [
                                const Icon(Icons.receipt_outlined,
                                    size: 16, color: Color(0xFF4169E1)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(notaTitle,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF4169E1)))),
                              ])),
                          if (hasImg)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: GestureDetector(
                                onTap: () => _showPhotoPopup(
                                    context, imageUrl, notaTitle),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Stack(children: [
                                    Image.network(imageUrl,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                        loadingBuilder: (_, child, progress) =>
                                            progress == null
                                                ? child
                                                : const SizedBox(
                                                    height: 120,
                                                    child: Center(
                                                        child:
                                                            CircularProgressIndicator()))),
                                    Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.4),
                                                borderRadius:
                                                    BorderRadius.circular(6)),
                                            child: const Icon(Icons.zoom_in,
                                                color: Colors.white,
                                                size: 16))),
                                  ]),
                                ),
                              ),
                            ),
                          Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(children: [
                                ...items.map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                              child: Text(item.name,
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: AppTheme
                                                          .textSecondary))),
                                          Text(formatRupiah(item.priceInRupiah),
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppTheme.textPrimary)),
                                        ]))),
                                if (notaDisc > 0) ...[
                                  const Divider(height: 12),
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Row(children: [
                                          Icon(Icons.discount_outlined,
                                              size: 14,
                                              color: Color(0xFF27AE60)),
                                          SizedBox(width: 4),
                                          Text('Diskon',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF27AE60),
                                                  fontWeight: FontWeight.w600)),
                                        ]),
                                        Text('-${formatRupiah(notaDisc)}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF27AE60),
                                                fontWeight: FontWeight.w600)),
                                      ]),
                                ],
                                const Divider(height: 16),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Subtotal Nota',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text(formatRupiah(notaTotal - notaDisc),
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    ]),
                              ])),
                        ]),
                  );
                }),

                // ── Total Card ──
                Container(
                    decoration: AppTheme.cardDecoration,
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      _Row('Subtotal', formatRupiah(s.subtotal)),
                      if (s.serviceAmount > 0) ...[
                        const SizedBox(height: 12),
                        _Row(
                            'Biaya Layanan (${(prov.serviceRate * 100).toStringAsFixed(0)}%)',
                            formatRupiah(s.serviceAmount)),
                      ],
                      if (s.taxAmount > 0) ...[
                        const SizedBox(height: 12),
                        _Row('Pajak (${(s.taxRate * 100).toStringAsFixed(0)}%)',
                            formatRupiah(s.taxAmount)),
                      ],
                      if (s.discountAmount > 0) ...[
                        const SizedBox(height: 12),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(children: [
                                Icon(Icons.discount_outlined,
                                    size: 16, color: Color(0xFF27AE60)),
                                SizedBox(width: 6),
                                Text('Diskon',
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF27AE60))),
                              ]),
                              Text('-${formatRupiah(s.discountAmount)}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF27AE60),
                                      fontWeight: FontWeight.w600)),
                            ]),
                      ],
                      if (prov.taxScheme != TaxScheme.none) ...[
                        const SizedBox(height: 8),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_schemeLabel(prov.taxScheme),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF8E8E93),
                                    fontStyle: FontStyle.italic))),
                      ],
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1)),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                            Text(formatRupiah(total),
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5)),
                          ]),
                      if (_editedAmounts.isNotEmpty)
                        const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('* Beberapa diedit manual',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFFF9800),
                                    fontStyle: FontStyle.italic))),
                    ])),

                const SizedBox(height: 24),

                // ── Tagihan Per Orang ──
                Padding(
                    padding: const EdgeInsets.only(bottom: 12, left: 4),
                    child: Row(children: [
                      const Expanded(
                          child: Text('TAGIHAN MASING-MASING',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                  letterSpacing: 0.8))),
                      if (_editedAmounts.isNotEmpty)
                        GestureDetector(
                            onTap: () {
                              // Reset semua edited amounts — lokal dan semua device
                              setState(() {
                                _editedAmounts.clear();
                              });
                              context
                                  .read<SessionProvider>()
                                  .setCustomAmounts({});
                            },
                            child: const Text('Reset Semua',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFF3B30)))),
                    ])),

                Container(
                    decoration: AppTheme.cardDecoration,
                    child: Column(
                      children: prov.participants.asMap().entries.map((entry) {
                        final p = entry.value;
                        final amt = _getAmount(p.id, s);
                        final edited = _editedAmounts.containsKey(p.id);
                        final last = entry.key == prov.participants.length - 1;
                        return Column(children: [
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              child: Row(children: [
                                ParticipantAvatar(participant: p, size: 36),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(p.name,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textPrimary)),
                                      if (edited)
                                        const Text('diedit manual',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFFFF9800))),
                                    ])),
                                Text(formatRupiah(amt),
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: edited
                                            ? const Color(0xFFFF9800)
                                            : AppTheme.textPrimary)),
                                const SizedBox(width: 8),
                                GestureDetector(
                                    onTap: () => _editAmount(context, p, amt),
                                    child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                            color: AppTheme.primaryBlueLight,
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: const Icon(Icons.edit_outlined,
                                            size: 16,
                                            color: Color(0xFF4169E1)))),
                              ])),
                          if (!last)
                            const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Divider(height: 1)),
                        ]);
                      }).toList(),
                    )),
              ])),

          // ── Share Buttons ──
          Container(
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(context).padding.bottom + 20),
            decoration: const BoxDecoration(
                color: AppTheme.scaffoldBg,
                border: Border(
                    top: BorderSide(color: AppTheme.divider, width: 0.5))),
            child: Column(children: [
              SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.whatsappGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: () => _share(prov, true),
                      icon: const Icon(Icons.share_outlined, size: 20),
                      label: const Text('Bagikan ke WhatsApp',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)))),
              const SizedBox(height: 10),
              SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                      onPressed: () => _share(prov, false),
                      icon: const Icon(Icons.mail_outline, size: 20),
                      label: const Text('Kirim via Email',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)))),
              const SizedBox(height: 10),
              TextButton(
                  onPressed: () => _finish(context, prov),
                  child: const Text('Selesai & Simpan ke Riwayat',
                      style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w500))),
            ]),
          ),
        ]),
      );
    });
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style:
                const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
        Text(value,
            style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
      ]);
}
