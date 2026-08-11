// lib/providers/session_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class NotaGroup {
  final String id, title, imageUrl;
  final List<String> itemIds;
  final int discountAmount;
  NotaGroup(
      {required this.id,
      required this.title,
      required this.itemIds,
      this.imageUrl = '',
      this.discountAmount = 0});
}

class SessionProvider extends ChangeNotifier {
  String? _roomCode;
  bool _isHost = false;
  String _myParticipantId = '';
  String _myName = '';
  List<Participant> _participants = [];
  List<MenuItem> _menuItems = [];
  List<ManualExpense> _manualExpenses = [];
  List<NotaGroup> _notaGroups = [];
  TaxScheme _taxScheme = TaxScheme.none;
  double _taxRate = 0.10;
  double _serviceRate = 0.05;
  int _totalDiscountAmount = 0;
  bool _isScanning = false;
  String? _scanError;
  String? _createRoomError;
  bool _hasPendingSession = false;
  List<HistoryEntry> _history = [];
  WebSocketService? _wsService;
  Timer? _pollTimer;
  DateTime? _lastLocalChange;
  Map<String, int> _customAmounts = {};

  String? get roomCode => _roomCode;
  bool get isHost => _isHost;
  bool get isInSession => _roomCode != null;
  bool get hasPendingSession => _hasPendingSession;
  String get myParticipantId => _myParticipantId;
  String get myName => _myName;
  List<Participant> get participants => List.unmodifiable(_participants);
  List<MenuItem> get menuItems => List.unmodifiable(_menuItems);
  List<ManualExpense> get manualExpenses => List.unmodifiable(_manualExpenses);
  List<NotaGroup> get notaGroups => List.unmodifiable(_notaGroups);
  TaxScheme get taxScheme => _taxScheme;
  double get taxRate => _taxRate;
  double get serviceRate => _serviceRate;
  int get totalDiscountAmount => _totalDiscountAmount;
  bool get isScanning => _isScanning;
  String? get scanError => _scanError;
  String? get createRoomError => _createRoomError;
  Map<String, int> get customAmounts => Map.unmodifiable(_customAmounts);
  List<HistoryEntry> get history => List.unmodifiable(_history);

  Participant? get myParticipant {
    try {
      return _participants.firstWhere((p) => p.id == _myParticipantId);
    } catch (_) {
      return null;
    }
  }

  Participant? get hostParticipant {
    try {
      return _participants.firstWhere((p) => p.isHost);
    } catch (_) {
      return _participants.isNotEmpty ? _participants.first : null;
    }
  }

  String? getNotaTitleForItem(String itemId) {
    for (final g in _notaGroups) {
      if (g.itemIds.contains(itemId)) return g.title;
    }
    return null;
  }

  String getImageUrlForNota(String notaTitle) {
    for (final g in _notaGroups) {
      if (g.title == notaTitle) return ApiService.getImageUrl(g.imageUrl);
    }
    return '';
  }

  int getDiscountForNota(String notaTitle) {
    for (final g in _notaGroups) {
      if (g.title == notaTitle) return g.discountAmount;
    }
    return 0;
  }

  Map<String, List<MenuItem>> get itemsByNota {
    final map = <String, List<MenuItem>>{};
    for (final item in _menuItems) {
      final title = getNotaTitleForItem(item.id) ?? 'Item Lainnya';
      map.putIfAbsent(title, () => []);
      map[title]!.add(item);
    }
    return map;
  }

  SessionProvider() {
    _loadHistory();
    _checkPendingSession();
  }

  // ── Helper: parse satu MenuItem dari JSON backend (selalu sertakan category) ──
  MenuItem _menuItemFromJson(dynamic item) => MenuItem(
        id: item['id'] as String,
        name: item['name'] as String,
        priceInRupiah: item['price_in_rupiah'] as int,
        category: item['category'] as String? ?? 'lainnya',
        assignedParticipantIds:
            List<String>.from(item['assigned_participant_ids'] ?? []),
      );

