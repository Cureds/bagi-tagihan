// lib/services/api_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../models/models.dart';

class ScanResult {
  final List<MenuItem> items;
  final TaxScheme taxScheme;
  final double taxRate;
  final double serviceRate;
  final int taxAmount;
  final int serviceAmount;
  final int discountAmount;
  final int totalOnReceipt;
  final String restaurantName;
  final String imageUrl;

  ScanResult({
    required this.items,
    required this.taxScheme,
    required this.taxRate,
    required this.serviceRate,
    required this.taxAmount,
    required this.serviceAmount,
    required this.discountAmount,
    required this.totalOnReceipt,
    required this.restaurantName,
    required this.imageUrl,
  });
}

class ApiService {
  static String baseUrl = 'https://pipluptine-bagi-tagihan-api.hf.space';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  static TaxScheme _parseTaxScheme(String str) {
    switch (str) {
      case 'service_before_tax':
        return TaxScheme.serviceBeforeTax;
      case 'service_after_tax':
        return TaxScheme.serviceAfterTax;
      case 'tax_only':
        return TaxScheme.taxOnly;
      default:
        return TaxScheme.none;
    }
  }

  static Future<ScanResult> scanReceipt(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/api/scan-receipt'));
    request.files.add(http.MultipartFile.fromBytes('image', bytes,
        filename: 'receipt.jpg', contentType: MediaType('image', 'jpeg')));
    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200)
      throw Exception('Scan gagal: ${response.statusCode}');
    final data = jsonDecode(response.body);

    // ── Gunakan index untuk pastikan ID unik (hindari collision) ──
    // dan SERTAKAN category (makanan/minuman/lainnya) dari hasil AI
    final itemsData = data['items'] as List;
    final items = itemsData.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      return MenuItem(
        id: '${generateId()}_$idx',
        name: item['name'] as String,
        priceInRupiah: item['price_in_rupiah'] as int,
        category: item['category'] as String? ?? 'lainnya',
      );
    }).toList();

    return ScanResult(
      items: items,
      taxScheme: _parseTaxScheme(data['tax_scheme'] as String? ?? 'none'),
      taxRate: (data['tax_rate'] as num?)?.toDouble() ?? 0.0,
      serviceRate: (data['service_rate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: data['tax_amount'] as int? ?? 0,
      serviceAmount: data['service_amount'] as int? ?? 0,
      discountAmount: data['discount_amount'] as int? ?? 0,
      totalOnReceipt: data['total_on_receipt'] as int? ?? 0,
      restaurantName: data['restaurant_name'] as String? ?? '',
      imageUrl: data['image_url'] as String? ?? '',
    );
  }

  static Future<void> createRoom(
      String code, String hostId, String hostName) async {
    await http.post(Uri.parse('$baseUrl/api/rooms'),
        headers: _headers,
        body: jsonEncode(
            {'room_code': code, 'host_id': hostId, 'host_name': hostName}));
  }

  static Future<Map<String, dynamic>> getRoomState(String roomCode) async {
    final response = await http.get(Uri.parse('$baseUrl/api/rooms/$roomCode'),
        headers: _headers);
    if (response.statusCode != 200) throw Exception('Room tidak ditemukan');
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> joinRoom(
      String code, String participantId, String name) async {
    final response = await http.post(Uri.parse('$baseUrl/api/rooms/$code/join'),
        headers: _headers,
        body: jsonEncode({'participant_id': participantId, 'name': name}));
    if (response.statusCode == 404) throw Exception('Kode tidak ditemukan');
    return jsonDecode(response.body);
  }

  static Future<void> leaveRoom(String roomCode, String participantId) async {
    try {
      await http.post(Uri.parse('$baseUrl/api/rooms/$roomCode/leave'),
          headers: _headers,
          body: jsonEncode({'participant_id': participantId}));
    } catch (e) {
      debugPrint('Leave room error: $e');
    }
  }

  static Future<void> syncItems(
    String roomCode,
    List<MenuItem> items,
    List<NotaGroupData> notaGroups, {
    TaxScheme taxScheme = TaxScheme.none,
    double taxRate = 0.10,
    double serviceRate = 0.05,
    int discountAmount = 0,
  }) async {
    String schemeStr;
    switch (taxScheme) {
      case TaxScheme.serviceBeforeTax:
        schemeStr = 'service_before_tax';
        break;
      case TaxScheme.serviceAfterTax:
        schemeStr = 'service_after_tax';
        break;
      case TaxScheme.taxOnly:
        schemeStr = 'tax_only';
        break;
      default:
        schemeStr = 'none';
    }
    await http.post(Uri.parse('$baseUrl/api/rooms/$roomCode/sync-items'),
        headers: _headers,
        body: jsonEncode({
          'items': items
              .map((i) => {
                    'id': i.id,
                    'name': i.name,
                    'price_in_rupiah': i.priceInRupiah,
                    'category': i.category,
                    'assigned_participant_ids': i.assignedParticipantIds,
                  })
              .toList(),
          'nota_groups': notaGroups
              .map((g) => {
                    'id': g.id,
                    'title': g.title,
                    'item_ids': g.itemIds,
                    'image_url': g.imageUrl,
                    'discount_amount': g.discountAmount,
                  })
              .toList(),
          'tax_scheme': schemeStr,
          'tax_rate': taxRate,
          'service_rate': serviceRate,
          'discount_amount': discountAmount,
        }));
  }

  static Future<void> syncManualExpenses(
      String roomCode, List<ManualExpense> expenses) async {
    try {
      await http.post(Uri.parse('$baseUrl/api/rooms/$roomCode/sync-expenses'),
          headers: _headers,
          body: jsonEncode({
            'expenses': expenses
                .map((e) => {
                      'id': e.id,
                      'description': e.description,
                      'amount_in_rupiah': e.amountInRupiah,
                      'shared_by_ids': e.sharedByIds,
                    })
                .toList(),
          }));
    } catch (e) {
      debugPrint('syncManualExpenses error: $e');
    }
  }

  static Future<void> syncCustomAmounts(
      String roomCode, Map<String, int> amounts) async {
    try {
      await http.post(
          Uri.parse('$baseUrl/api/rooms/$roomCode/sync-custom-amounts'),
          headers: _headers,
          body: jsonEncode({'amounts': amounts}));
    } catch (e) {
      debugPrint('syncCustomAmounts error: $e');
    }
  }

  static Future<void> syncAssignment(
      String roomCode, String itemId, String participantId) async {
    await http.post(Uri.parse('$baseUrl/api/rooms/$roomCode/sync-assignment'),
        headers: _headers,
        body: jsonEncode({'item_id': itemId, 'participant_id': participantId}));
  }

  static String getImageUrl(String relativeUrl) {
    if (relativeUrl.isEmpty) return '';
    if (relativeUrl.startsWith('http')) return relativeUrl;
    return '$baseUrl$relativeUrl';
  }
}

class NotaGroupData {
  final String id, title, imageUrl;
  final List<String> itemIds;
  final int discountAmount;
  NotaGroupData(
      {required this.id,
      required this.title,
      required this.itemIds,
      this.imageUrl = '',
      this.discountAmount = 0});
}
