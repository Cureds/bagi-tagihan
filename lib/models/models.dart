// lib/models/models.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Participant {
  final String id;
  final String name;
  final int colorIndex;
  final bool isHost;

  Participant(
      {required this.id,
      required this.name,
      required this.colorIndex,
      this.isHost = false});

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
  Color get color =>
      AppTheme.avatarColors[colorIndex % AppTheme.avatarColors.length];

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'colorIndex': colorIndex, 'isHost': isHost};
  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        id: json['id'] as String,
        name: json['name'] as String,
        colorIndex: json['colorIndex'] as int,
        isHost: json['isHost'] as bool? ?? false,
      );
}

// ── Kategori item: makanan / minuman / lainnya ──────────────────
class MenuItem {
  final String id;
  String name;
  int priceInRupiah;
  String category; // 'makanan' | 'minuman' | 'lainnya'
  List<String> assignedParticipantIds;

  MenuItem(
      {required this.id,
      required this.name,
      required this.priceInRupiah,
      this.category = 'lainnya',
      List<String>? assignedParticipantIds})
      : assignedParticipantIds = assignedParticipantIds ?? [];

  bool isAssignedTo(String participantId) =>
      assignedParticipantIds.contains(participantId);

  void toggleParticipant(String participantId) {
    if (assignedParticipantIds.contains(participantId)) {
      assignedParticipantIds.remove(participantId);
    } else {
      assignedParticipantIds.add(participantId);
    }
  }

  int pricePerPerson() {
    if (assignedParticipantIds.isEmpty) return 0;
    return (priceInRupiah / assignedParticipantIds.length).round();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'priceInRupiah': priceInRupiah,
        'category': category,
        'assignedParticipantIds': assignedParticipantIds,
      };

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as String,
        name: json['name'] as String,
        priceInRupiah: json['priceInRupiah'] as int,
        category: json['category'] as String? ?? 'lainnya',
        assignedParticipantIds:
            List<String>.from(json['assignedParticipantIds'] as List? ?? []),
      );

  MenuItem copyWith(
          {String? id,
          String? name,
          int? priceInRupiah,
          String? category,
          List<String>? assignedParticipantIds}) =>
      MenuItem(
        id: id ?? this.id,
        name: name ?? this.name,
        priceInRupiah: priceInRupiah ?? this.priceInRupiah,
        category: category ?? this.category,
        assignedParticipantIds:
            assignedParticipantIds ?? List.from(this.assignedParticipantIds),
      );
}

class ManualExpense {
  final String id;
  String description;
  int amountInRupiah;
  List<String> sharedByIds;

  ManualExpense(
      {required this.id,
      required this.description,
      required this.amountInRupiah,
      List<String>? sharedByIds})
      : sharedByIds = sharedByIds ?? [];

  int amountPerPerson() {
    if (sharedByIds.isEmpty) return 0;
    return (amountInRupiah / sharedByIds.length).round();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amountInRupiah': amountInRupiah,
        'sharedByIds': sharedByIds,
      };

  factory ManualExpense.fromJson(Map<String, dynamic> json) => ManualExpense(
        id: json['id'] as String,
        description: json['description'] as String,
        amountInRupiah: json['amountInRupiah'] as int,
        sharedByIds: List<String>.from(json['sharedByIds'] as List? ?? []),
      );
}

enum TaxScheme { serviceBeforeTax, serviceAfterTax, taxOnly, none }

class BillSummary {
  final int subtotal;
  final int taxAmount;
  final double taxRate;
  final int serviceAmount;
  final int discountAmount;
  final int totalAmount;
  final TaxScheme taxScheme;
  final Map<String, int> perParticipant;

  BillSummary({
    required this.subtotal,
    required this.taxAmount,
    required this.taxRate,
    required this.serviceAmount,
    required this.totalAmount,
    required this.taxScheme,
    required this.perParticipant,
    this.discountAmount = 0,
  });

  double get serviceRate => subtotal > 0 ? serviceAmount / subtotal : 0;
}