  // ── AUTO-SAVE ────────────────────────────────────────────────────
  Future<void> saveActiveSession() async {
    if (_menuItems.isEmpty && _participants.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode({
        'roomCode': _roomCode,
        'isHost': _isHost,
        'myParticipantId': _myParticipantId,
        'myName': _myName,
        'participants': _participants
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'colorIndex': p.colorIndex,
                  'isHost': p.isHost
                })
            .toList(),
        'menuItems': _menuItems
            .map((i) => {
                  'id': i.id,
                  'name': i.name,
                  'priceInRupiah': i.priceInRupiah,
                  'category': i.category,
                  'assignedParticipantIds': i.assignedParticipantIds,
                })
            .toList(),
        'manualExpenses': _manualExpenses
            .map((e) => {
                  'id': e.id,
                  'description': e.description,
                  'amountInRupiah': e.amountInRupiah,
                  'sharedByIds': e.sharedByIds,
                })
            .toList(),
        'notaGroups': _notaGroups
            .map((g) => {
                  'id': g.id,
                  'title': g.title,
                  'itemIds': g.itemIds,
                  'imageUrl': g.imageUrl,
                  'discountAmount': g.discountAmount,
                })
            .toList(),
        'taxScheme': _taxScheme == TaxScheme.serviceBeforeTax
            ? 'service_before_tax'
            : _taxScheme == TaxScheme.serviceAfterTax
                ? 'service_after_tax'
                : _taxScheme == TaxScheme.taxOnly
                    ? 'tax_only'
                    : 'none',
        'taxRate': _taxRate,
        'serviceRate': _serviceRate,
        'totalDiscountAmount': _totalDiscountAmount,
        'customAmounts': _customAmounts,
        'savedAt': DateTime.now().toIso8601String(),
      });
      await prefs.setString('pending_session', data);
      debugPrint('Session auto-saved');
    } catch (e) {
      debugPrint('Save session error: $e');
    }
  }

  Future<void> _checkPendingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('pending_session');
      if (saved != null) {
        _hasPendingSession = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> restorePendingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('pending_session');
      if (saved == null) return false;
      final data = jsonDecode(saved) as Map<String, dynamic>;

      _roomCode = data['roomCode'] as String?;
      _isHost = data['isHost'] as bool? ?? false;
      _myParticipantId = data['myParticipantId'] as String? ?? '';
      _myName = data['myName'] as String? ?? '';

      final pList = data['participants'] as List? ?? [];
      _participants = pList
          .map((p) => Participant(
                id: p['id'] as String,
                name: p['name'] as String,
                colorIndex: p['colorIndex'] as int? ?? 0,
                isHost: p['isHost'] as bool? ?? false,
              ))
          .toList();

      final iList = data['menuItems'] as List? ?? [];
      _menuItems = iList
          .map((i) => MenuItem(
                id: i['id'] as String,
                name: i['name'] as String,
                priceInRupiah: i['priceInRupiah'] as int,
                category: i['category'] as String? ?? 'lainnya',
                assignedParticipantIds:
                    List<String>.from(i['assignedParticipantIds'] ?? []),
              ))
          .toList();

      final eList = data['manualExpenses'] as List? ?? [];
      _manualExpenses = eList
          .map((e) => ManualExpense(
                id: e['id'] as String,
                description: e['description'] as String,
                amountInRupiah: e['amountInRupiah'] as int,
                sharedByIds: List<String>.from(e['sharedByIds'] ?? []),
              ))
          .toList();

      final gList = data['notaGroups'] as List? ?? [];
      _notaGroups = gList
          .map((g) => NotaGroup(
                id: g['id'] as String,
                title: g['title'] as String,
                itemIds: List<String>.from(g['itemIds'] ?? []),
                imageUrl: g['imageUrl'] as String? ?? '',
                discountAmount: g['discountAmount'] as int? ?? 0,
              ))
          .toList();

      _taxScheme = _parseTaxScheme(data['taxScheme'] as String? ?? 'none');
      _taxRate = (data['taxRate'] as num?)?.toDouble() ?? 0.10;
      _serviceRate = (data['serviceRate'] as num?)?.toDouble() ?? 0.05;
      _totalDiscountAmount = data['totalDiscountAmount'] as int? ?? 0;
      final savedAmounts = data['customAmounts'] as Map? ?? {};
      _customAmounts = savedAmounts.isEmpty
          ? {}
          : savedAmounts
              .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      _hasPendingSession = false;

      notifyListeners();
      debugPrint(
          'Session restored: ${_menuItems.length} items, ${_participants.length} participants');
      return true;
    } catch (e) {
      debugPrint('Restore session error: $e');
      return false;
    }
  }

  Future<void> clearPendingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_session');
      _hasPendingSession = false;
      notifyListeners();
    } catch (_) {}
  }

  // ── Polling ──────────────────────────────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_roomCode == null) {
        _pollTimer?.cancel();
        return;
      }
      try {
        final roomState = await ApiService.getRoomState(_roomCode!);
        bool changed = false;

        final participants = roomState['participants'] as List? ?? [];
        final newList = participants.asMap().entries.map((e) {
          final p = e.value as Map<String, dynamic>;
          return Participant(
            id: p['id'] as String,
            name: p['name'] as String,
            colorIndex: p['color_index'] as int? ?? e.key,
            isHost: p['is_host'] as bool? ?? false,
          );
        }).toList();
        if (newList.length != _participants.length) {
          _participants = newList;
          changed = true;
        }

        final secsSince = _lastLocalChange == null
            ? 999
            : DateTime.now().difference(_lastLocalChange!).inSeconds;

        final itemsList = roomState['menu_items'] as List? ?? [];
        final newItems = itemsList.map(_menuItemFromJson).toList();

        // Grace period 3 detik setelah local change supaya polling tidak overwrite
        bool itemsChanged = false;
        if (secsSince > 3) {
          itemsChanged = newItems.length != _menuItems.length;
          if (!itemsChanged) {
            for (int i = 0; i < newItems.length; i++) {
              final n = newItems[i];
              final o = _menuItems[i];
              final nIds = n.assignedParticipantIds;
              final oIds = o.assignedParticipantIds;
              if (n.name != o.name ||
                  n.priceInRupiah != o.priceInRupiah ||
                  n.category != o.category ||
                  nIds.length != oIds.length ||
                  nIds.any((id) => !oIds.contains(id))) {
                itemsChanged = true;
                break;
              }
            }
          }
        }
        if (itemsChanged) {
          _menuItems = newItems;
          if (roomState['tax_scheme'] != null) {
            _taxScheme = _parseTaxScheme(roomState['tax_scheme'] as String);
            _taxRate = (roomState['tax_rate'] as num?)?.toDouble() ?? 0.10;
            _serviceRate =
                (roomState['service_rate'] as num?)?.toDouble() ?? 0.05;
            _totalDiscountAmount = roomState['discount_amount'] as int? ?? 0;
          }
          changed = true;
        }

        // Expense: cek perubahan isi + grace period
        final expensesList = roomState['manual_expenses'] as List? ?? [];
        final newExpenses = expensesList
            .map((e) => ManualExpense(
                  id: e['id'] as String,
                  description: e['description'] as String,
                  amountInRupiah: e['amount_in_rupiah'] as int,
                  sharedByIds: List<String>.from(e['shared_by_ids'] ?? []),
                ))
            .toList();
        bool expensesChanged = false;
        if (secsSince > 3) {
          expensesChanged = newExpenses.length != _manualExpenses.length;
          if (!expensesChanged) {
            for (int i = 0; i < newExpenses.length; i++) {
              if (newExpenses[i].id != _manualExpenses[i].id ||
                  newExpenses[i].description !=
                      _manualExpenses[i].description ||
                  newExpenses[i].amountInRupiah !=
                      _manualExpenses[i].amountInRupiah) {
                expensesChanged = true;
                break;
              }
            }
          }
        }
        if (expensesChanged) {
          _manualExpenses = newExpenses;
          changed = true;
        }

        final notaGroupsList = roomState['nota_groups'] as List? ?? [];
        if (notaGroupsList.isNotEmpty &&
            notaGroupsList.length != _notaGroups.length) {
          _notaGroups = notaGroupsList
              .map((g) => NotaGroup(
                    id: g['id'] as String,
                    title: g['title'] as String,
                    itemIds: List<String>.from(g['item_ids'] ?? []),
                    imageUrl: g['image_url'] as String? ?? '',
                    discountAmount: g['discount_amount'] as int? ?? 0,
                  ))
              .toList();
          changed = true;
        }

        final customAmountsRaw = roomState['custom_amounts'] as Map? ?? {};
        final newAmounts = customAmountsRaw.isEmpty
            ? <String, int>{}
            : customAmountsRaw
                .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        if (newAmounts.toString() != _customAmounts.toString()) {
          _customAmounts = newAmounts;
          changed = true;
        }

        if (changed) notifyListeners();
      } catch (e) {
        debugPrint('Poll error: $e');
      }
    });
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'] as String;
    final data = message['data'];
    switch (type) {
      case 'room_state':
      case 'participant_joined':
        final list = (data['participants'] as List? ?? []);
        _participants = list.asMap().entries.map((e) {
          final p = e.value as Map<String, dynamic>;
          return Participant(
            id: p['id'] as String,
            name: p['name'] as String,
            colorIndex: p['color_index'] as int? ?? e.key,
            isHost: p['is_host'] as bool? ?? false,
          );
        }).toList();
        notifyListeners();
        break;
      case 'participant_left':
        final leftId = message['participant_id'] as String? ?? '';
        final leftList = (data['participants'] as List? ?? []);
        _participants = leftList.asMap().entries.map((e) {
          final p = e.value as Map<String, dynamic>;
          return Participant(
            id: p['id'] as String,
            name: p['name'] as String,
            colorIndex: p['color_index'] as int? ?? e.key,
            isHost: p['is_host'] as bool? ?? false,
          );
        }).toList();
        // Bersihin assignments dari participant yang keluar
        if (leftId.isNotEmpty) {
          _menuItems = _menuItems.map((item) {
            final ids = List<String>.from(item.assignedParticipantIds);
            if (ids.contains(leftId)) {
              ids.remove(leftId);
              return MenuItem(
                id: item.id,
                name: item.name,
                priceInRupiah: item.priceInRupiah,
                category: item.category,
                assignedParticipantIds: ids,
              );
            }
            return item;
          }).toList();
        }
        notifyListeners();
        break;
      case 'amounts_updated':
        final amountsRaw = data['custom_amounts'] as Map? ?? {};
        _customAmounts = amountsRaw
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        notifyListeners();
        break;
      case 'expenses_updated':
        final expList = (data['manual_expenses'] as List? ?? []);
        _manualExpenses = expList
            .map((e) => ManualExpense(
                  id: e['id'] as String,
                  description: e['description'] as String,
                  amountInRupiah: e['amount_in_rupiah'] as int,
                  sharedByIds: List<String>.from(e['shared_by_ids'] ?? []),
                ))
            .toList();
        notifyListeners();
        break;
      case 'items_updated':
        final itemsList = data['items'] as List? ?? [];
        _menuItems = itemsList.map(_menuItemFromJson).toList();
        final notaGroupsList = data['nota_groups'] as List? ?? [];
        if (notaGroupsList.isNotEmpty) {
          _notaGroups = notaGroupsList
              .map((g) => NotaGroup(
                    id: g['id'] as String,
                    title: g['title'] as String,
                    itemIds: List<String>.from(g['item_ids'] ?? []),
                    imageUrl: g['image_url'] as String? ?? '',
                    discountAmount: g['discount_amount'] as int? ?? 0,
                  ))
              .toList();
        }
        if (data['tax_scheme'] != null) {
          _taxScheme = _parseTaxScheme(data['tax_scheme'] as String);
          _taxRate = (data['tax_rate'] as num?)?.toDouble() ?? 0.10;
          _serviceRate = (data['service_rate'] as num?)?.toDouble() ?? 0.05;
          _totalDiscountAmount = data['discount_amount'] as int? ?? 0;
        }
        notifyListeners();
        break;
    }
  }

  TaxScheme _parseTaxScheme(String str) {
    switch (str) {
      case 'service_before_tax':
      case 'TaxScheme.serviceBeforeTax':
        return TaxScheme.serviceBeforeTax;
      case 'service_after_tax':
      case 'TaxScheme.serviceAfterTax':
        return TaxScheme.serviceAfterTax;
      case 'tax_only':
      case 'TaxScheme.taxOnly':
        return TaxScheme.taxOnly;
      default:
        return TaxScheme.none;
    }
  }

  Future<void> createRoom(String hostName) async {
    final code = generateRoomCode();
    final hostId = generateId();
    _roomCode = code;
    _isHost = true;
    _myParticipantId = hostId;
    _myName = hostName;
    _participants = [
      Participant(id: hostId, name: hostName, colorIndex: 0, isHost: true)
    ];
    _menuItems = [];
    _manualExpenses = [];
    _notaGroups = [];
    _taxScheme = TaxScheme.none;
    _totalDiscountAmount = 0;
    _createRoomError = null;
    notifyListeners();
    try {
      await ApiService.createRoom(code, hostId, hostName);
      _wsService = WebSocketService(
          roomCode: code,
          participantId: hostId,
          onMessage: _handleWebSocketMessage);
      _wsService!.connect();
      _startPolling();
    } catch (e) {
      _createRoomError = 'Gagal buat room: $e';
      debugPrint('Create room error: $e');
      notifyListeners();
    }
  }

  Future<bool> joinRoom(String code, String name) async {
    try {
      final myId = generateId();
      final response =
          await ApiService.joinRoom(code.toUpperCase(), myId, name);

      _roomCode = code.toUpperCase();
      _isHost = false;
      _myName = name;
      _myParticipantId = response['your_participant_id'] as String? ?? myId;

      final list = response['participants'] as List? ?? [];
      _participants = list.asMap().entries.map((e) {
        final p = e.value as Map<String, dynamic>;
        return Participant(
          id: p['id'] as String,
          name: p['name'] as String,
          colorIndex: p['color_index'] as int? ?? e.key,
          isHost: p['is_host'] as bool? ?? false,
        );
      }).toList();

      // ── FIX: SELALU replace dari response, JANGAN pakai guard
      // "isNotEmpty" — supaya data sesi lama (nota/menu/expense dari
      // room sebelumnya) tidak nyangkut kalau room baru ini kosong ──
      final itemsList = response['menu_items'] as List? ?? [];
      _menuItems = itemsList.map(_menuItemFromJson).toList();

      final notaGroupsList = response['nota_groups'] as List? ?? [];
      _notaGroups = notaGroupsList
          .map((g) => NotaGroup(
                id: g['id'] as String,
                title: g['title'] as String,
                itemIds: List<String>.from(g['item_ids'] ?? []),
                imageUrl: g['image_url'] as String? ?? '',
                discountAmount: g['discount_amount'] as int? ?? 0,
              ))
          .toList();

      final expensesList = response['manual_expenses'] as List? ?? [];
      _manualExpenses = expensesList
          .map((e) => ManualExpense(
                id: e['id'] as String,
                description: e['description'] as String,
                amountInRupiah: e['amount_in_rupiah'] as int,
                sharedByIds: List<String>.from(e['shared_by_ids'] ?? []),
              ))
          .toList();

      _taxScheme = _parseTaxScheme(response['tax_scheme'] as String? ?? 'none');
      _taxRate = (response['tax_rate'] as num?)?.toDouble() ?? 0.10;
      _serviceRate = (response['service_rate'] as num?)?.toDouble() ?? 0.05;
      _totalDiscountAmount = response['discount_amount'] as int? ?? 0;

      final customAmountsRaw = response['custom_amounts'] as Map? ?? {};
      _customAmounts = customAmountsRaw.isEmpty
          ? {}
          : customAmountsRaw
              .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));

      _wsService = WebSocketService(
        roomCode: code.toUpperCase(),
        participantId: _myParticipantId,
        onMessage: _handleWebSocketMessage,
      );
      _wsService!.connect();
      _startPolling();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Join room error: $e');
      return false;
    }
  }

  void setScannedItems(
    List<MenuItem> items, {
    TaxScheme scheme = TaxScheme.serviceBeforeTax,
    double taxRate = 0.10,
    double serviceRate = 0.05,
    String notaTitle = '',
    String imageUrl = '',
    int discountAmount = 0,
  }) async {
    if (notaTitle.isNotEmpty && items.isNotEmpty) {
      _notaGroups.add(NotaGroup(
        id: generateId(),
        title: notaTitle,
        itemIds: items.map((i) => i.id).toList(),
        imageUrl: imageUrl,
        discountAmount: discountAmount,
      ));
    }
    _menuItems = [..._menuItems, ...items];
    _taxScheme = scheme;
    _taxRate = taxRate;
    _serviceRate = serviceRate;
    _totalDiscountAmount += discountAmount;
    _isScanning = false;
    _scanError = null;
    notifyListeners();
    saveActiveSession();
    if (_roomCode != null) {
      try {
        final notaGroupData = _notaGroups
            .map((g) => NotaGroupData(
                  id: g.id,
                  title: g.title,
                  itemIds: g.itemIds,
                  imageUrl: g.imageUrl,
                  discountAmount: g.discountAmount,
                ))
            .toList();
        await ApiService.syncItems(_roomCode!, _menuItems, notaGroupData,
            taxScheme: scheme,
            taxRate: taxRate,
            serviceRate: serviceRate,
            discountAmount: _totalDiscountAmount);
      } catch (e) {
        debugPrint('Sync items error: $e');
      }
    }
  }

  void setScanning(bool value, {String? error}) {
    _isScanning = value;
    _scanError = error;
    notifyListeners();
  }

  void clearItems() {
    _menuItems = [];
    _notaGroups = [];
    _totalDiscountAmount = 0;
    notifyListeners();
  }

  void deleteItem(String itemId) async {
    _lastLocalChange = DateTime.now();
    _menuItems = _menuItems.where((item) => item.id != itemId).toList();
    for (final g in _notaGroups) {
      g.itemIds.remove(itemId);
    }
    _notaGroups = _notaGroups.where((g) => g.itemIds.isNotEmpty).toList();
    notifyListeners();
    if (_roomCode != null) {
      try {
        final notaGroupData = _notaGroups
            .map((g) => NotaGroupData(
                  id: g.id,
                  title: g.title,
                  itemIds: g.itemIds,
                  imageUrl: g.imageUrl,
                  discountAmount: g.discountAmount,
                ))
            .toList();
        await ApiService.syncItems(_roomCode!, _menuItems, notaGroupData,
            taxScheme: _taxScheme,
            taxRate: _taxRate,
            serviceRate: _serviceRate,
            discountAmount: _totalDiscountAmount);
      } catch (e) {
        debugPrint('Sync delete error: $e');
      }
    }
  }

  void editItem(String itemId, String newName, int newPrice) async {
    _lastLocalChange = DateTime.now();
    final index = _menuItems.indexWhere((item) => item.id == itemId);
    if (index == -1) return;
    _menuItems[index] =
        _menuItems[index].copyWith(name: newName, priceInRupiah: newPrice);
    _menuItems = List.from(_menuItems);
    notifyListeners();
    if (_roomCode != null) {
      try {
        final notaGroupData = _notaGroups
            .map((g) => NotaGroupData(
                  id: g.id,
                  title: g.title,
                  itemIds: g.itemIds,
                  imageUrl: g.imageUrl,
                  discountAmount: g.discountAmount,
                ))
            .toList();
        await ApiService.syncItems(_roomCode!, _menuItems, notaGroupData,
            taxScheme: _taxScheme,
            taxRate: _taxRate,
            serviceRate: _serviceRate,
            discountAmount: _totalDiscountAmount);
      } catch (e) {
        debugPrint('Sync edit error: $e');
      }
    }
  }

  void deleteManualExpense(String expenseId) {
    _lastLocalChange = DateTime.now();
    _manualExpenses = _manualExpenses.where((e) => e.id != expenseId).toList();
    notifyListeners();
    _syncExpenses();
  }

  void editManualExpense(
      String expenseId, String newDescription, int newAmount) {
    _lastLocalChange = DateTime.now();
    final index = _manualExpenses.indexWhere((e) => e.id == expenseId);
    if (index == -1) return;
    _manualExpenses[index] = ManualExpense(
      id: expenseId,
      description: newDescription,
      amountInRupiah: newAmount,
      sharedByIds: _manualExpenses[index].sharedByIds,
    );
    _manualExpenses = List.from(_manualExpenses);
    notifyListeners();
    _syncExpenses();
  }

  void addManualExpense(
      {required String description,
      required int amountInRupiah,
      required List<String> sharedByIds}) {
    _lastLocalChange = DateTime.now();
    _manualExpenses = [
      ..._manualExpenses,
      ManualExpense(
        id: generateId(),
        description: description,
        amountInRupiah: amountInRupiah,
        sharedByIds: sharedByIds,
      )
    ];
    notifyListeners();
    _syncExpenses();
  }

  void _syncExpenses() {
    if (_roomCode == null) return;
    ApiService.syncManualExpenses(_roomCode!, _manualExpenses)
        .catchError((e) => debugPrint('Sync expenses error: $e'));
  }

  void toggleItemAssignment(String itemId, String participantId) {
    _lastLocalChange = DateTime.now();
    final index = _menuItems.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      final current = _menuItems[index];
      final newIds = List<String>.from(current.assignedParticipantIds);
      if (newIds.contains(participantId)) {
        newIds.remove(participantId);
      } else {
        newIds.add(participantId);
      }
      final updatedItem = MenuItem(
        id: current.id,
        name: current.name,
        priceInRupiah: current.priceInRupiah,
        category: current.category,
        assignedParticipantIds: newIds,
      );
      final newList = List<MenuItem>.from(_menuItems);
      newList[index] = updatedItem;
      _menuItems = newList;
      notifyListeners();
    }
    if (_roomCode != null) {
      ApiService.syncAssignment(_roomCode!, itemId, participantId)
          .catchError((e) => debugPrint('Sync assignment error: $e'));
    }
  }

  void addManualExpenseWithExpense(
      {required String description,
      required int amountInRupiah,
      required List<String> sharedByIds}) {
    addManualExpense(
        description: description,
        amountInRupiah: amountInRupiah,
        sharedByIds: sharedByIds);
  }

  void setCustomAmounts(Map<String, int> amounts) {
    _customAmounts = Map.from(amounts);
    notifyListeners();
    if (_roomCode != null) {
      ApiService.syncCustomAmounts(_roomCode!, amounts)
          .catchError((e) => debugPrint('Sync amounts error: $e'));
    }
  }

  BillSummary calculateBill() {
    int subtotal = 0;
    final Map<String, int> perParticipant = {};
    for (final p in _participants) {
      perParticipant[p.id] = 0;
    }
    for (final item in _menuItems) {
      subtotal += item.priceInRupiah;
      if (item.assignedParticipantIds.isNotEmpty) {
        final count = item.assignedParticipantIds.length;
        final perPerson = item.priceInRupiah ~/ count;
        final remainder = item.priceInRupiah - (perPerson * count);
        for (int i = 0; i < item.assignedParticipantIds.length; i++) {
          final id = item.assignedParticipantIds[i];
          perParticipant[id] =
              (perParticipant[id] ?? 0) + perPerson + (i == 0 ? remainder : 0);
        }
      }
    }
    for (final expense in _manualExpenses) {
      if (expense.sharedByIds.isNotEmpty) {
        final perPerson = expense.amountInRupiah ~/ expense.sharedByIds.length;
        final remainder =
            expense.amountInRupiah - (perPerson * expense.sharedByIds.length);
        for (int i = 0; i < expense.sharedByIds.length; i++) {
          final id = expense.sharedByIds[i];
          perParticipant[id] =
              (perParticipant[id] ?? 0) + perPerson + (i == 0 ? remainder : 0);
        }
      }
    }
    int serviceAmount = 0, taxAmount = 0;
    switch (_taxScheme) {
      case TaxScheme.serviceBeforeTax:
        serviceAmount = (subtotal * _serviceRate).round();
        taxAmount = ((subtotal + serviceAmount) * _taxRate).round();
        break;
      case TaxScheme.serviceAfterTax:
        taxAmount = (subtotal * _taxRate).round();
        serviceAmount = ((subtotal + taxAmount) * _serviceRate).round();
        break;
      case TaxScheme.taxOnly:
        taxAmount = (subtotal * _taxRate).round();
        break;
      case TaxScheme.none:
        break;
    }
    final totalTaxService = taxAmount + serviceAmount;
    final manualTotal =
        _manualExpenses.fold<int>(0, (s, e) => s + e.amountInRupiah);
    final totalAmount =
        subtotal + manualTotal + totalTaxService - _totalDiscountAmount;
    if (subtotal > 0 && totalTaxService > 0) {
      int distributed = 0;
      final ids = perParticipant.keys.toList();
      for (int i = 0; i < ids.length; i++) {
        final share = perParticipant[ids[i]]!;
        if (share > 0) {
          if (i == ids.length - 1) {
            perParticipant[ids[i]] = share + (totalTaxService - distributed);
          } else {
            final tax = (share * totalTaxService / subtotal).round();
            perParticipant[ids[i]] = share + tax;
            distributed += tax;
          }
        }
      }
    }
    if (_totalDiscountAmount > 0 && perParticipant.isNotEmpty) {
      int distributed = 0;
      final ids = perParticipant.keys.toList();
      for (int i = 0; i < ids.length; i++) {
        final share = perParticipant[ids[i]]!;
        if (i == ids.length - 1) {
          perParticipant[ids[i]] =
              (share - (_totalDiscountAmount - distributed)).clamp(0, share);
        } else {
          final disc = (_totalDiscountAmount / ids.length).round();
          perParticipant[ids[i]] = (share - disc).clamp(0, share);
          distributed += disc;
        }
      }
    }
    return BillSummary(
      subtotal: subtotal,
      taxAmount: taxAmount,
      taxRate: _taxRate,
      serviceAmount: serviceAmount,
      totalAmount: totalAmount,
      taxScheme: _taxScheme,
      perParticipant: perParticipant,
      discountAmount: _totalDiscountAmount,
    );
  }

  Future<void> finishSession(String sessionTitle,
      {Map<String, int>? editedAmounts}) async {
    final summary = calculateBill();
    final historyParticipants = _participants.map((p) {
      final amount = editedAmounts?[p.id] ?? summary.perParticipant[p.id] ?? 0;
      return HistoryParticipant(
          name: p.name, amount: amount, colorIndex: p.colorIndex);
    }).toList();
    final historyNotaGroups = itemsByNota.entries.map((entry) {
      final notaSubtotal =
          entry.value.fold<int>(0, (sum, item) => sum + item.priceInRupiah);
      return HistoryNotaGroup(
        title: entry.key,
        subtotal: notaSubtotal,
        items: entry.value
            .map((item) =>
                HistoryItem(name: item.name, price: item.priceInRupiah))
            .toList(),
      );
    }).toList();
    final entry = HistoryEntry(
      id: generateId(),
      title: sessionTitle.isNotEmpty ? sessionTitle : 'Sesi ${_roomCode ?? ""}',
      date: DateTime.now(),
      totalAmount: editedAmounts != null
          ? editedAmounts.values.fold(0, (a, b) => a + b)
          : summary.totalAmount,
      subtotal: summary.subtotal,
      taxAmount: summary.taxAmount,
      serviceAmount: summary.serviceAmount,
      discountAmount: _totalDiscountAmount,
      participants: historyParticipants,
      notaGroups: historyNotaGroups,
    );
    _history = [entry, ..._history];
    await _saveHistory();
    await clearPendingSession();
    _stopSession();
    notifyListeners();
  }

  void deleteHistory(String historyId) async {
    _history = _history.where((h) => h.id != historyId).toList();
    await _saveHistory();
    notifyListeners();
  }

  void leaveSession() async {
    if (_roomCode != null && _myParticipantId.isNotEmpty) {
      try {
        await ApiService.leaveRoom(_roomCode!, _myParticipantId);
      } catch (e) {
        debugPrint('Leave error: $e');
      }
    }
    _stopSession();
    notifyListeners();
  }

  void _stopSession() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _wsService?.disconnect();
    _wsService = null;
    _roomCode = null;
    _isHost = false;
    _participants = [];
    _menuItems = [];
    _manualExpenses = [];
    _notaGroups = [];
    _taxScheme = TaxScheme.none;
    _totalDiscountAmount = 0;
    _customAmounts = {};
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          'history', _history.map((e) => jsonEncode(e.toJson())).toList());
    } catch (e) {
      debugPrint('Gagal simpan history: $e');
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('history') ?? [];
      _history =
          saved.map((s) => HistoryEntry.fromJson(jsonDecode(s))).toList();
    } catch (e) {
      _history = [];
    }
    notifyListeners();
  }
}
