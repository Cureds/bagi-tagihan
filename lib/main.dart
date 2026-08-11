// lib/main.dart
// Entry point utama aplikasi Flutter.
// File ini menginisialisasi Provider dan menjalankan HomeScreen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/session_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  // Pastikan Flutter sudah diinisialisasi sebelum memanggil fungsi async
  WidgetsFlutterBinding.ensureInitialized();

  // Kunci orientasi layar ke portrait saja (vertikal)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set warna status bar (jam, baterai, dll) menjadi gelap (teks hitam)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  runApp(const BagiTagihanApp());
}

class BagiTagihanApp extends StatelessWidget {
  const BagiTagihanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // Daftarkan semua Provider di sini
      providers: [
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      child: MaterialApp(
        title: 'Bagi Tagihan',
        debugShowCheckedModeBanner: false, // Sembunyikan label "DEBUG"
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
