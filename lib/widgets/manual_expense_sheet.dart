// lib/widgets/manual_expense_sheet.dart
// Bottom sheet untuk menambahkan pengeluaran manual.
// Muncul dari bawah layar ketika user menekan "Tambah Pengeluaran Manual".

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import 'participant_avatar.dart';

class ManualExpenseSheet extends StatefulWidget {
  const ManualExpenseSheet({super.key});

  // Cara memanggil bottom sheet ini dari layar lain:
  // ManualExpenseSheet.show(context);
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,  // Agar sheet bisa naik saat keyboard muncul
      backgroundColor: Colors.transparent,
      builder: (_) => const ManualExpenseSheet(),
    );
  }

  @override
  State<ManualExpenseSheet> createState() => _ManualExpenseSheetState();
}

class _ManualExpenseSheetState extends State<ManualExpenseSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _nameFocus = FocusNode();
  final _amountFocus = FocusNode();

  // ID peserta yang dipilih untuk menanggung biaya ini
  final Set<String> _selectedIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Otomatis pilih semua peserta saat sheet dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SessionProvider>();
      setState(() {
        _selectedIds.addAll(provider.participants.map((p) => p.id));
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _save() {
    // Validasi input
    final name = _nameController.text.trim();
    final amountText = _amountController.text.trim().replaceAll('.', '');
    final amount = int.tryParse(amountText);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nama pengeluaran')),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah yang valid')),
      );
      return;
    }

    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih siapa yang menanggung biaya ini')),
      );
      return;
    }

    setState(() => _isLoading = true);

    context.read<SessionProvider>().addManualExpense(
          description: name,
          amountInRupiah: amount,
          sharedByIds: _selectedIds.toList(),
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle bar ──
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header ──
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 22, color: Color(0xFF8E8E93)),
                ),
                const Expanded(
                  child: Text(
                    'Tambah Pengeluaran',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                const SizedBox(width: 22), // Spacer untuk balance
              ],
            ),
            const SizedBox(height: 24),

            // ── Field: Nama Pengeluaran ──
            const Text(
              'Nama Pengeluaran',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _amountFocus.requestFocus(),
              decoration: const InputDecoration(
                hintText: 'Contoh: Bensin, Tiket, dll',
              ),
              style: const TextStyle(
                fontSize: 17,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 16),

            // ── Field: Jumlah ──
            const Text(
              'Jumlah',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              focusNode: _amountFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: TextStyle(
                  fontSize: 17,
                  color: Color(0xFF1C1C1E),
                  fontWeight: FontWeight.w400,
                ),
                hintText: '0',
              ),
              style: const TextStyle(
                fontSize: 17,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 24),

            // ── Pilih Peserta ──
            const Text(
              'Siapa yang bayar?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: provider.participants.asMap().entries.map((entry) {
                final index = entry.key;
                final participant = entry.value;
                final isSelected = _selectedIds.contains(participant.id);

                return Padding(
                  padding: EdgeInsets.only(right: index < provider.participants.length - 1 ? 12 : 0),
                  child: ParticipantAvatar(
                    participant: participant,
                    size: 52,
                    isSelected: isSelected,
                    showName: true,
                    onTap: () {
                      setState(() {
                        if (_selectedIds.contains(participant.id)) {
                          _selectedIds.remove(participant.id);
                        } else {
                          _selectedIds.add(participant.id);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // ── Tombol Simpan ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan Pengeluaran'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