// ── History Models ──────────────────────────────────────────────
class HistoryEntry {
  final String id;
  final String title;
  final DateTime date;
  final int totalAmount;
  final List<HistoryParticipant> participants;
  final List<HistoryNotaGroup> notaGroups;
  final int subtotal;
  final int taxAmount;
  final int serviceAmount;
  final int discountAmount;

  HistoryEntry({
    required this.id,
    required this.title,
    required this.date,
    required this.totalAmount,
    this.participants = const [],
    this.notaGroups = const [],
    this.subtotal = 0,
    this.taxAmount = 0,
    this.serviceAmount = 0,
    this.discountAmount = 0,
  });

  bool get hasDetailData => participants.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'totalAmount': totalAmount,
        'subtotal': subtotal,
        'taxAmount': taxAmount,
        'serviceAmount': serviceAmount,
        'discountAmount': discountAmount,
        'participants': participants.map((p) => p.toJson()).toList(),
        'notaGroups': notaGroups.map((n) => n.toJson()).toList(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        date: DateTime.parse(json['date'] as String),
        totalAmount: json['totalAmount'] as int,
        subtotal: json['subtotal'] as int? ?? 0,
        taxAmount: json['taxAmount'] as int? ?? 0,
        serviceAmount: json['serviceAmount'] as int? ?? 0,
        discountAmount: json['discountAmount'] as int? ?? 0,
        participants: (json['participants'] as List?)
                ?.map((p) => HistoryParticipant.fromJson(p))
                .toList() ??
            [],
        notaGroups: (json['notaGroups'] as List?)
                ?.map((n) => HistoryNotaGroup.fromJson(n))
                .toList() ??
            [],
      );

  String get formattedDate {
    const months = [
      '',
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
    return '${date.day} ${months[date.month]} ${date.year}';
  }
}

class HistoryParticipant {
  final String name;
  final int amount;
  final int colorIndex;

  HistoryParticipant(
      {required this.name, required this.amount, required this.colorIndex});

  Map<String, dynamic> toJson() =>
      {'name': name, 'amount': amount, 'colorIndex': colorIndex};
  factory HistoryParticipant.fromJson(Map<String, dynamic> json) =>
      HistoryParticipant(
        name: json['name'] as String,
        amount: json['amount'] as int,
        colorIndex: json['colorIndex'] as int? ?? 0,
      );
}

class HistoryNotaGroup {
  final String title;
  final List<HistoryItem> items;
  final int subtotal;

  HistoryNotaGroup(
      {required this.title, required this.items, required this.subtotal});

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtotal': subtotal,
        'items': items.map((i) => i.toJson()).toList(),
      };
  factory HistoryNotaGroup.fromJson(Map<String, dynamic> json) =>
      HistoryNotaGroup(
        title: json['title'] as String,
        subtotal: json['subtotal'] as int? ?? 0,
        items: (json['items'] as List?)
                ?.map((i) => HistoryItem.fromJson(i))
                .toList() ??
            [],
      );
}

class HistoryItem {
  final String name;
  final int price;

  HistoryItem({required this.name, required this.price});

  Map<String, dynamic> toJson() => {'name': name, 'price': price};
  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        name: json['name'] as String,
        price: json['price'] as int,
      );
}

// ── Helpers ─────────────────────────────────────────────────────
String formatRupiah(int amount) {
  final String numStr = amount.abs().toString();
  final StringBuffer result = StringBuffer();
  int count = 0;
  for (int i = numStr.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) result.write('.');
    result.write(numStr[i]);
    count++;
  }
  final formatted = result.toString().split('').reversed.join('');
  return 'Rp ${amount < 0 ? '-' : ''}$formatted';
}

String generateId() =>
    DateTime.now().millisecondsSinceEpoch.toString() +
    (DateTime.now().microsecond).toString();

String generateRoomCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = DateTime.now().millisecondsSinceEpoch;
  String code = '';
  int seed = random;
  for (int i = 0; i < 5; i++) {
    code += chars[seed % chars.length];
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  }
  return code;
}
