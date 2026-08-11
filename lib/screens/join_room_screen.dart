// lib/screens/join_room_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import 'waiting_room_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _codeFocus = FocusNode();
  final _nameFocus = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _codeFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _scanQR() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QRScannerScreen()),
    );
    if (code != null && code.isNotEmpty && mounted) {
      _codeController.text = code.toUpperCase();
      _nameFocus.requestFocus();
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();

    if (code.isEmpty) {
      _showError('Masukkan kode ruangan terlebih dahulu');
      return;
    }
    if (code.length < 4) {
      _showError('Kode ruangan minimal 4 karakter');
      return;
    }
    if (name.isEmpty) {
      _showError('Masukkan nama kamu terlebih dahulu');
      return;
    }

    setState(() => _isLoading = true);
    final success = await context.read<SessionProvider>().joinRoom(code, name);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const WaitingRoomScreen()));
    } else {
      _showError('Kode ruangan "$code" tidak ditemukan. Coba lagi.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFF1C1C1E)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
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
                const Text('Gabung Ruangan',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5)),
                const SizedBox(height: 6),
                const Text('Scan QR atau masukkan kode untuk bergabung',
                    style:
                        TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                      onPressed: _scanQR,
                      icon: const Icon(Icons.qr_code_scanner, size: 22),
                      label: const Text('Scan QR Code')),
                ),
                const SizedBox(height: 16),
                const Row(children: [
                  Expanded(child: Divider(color: AppTheme.divider)),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('atau',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13))),
                  Expanded(child: Divider(color: AppTheme.divider)),
                ]),
                const SizedBox(height: 16),
                Container(
                  decoration: AppTheme.cardDecoration,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kode Ruangan',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.3)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _codeController,
                        focusNode: _codeFocus,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        maxLength: 5,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]')),
                          UpperCaseTextFormatter()
                        ],
                        onSubmitted: (_) => _nameFocus.requestFocus(),
                        decoration: const InputDecoration(
                            hintText: 'Masukkan kode',
                            counterText: '',
                            hintStyle: TextStyle(
                                fontSize: 20,
                                color: AppTheme.textHint,
                                fontWeight: FontWeight.w500)),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: 3),
                      ),
                      const SizedBox(height: 20),
                      const Text('Nama Kamu',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.3)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _joinRoom(),
                        decoration: const InputDecoration(
                            hintText: 'Masukkan nama kamu'),
                        style: const TextStyle(
                            fontSize: 17, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _joinRoom,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Text('Gabung Sesi'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
        text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}

class _QRScannerScreen extends StatefulWidget {
  const _QRScannerScreen();
  @override
  State<_QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<_QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _scanned = false;

  @override
  void reassemble() {
    super.reassemble();
    controller?.pauseCamera();
    controller?.resumeCamera();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (_scanned) return;
      if (scanData.code != null && scanData.code!.isNotEmpty) {
        _scanned = true;
        controller.pauseCamera();
        Navigator.pop(context, scanData.code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title:
            const Text('Scan QR Code', style: TextStyle(color: Colors.white)),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(children: [
        QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
                borderColor: AppTheme.primaryBlue,
                borderRadius: 20,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 260)),
        const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
                child: Text('Arahkan kamera ke QR code',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)))),
      ]),
    );
  }
}
