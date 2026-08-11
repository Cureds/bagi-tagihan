// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import 'join_room_screen.dart';
import 'waiting_room_screen.dart';
import 'history_detail_screen.dart';
import 'final_summary_screen.dart';
import 'select_items_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// ── Catatan fix: WidgetsBindingObserver & didChangeAppLifecycleState
// dihapus. Cek pending session SEKARANG cuma jalan sekali saat HomeScreen
// pertama kali dibuat (cold start), bukan setiap kali app di-resume.
// Ini yang bikin popup "Lanjutkan Sesi?" muncul berulang setiap minimize/
// swipe notification — karena dulu dicek ulang terus dari storage yang
// datanya tidak pernah benar-benar terhapus.
class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingSession());
  }

  Future<void> _checkPendingSession() async {
    if (!mounted) return;
    final provider = context.read<SessionProvider>();
    if (provider.hasPendingSession &&
        provider.menuItems.isEmpty &&
        provider.roomCode == null) {
      _showRestoreDialog();
    }
  }

  /// Push full back stack: WaitingRoom → SelectItems → FinalSummary
  /// supaya semua screen bisa diakses setelah restore sesi.
  void _navigateToRestoredSession() {
    final navigator = Navigator.of(context);
    navigator
        .push(MaterialPageRoute(builder: (_) => const WaitingRoomScreen()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator
          .push(MaterialPageRoute(builder: (_) => const SelectItemsScreen()));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigator.push(
            MaterialPageRoute(builder: (_) => const FinalSummaryScreen()));
      });
    });
  }

  void _showRestoreDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.restore, color: Color(0xFF4169E1)),
          SizedBox(width: 10),
          Text('Lanjutkan Sesi?',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
            'Ada sesi bagi tagihan yang belum disimpan ke riwayat. Mau dilanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Nanti', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<SessionProvider>();
              final restored = await provider.restorePendingSession();
              if (restored) {
                // ── FIX: hapus data tersimpan setelah berhasil di-restore,
                // supaya tidak ke-detect lagi sebagai "pending" di kemudian hari ──
                await provider.clearPendingSession();
              }
              if (restored && mounted) {
                _navigateToRestoredSession();
              }
            },
            style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateRoomDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Buat Sesi Baru',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Masukkan nama kamu',
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Contoh: Daud'),
          ),
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
              child: const Text('Buat')),
        ],
      ),
    );
    if (confirmed == true &&
        nameController.text.trim().isNotEmpty &&
        context.mounted) {
      await context
          .read<SessionProvider>()
          .createRoom(nameController.text.trim());
      if (context.mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WaitingRoomScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Image.asset('assets/branding/logo.png', height: 32),
                  ),
                  const SizedBox(height: 32),
                  const Text('Selamat Datang!',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  const Text('Mulai atau gabung sesi bagi tagihan',
                      style: TextStyle(
                          fontSize: 15, color: AppTheme.textSecondary)),
                  const SizedBox(height: 32),

                  // Banner "Lanjutkan Sesi"
                  if (provider.hasPendingSession) ...[
                    GestureDetector(
                      onTap: () => _showRestoreDialog(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFC107)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.restore, color: Color(0xFF856404)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ada sesi yang belum selesai',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF856404))),
                                Text('Ketuk untuk melanjutkan',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF856404))),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Color(0xFF856404)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tombol Buat & Gabung
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateRoomDialog(context),
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('Buat Sesi Baru'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const JoinRoomScreen())),
                      icon: const Icon(Icons.login_outlined, size: 20),
                      label: const Text('Gabung Sesi'),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Riwayat
                  Row(children: [
                    const Text('Riwayat Tagihan',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const Spacer(),
                    if (provider.history.isNotEmpty)
                      Text('${provider.history.length} sesi',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary)),
                  ]),
                  const SizedBox(height: 16),

                  if (provider.history.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E5EA))),
                      child: const Column(children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48, color: Color(0xFFCCCCCC)),
                        SizedBox(height: 12),
                        Text('Belum ada riwayat tagihan',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary)),
                        SizedBox(height: 4),
                        Text('Sesi yang selesai akan muncul di sini',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.textSecondary)),
                      ]),
                    )
                  else
                    ...provider.history.map((entry) => _HistoryCard(
                          entry: entry,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      HistoryDetailScreen(entry: entry))),
                        )),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final dynamic entry;
  final VoidCallback onTap;
  const _HistoryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppTheme.primaryBlueLight,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.receipt_long,
                color: AppTheme.primaryBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(_formatDate(entry.date),
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text(_formatRupiah(entry.totalAmount),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ]),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatRupiah(int amount) {
    final s = amount.toString();
    final buf = StringBuffer('Rp ');
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
