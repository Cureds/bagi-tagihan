// lib/screens/select_items_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/participant_avatar.dart';
import 'final_summary_screen.dart';

class SelectItemsScreen extends StatefulWidget {
  const SelectItemsScreen({super.key});
  @override
  State<SelectItemsScreen> createState() => _SelectItemsScreenState();
}

class _SelectItemsScreenState extends State<SelectItemsScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  String _getTaxSchemeText(TaxScheme scheme) {
    switch (scheme) {
      case TaxScheme.serviceBeforeTax:
        return 'Biaya layanan diterapkan sebelum pajak';
      case TaxScheme.serviceAfterTax:
        return 'Pajak diterapkan sebelum biaya layanan';
      case TaxScheme.taxOnly:
        return 'Hanya pajak (tanpa biaya layanan)';
      case TaxScheme.none:
        return 'Tanpa pajak dan biaya layanan';
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelectItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _confirmDeleteSelected(SessionProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Item Terpilih?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('${_selectedIds.length} item akan dihapus dari daftar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
              onPressed: () {
                for (final id in _selectedIds.toList()) {
                  provider.deleteItem(id);
                }
                Navigator.pop(ctx);
                setState(() {
                  _selectionMode = false;
                  _selectedIds.clear();
                });
              },
              child: const Text('Hapus',
                  style: TextStyle(color: Color(0xFFFF3B30)))),
        ],
      ),
    );
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

  // ── Popup peserta — SEKARANG SCROLLABLE untuk 10+ peserta ──────
  void _showParticipantsPopup(
      BuildContext context, List<Participant> participants) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              constraints: const BoxConstraints(maxHeight: 480),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10))
                  ]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Peserta Sesi (${participants.length})',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                        decoration: TextDecoration.none)),
                const SizedBox(height: 16),
                // ── Bagian yang bisa di-scroll kalau peserta banyak ──
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: participants
                          .map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(children: [
                                  ParticipantAvatar(participant: p, size: 44),
                                  const SizedBox(width: 14),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(p.name,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1C1C1E),
                                                decoration:
                                                    TextDecoration.none)),
                                        if (p.isHost)
                                          const Text('Host',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF4169E1),
                                                  fontWeight: FontWeight.w500,
                                                  decoration:
                                                      TextDecoration.none)),
                                      ])),
                                ]),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('Tutup'))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  void _showEditDialog(
      BuildContext context, SessionProvider provider, MenuItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final priceCtrl =
        TextEditingController(text: item.priceInRupiah.toString());
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Edit Item',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nama Item')),
                const SizedBox(height: 12),
                TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Harga', prefixText: 'Rp ')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal')),
                TextButton(
                    onPressed: () {
                      final n = nameCtrl.text.trim();
                      final p = int.tryParse(priceCtrl.text.trim()) ??
                          item.priceInRupiah;
                      if (n.isNotEmpty) provider.editItem(item.id, n, p);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Simpan',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4169E1)))),
              ],
            ));
  }

  void _confirmDeleteItem(
      BuildContext context, SessionProvider provider, MenuItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Item?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Hapus "${item.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                provider.deleteItem(item.id);
              },
              child: const Text('Hapus',
                  style: TextStyle(color: Color(0xFFFF3B30)))),
        ],
      ),
    );
  }

  // ── Bottom sheet Edit/Hapus muncul setelah TAHAN (long press) ──
  void _showItemActionsSheet(
      BuildContext context, SessionProvider provider, MenuItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(item.name,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppTheme.primaryBlueLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_outlined,
                      color: Color(0xFF4169E1))),
              title: const Text('Edit Item',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _showEditDialog(context, provider, item);
              },
            ),
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFEEEE),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline,
                      color: Color(0xFFFF3B30))),
              title: const Text('Hapus Item',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFFFF3B30))),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteItem(context, provider, item);
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _showEditExpenseDialog(
      BuildContext context, SessionProvider provider, ManualExpense expense) {
    final nameCtrl = TextEditingController(text: expense.description);
    final amtCtrl =
        TextEditingController(text: expense.amountInRupiah.toString());
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Edit Pengeluaran',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nama')),
                const SizedBox(height: 12),
                TextField(
                    controller: amtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Jumlah', prefixText: 'Rp ')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal')),
                TextButton(
                    onPressed: () {
                      final n = nameCtrl.text.trim();
                      final a = int.tryParse(amtCtrl.text.trim()) ??
                          expense.amountInRupiah;
                      if (n.isNotEmpty) {
                        provider.editManualExpense(expense.id, n, a);
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('Simpan',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4169E1)))),
              ],
            ));
  }

  void _confirmDeleteExpense(
      BuildContext context, SessionProvider provider, ManualExpense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('Hapus?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Hapus "${expense.description}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                provider.deleteManualExpense(expense.id);
              },
              child: const Text('Hapus',
                  style: TextStyle(color: Color(0xFFFF3B30)))),
        ],
      ),
    );
  }

  // ── Bottom sheet Edit/Hapus untuk pengeluaran manual (tahan) ────
  void _showExpenseActionsSheet(
      BuildContext context, SessionProvider provider, ManualExpense expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(expense.description,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppTheme.primaryBlueLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_outlined,
                      color: Color(0xFF4169E1))),
              title: const Text('Edit Pengeluaran',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _showEditExpenseDialog(context, provider, expense);
              },
            ),
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFEEEE),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline,
                      color: Color(0xFFFF3B30))),
              title: const Text('Hapus Pengeluaran',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFFFF3B30))),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteExpense(context, provider, expense);
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _buildSharedAvatars(List<String> ids, List<Participant> all) {
    final shared = all.where((p) => ids.contains(p.id)).toList();
    if (shared.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ParticipantAvatar(participant: shared.first, size: 22),
      if (shared.length > 1) ...[
        const SizedBox(width: 4),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: const Color(0xFF4169E1),
                borderRadius: BorderRadius.circular(8)),
            child: Text('+${shared.length - 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700))),
      ],
    ]);
  }

  // ── Sub-header kecil untuk Makanan / Minuman / Lainnya ──────────
  Widget _categoryLabel(String text, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6, left: 2),
        child: Row(children: [
          Icon(icon, size: 14, color: const Color(0xFF8E8E93)),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8E8E93),
                  letterSpacing: 0.6)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, provider, _) {
        final itemsByNota = provider.itemsByNota;
        final host = provider.hostParticipant;
        final otherCount = provider.participants.length - 1;
        final hasAnyMenuItem = provider.menuItems.isNotEmpty;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          appBar: AppBar(
            leading: IconButton(
                icon: Icon(_selectionMode ? Icons.close : Icons.arrow_back_ios,
                    size: _selectionMode ? 24 : 18),
                onPressed: () => _selectionMode
                    ? _toggleSelectionMode()
                    : Navigator.pop(context)),
            title: _selectionMode
                ? Text('${_selectedIds.length} dipilih',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary))
                : Image.asset('assets/branding/logo.png', height: 28),
            centerTitle: !_selectionMode,
            actions: [
              if (hasAnyMenuItem)
                TextButton(
                  onPressed: _toggleSelectionMode,
                  child: Text(_selectionMode ? 'Batal' : 'Pilih',
                      style: const TextStyle(
                          color: Color(0xFF4169E1),
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    if (!_selectionMode) ...[
                      const Text('Pilih Item',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      const Text('Ketuk avatar untuk memilih siapa yang pesan',
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      if (host != null)
                        GestureDetector(
                          onTap: () => _showParticipantsPopup(
                              context, provider.participants),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                                color: AppTheme.primaryBlueLight,
                                borderRadius: BorderRadius.circular(14)),
                            child: Row(children: [
                              ParticipantAvatar(participant: host, size: 36),
                              if (otherCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF4169E1),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Text('+$otherCount',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700))),
                              ],
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(
                                      '${provider.participants.length} peserta',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF4169E1)))),
                              const Icon(Icons.chevron_right,
                                  color: Color(0xFF4169E1), size: 20),
                            ]),
                          ),
                        ),
                      if (provider.taxScheme != TaxScheme.none)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFD6E0FF))),
                          child: Row(children: [
                            const Icon(Icons.info_outline,
                                size: 18, color: Color(0xFF4169E1)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const Text('Terdeteksi AI',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF4169E1))),
                                  Text(_getTaxSchemeText(provider.taxScheme),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280))),
                                  Text(
                                      'Pajak: ${(provider.taxRate * 100).toStringAsFixed(0)}%'
                                      '${provider.serviceRate > 0 ? " • Service: ${(provider.serviceRate * 100).toStringAsFixed(0)}%" : ""}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280))),
                                ])),
                          ]),
                        ),
                      if (provider.totalDiscountAmount > 0)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: const Color(0xFFEFFAF3),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFB7EAC9))),
                          child: Row(children: [
                            const Icon(Icons.discount_outlined,
                                size: 18, color: Color(0xFF27AE60)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const Text('Diskon Terdeteksi',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF27AE60))),
                                  Text(
                                      'Total diskon: ${formatRupiah(provider.totalDiscountAmount)}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF27AE60))),
                                ])),
                          ]),
                        ),
                    ] else
                      const SizedBox(height: 12),
                    ...itemsByNota.entries.map((entry) {
                      final imgUrl = provider.getImageUrlForNota(entry.key);
                      final hasImg = imgUrl.isNotEmpty;

                      // ── Pisahkan item per nota jadi Makanan / Minuman / Lainnya ──
                      final makanan = entry.value
                          .where((i) => i.category == 'makanan')
                          .toList();
                      final minuman = entry.value
                          .where((i) => i.category == 'minuman')
                          .toList();
                      final lainnya = entry.value
                          .where((i) =>
                              i.category != 'makanan' &&
                              i.category != 'minuman')
                          .toList();

                      Widget buildCard(MenuItem item) => _MenuItemCard(
                            key: ValueKey(item.id),
                            item: item,
                            participants: provider.participants,
                            selectionMode: _selectionMode,
                            isSelected: _selectedIds.contains(item.id),
                            onToggleAssign: (pid) =>
                                provider.toggleItemAssignment(item.id, pid),
                            onToggleSelect: () => _toggleSelectItem(item.id),
                            onLongPress: () =>
                                _showItemActionsSheet(context, provider, item),
                          );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 8),
                            child: GestureDetector(
                              onTap: hasImg
                                  ? () => _showPhotoPopup(
                                      context, imgUrl, entry.key)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFE5E5EA)),
                                ),
                                child: Row(children: [
                                  hasImg
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Image.network(imgUrl,
                                              width: 36,
                                              height: 36,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                      Icons.receipt_outlined,
                                                      size: 20,
                                                      color:
                                                          Color(0xFF4169E1))))
                                      : const Icon(Icons.receipt_outlined,
                                          size: 16, color: Color(0xFF4169E1)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(entry.key,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF4169E1)))),
                                  Text('${entry.value.length} item',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8E8E93))),
                                  if (hasImg)
                                    const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.zoom_in,
                                            size: 16,
                                            color: Color(0xFF8E8E93))),
                                ]),
                              ),
                            ),
                          ),
                          if (makanan.isNotEmpty) ...[
                            _categoryLabel(
                                'MAKANAN', Icons.restaurant_outlined),
                            ...makanan.map(buildCard),
                          ],
                          if (minuman.isNotEmpty) ...[
                            _categoryLabel(
                                'MINUMAN', Icons.local_cafe_outlined),
                            ...minuman.map(buildCard),
                          ],
                          if (lainnya.isNotEmpty) ...[
                            if (makanan.isNotEmpty || minuman.isNotEmpty)
                              _categoryLabel('LAINNYA', Icons.more_horiz),
                            ...lainnya.map(buildCard),
                          ],
                        ],
                      );
                    }),
                    if (!_selectionMode &&
                        provider.manualExpenses.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('PENGELUARAN MANUAL',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 10),
                      ...provider.manualExpenses
                          .map((expense) => GestureDetector(
                                onLongPress: () => _showExpenseActionsSheet(
                                    context, provider, expense),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                  decoration: AppTheme.cardDecoration,
                                  child: Row(children: [
                                    Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFFFF3E0),
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: const Icon(Icons.receipt_long,
                                            size: 18,
                                            color: Color(0xFFFF9800))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(expense.description,
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textPrimary)),
                                          const SizedBox(height: 4),
                                          _buildSharedAvatars(
                                              expense.sharedByIds,
                                              provider.participants),
                                        ])),
                                    Text(formatRupiah(expense.amountInRupiah),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary)),
                                  ]),
                                ),
                              )),
                    ],
                    if (provider.menuItems.isEmpty &&
                        provider.manualExpenses.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                              child: Text('Belum ada item.',
                                  style: TextStyle(
                                      color: Color(0xFF8E8E93),
                                      fontSize: 14)))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: _selectionMode
                    ? SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _selectedIds.isEmpty
                              ? null
                              : () => _confirmDeleteSelected(provider),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF3B30)),
                          child: Text(_selectedIds.isEmpty
                              ? 'Pilih item untuk dihapus'
                              : 'Hapus (${_selectedIds.length}) Item'),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                            onPressed: (provider.menuItems.isEmpty &&
                                    provider.manualExpenses.isEmpty)
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const FinalSummaryScreen())),
                            child: const Text('Lihat Hasil'))),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final List<Participant> participants;
  final bool selectionMode;
  final bool isSelected;
  final Function(String) onToggleAssign;
  final VoidCallback onToggleSelect;
  final VoidCallback onLongPress;

  const _MenuItemCard({
    super.key,
    required this.item,
    required this.participants,
    required this.selectionMode,
    required this.isSelected,
    required this.onToggleAssign,
    required this.onToggleSelect,
    required this.onLongPress,
  });

  void _showAssignPopup(BuildContext context) {
    final selectedIds = Set<String>.from(
      participants.where((p) => item.isAssignedTo(p.id)).map((p) => p.id),
    );

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: StatefulBuilder(
              builder: (ctx2, setState) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                constraints: const BoxConstraints(maxHeight: 480),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 10))
                    ]),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Siapa yang pesan\n"${item.name}"?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                          decoration: TextDecoration.none)),
                  const SizedBox(height: 16),
                  // ── Scrollable juga untuk 10+ peserta ──
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: participants.map((p) {
                          final assigned = selectedIds.contains(p.id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () {
                                onToggleAssign(p.id);
                                setState(() {
                                  if (selectedIds.contains(p.id)) {
                                    selectedIds.remove(p.id);
                                  } else {
                                    selectedIds.add(p.id);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: assigned
                                      ? const Color(0xFFEEF2FF)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: assigned
                                          ? const Color(0xFF4169E1)
                                          : const Color(0xFFE5E5EA),
                                      width: assigned ? 2 : 1),
                                ),
                                child: Row(children: [
                                  ParticipantAvatar(participant: p, size: 36),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(p.name,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1C1C1E),
                                              decoration:
                                                  TextDecoration.none))),
                                  if (assigned)
                                    const Icon(Icons.check_circle,
                                        color: Color(0xFF4169E1), size: 22),
                                ]),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: const Text('Selesai'))),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assigned =
        participants.where((p) => item.isAssignedTo(p.id)).toList();
    final firstAssigned = assigned.isNotEmpty ? assigned.first : null;
    final overflow = assigned.length - 1;

    return GestureDetector(
      onLongPress: selectionMode ? null : onLongPress,
      onTap: selectionMode ? onToggleSelect : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF4169E1)
                  : const Color(0xFFE5E5EA),
              width: isSelected ? 2 : 1),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Row(children: [
          if (selectionMode) ...[
            Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected
                    ? const Color(0xFF4169E1)
                    : const Color(0xFFCCCCCC),
                size: 24),
            const SizedBox(width: 12),
          ],
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 3),
                Text(formatRupiah(item.priceInRupiah),
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ])),
          const SizedBox(width: 8),
          if (!selectionMode)
            GestureDetector(
              onTap: () => _showAssignPopup(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: firstAssigned != null
                      ? const Color(0xFFEEF2FF)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: firstAssigned != null
                          ? const Color(0xFF4169E1)
                          : const Color(0xFFE0E0E0)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  firstAssigned != null
                      ? ParticipantAvatar(participant: firstAssigned, size: 28)
                      : const Icon(Icons.person_add_outlined,
                          size: 18, color: Color(0xFF8E8E93)),
                  if (overflow > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF4169E1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('+$overflow',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))),
                  ],
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more,
                      size: 16,
                      color: firstAssigned != null
                          ? const Color(0xFF4169E1)
                          : const Color(0xFF8E8E93)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
