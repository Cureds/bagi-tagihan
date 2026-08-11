// lib/screens/waiting_room_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/participant_avatar.dart';
import '../widgets/manual_expense_sheet.dart';
import 'select_items_screen.dart';

class WaitingRoomScreen extends StatelessWidget {
  const WaitingRoomScreen({super.key});

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Kode disalin!'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: const Color(0xFF1C1C1E),
    ));
  }

  Future<void> _showCameraWarning(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.tips_and_updates_outlined,
              color: Color(0xFF4169E1), size: 24),
          SizedBox(width: 10),
          Text('Tips Foto Struk',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ]),
        content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TipRow(
                  icon: Icons.wb_sunny_outlined,
                  text: 'Pastikan pencahayaan cukup'),
              SizedBox(height: 10),
              _TipRow(
                  icon: Icons.crop_free,
                  text: 'Seluruh struk terlihat dalam frame'),
              SizedBox(height: 10),
              _TipRow(
                  icon: Icons.straighten,
                  text: 'Letakkan struk di permukaan rata'),
              SizedBox(height: 10),
              _TipRow(icon: Icons.block, text: 'Hindari bayangan & lipatan'),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Lanjut Foto')),
        ],
      ),
    );
    if (proceed == true && context.mounted) _scanReceipt(context);
  }

  Future<void> _scanReceipt(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppTheme.primaryBlueLight,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt_outlined,
                    color: AppTheme.primaryBlue)),
            title: const Text('Ambil Foto Sekarang',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Gunakan kamera perangkat'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppTheme.primaryBlueLight,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_outlined,
                    color: AppTheme.primaryBlue)),
            title: const Text('Pilih dari Galeri',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Pilih foto yang sudah ada'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );

    if (source == null || !context.mounted) return;
    final image = await picker.pickImage(
        source: source, imageQuality: 90, maxWidth: 1920);
    if (image == null || !context.mounted) return;

    final provider = context.read<SessionProvider>();
    provider.setScanning(true);

    try {
      final result = await ApiService.scanReceipt(image.path);
      if (!context.mounted) return;

      // Ask for nota title
      final titleController = TextEditingController();
      final scannerName = provider.myName;
      final suggestedTitle = result.restaurantName.isNotEmpty
          ? '${result.restaurantName} - $scannerName'
          : 'Nota - $scannerName';
      titleController.text = suggestedTitle;

      final notaTitle = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nama Nota',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Beri nama untuk nota ini',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
                controller: titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    hintText: 'Contoh: Moi Garden - Daud')),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(
                    ctx,
                    titleController.text.trim().isEmpty
                        ? suggestedTitle
                        : titleController.text.trim()),
                child: const Text('Simpan',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4169E1)))),
          ],
        ),
      );

      provider.setScannedItems(
        result.items,
        scheme: result.taxScheme,
        taxRate: result.taxRate,
        serviceRate: result.serviceRate,
        notaTitle: notaTitle ?? suggestedTitle,
        imageUrl: result.imageUrl,
        discountAmount: result.discountAmount,
      );
    } catch (e) {
      provider.setScanning(false, error: e.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal scan: $e')));
        return;
      }
    }

    if (context.mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SelectItemsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, provider, _) {
        final totalItems =
            provider.menuItems.length + provider.manualExpenses.length;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          appBar: AppBar(
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 18),
                onPressed: () => _confirmLeave(context, provider)),
            title: Image.asset('assets/branding/logo.png', height: 28),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text('Ruang Tunggu',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      const Text('Undang teman untuk bergabung',
                          style: TextStyle(
                              fontSize: 15, color: AppTheme.textSecondary)),
                      const SizedBox(height: 24),

                      // ── Kode + QR ──
                      Container(
                        decoration: AppTheme.cardDecoration,
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          Row(children: [
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Kode Ruangan',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 6),
                                  Text(provider.roomCode ?? '-----',
                                      style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textPrimary,
                                          letterSpacing: 4)),
                                ]),
                            const Spacer(),
                            GestureDetector(
                                onTap: () =>
                                    _copyCode(context, provider.roomCode ?? ''),
                                child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                        color: AppTheme.primaryBlueLight,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: const Icon(Icons.copy_outlined,
                                        color: AppTheme.primaryBlue,
                                        size: 20))),
                          ]),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE5E5EA))),
                            child: QrImageView(
                              data: provider.roomCode ?? '',
                              version: QrVersions.auto,
                              size: 160,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF4169E1)),
                              dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF1C1C1E)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Scan QR untuk bergabung',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF8E8E93))),
                        ]),
                      ),
                      const SizedBox(height: 28),

                      // ── Peserta ──
                      Text('Peserta (${provider.participants.length})',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: provider.participants.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 16),
                          itemBuilder: (_, i) => ParticipantAvatar(
                              participant: provider.participants[i],
                              size: 52,
                              showName: true),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Thumbnail nota yang sudah discan ──
                      if (provider.notaGroups.isNotEmpty) ...[
                        const Text('Nota Terscan',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: provider.notaGroups.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) {
                              final nota = provider.notaGroups[i];
                              final fullUrl =
                                  ApiService.getImageUrl(nota.imageUrl);
                              return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: fullUrl.isNotEmpty
                                          ? Image.network(fullUrl,
                                              width: 72,
                                              height: 72,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _placeholder())
                                          : _placeholder(),
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                        width: 72,
                                        child: Text(nota.title,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textSecondary),
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center)),
                                  ]);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (provider.isScanning)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: AppTheme.primaryBlueLight,
                              borderRadius: BorderRadius.circular(14)),
                          child: const Row(children: [
                            SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppTheme.primaryBlue)),
                            SizedBox(width: 12),
                            Text('Memproses struk dengan AI...',
                                style: TextStyle(
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w500)),
                          ]),
                        ),

                      SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                              onPressed: provider.isScanning
                                  ? null
                                  : () => _showCameraWarning(context),
                              icon: const Icon(Icons.camera_alt_outlined,
                                  size: 20),
                              label: const Text('Pindai Struk'))),
                      const SizedBox(height: 12),
                      SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                              onPressed: () => ManualExpenseSheet.show(context),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              label: const Text('Tambah Pengeluaran Manual'))),
                      const SizedBox(height: 12),
                      if (totalItems > 0)
                        SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const SelectItemsScreen())),
                                icon: const Icon(Icons.list_alt_outlined,
                                    size: 20),
                                label: Text('Lihat Menu ($totalItems item)'))),
                      const SizedBox(height: 32),
                    ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(10)),
        child:
            const Icon(Icons.receipt_long, size: 30, color: Color(0xFFCCCCCC)),
      );

  void _confirmLeave(BuildContext context, SessionProvider provider) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Keluar dari Sesi?',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              content: const Text('Data sesi ini akan hilang.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tetap')),
                TextButton(
                    onPressed: () {
                      provider.leaveSession();
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    child: const Text('Keluar',
                        style: TextStyle(color: Color(0xFFFF3B30)))),
              ],
            ));
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 20, color: const Color(0xFF4169E1)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontSize: 14, color: Color(0xFF1C1C1E)))),
      ]);
}
