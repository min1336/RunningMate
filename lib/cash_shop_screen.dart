import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CashShopScreen extends StatefulWidget {
  const CashShopScreen({super.key});
  @override
  State<CashShopScreen> createState() => _CashShopScreenState();
}

class _CashShopScreenState extends State<CashShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _myCash = 0;
  String _selectedSort = '가격 낮은 순';
  List<Map<String, dynamic>> _shopItems = [];
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _dailyItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return; // 전환 중일 때 무시
      if (_tabController.index == 1) {
        _loadInventory(); // 보유함 탭일 때만 새로고침
      }
    });
    _loadAllData();
  }

  Future<int> getMonthlyCashEarned() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cash_logs')
        .where('timestamp', isGreaterThanOrEqualTo: firstOfMonth)
        .get();

    int total = 0;
    for (var doc in snapshot.docs) {
      total += (doc['total'] as num).toInt();
    }
    return total;
  }

  Future<void> _loadAllData() async {
    await _loadCash();
    await _loadShopItems();
    await _loadInventory();
    await _loadDailyItems();
  }

  Future<void> _loadCash() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    setState(() => _myCash = data['cash'] ?? 0);
  }

  Future<void> _loadShopItems() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('shop_items').get();
    final items =
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    setState(() {
      _shopItems = items;
      _applySort();
    });
  }

  Future<void> _loadInventory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('purchases')
        .get();

    final itemIds = snapshot.docs.map((doc) => doc['itemId']).toSet();

    final itemSnapshot = await FirebaseFirestore.instance
        .collection('shop_items')
        .where(FieldPath.documentId, whereIn: itemIds.toList())
        .get();

    final itemMap = {for (var doc in itemSnapshot.docs) doc.id: doc.data()};

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final itemId = data['itemId'];
      grouped.putIfAbsent(itemId, () => []).add(data);
    }

    final items = grouped.entries.map((entry) {
      final itemId = entry.key;
      final purchases = entry.value;
      final count = purchases.length;
      final itemInfo = itemMap[itemId] ?? {};

      return {
        'id': itemId,
        ...itemInfo,
        ...purchases.first,
        'count': count,
      };
    }).toList();

    setState(() {
      _inventory = items;
      _applySort();
    });
  }

  Future<void> _loadDailyItems() async {
    final doc = await FirebaseFirestore.instance
        .collection('dailyShopItems')
        .doc('today')
        .get();
    if (!doc.exists) return;
    final ids = List<String>.from(doc['itemIds'] ?? []);
    final snapshot = await FirebaseFirestore.instance
        .collection('shop_items')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    final items =
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    setState(() {
      _dailyItems = items;
      _applySort();
    });
  }

  Future<void> _buyItem(Map<String, dynamic> item) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final cost = item['cost'];
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final itemRef =
        FirebaseFirestore.instance.collection('shop_items').doc(item['id']);
    String? failureMessage;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(docRef);
      final itemSnapshot = await transaction.get(itemRef);

      final currentCash = userSnapshot['cash'] ?? 0;
      final currentQuantity = itemSnapshot['quantity'] ?? 0;

      if (currentQuantity <= 0) {
        failureMessage = "❌ 품절된 상품입니다.";
        return;
      }

      if (currentCash < cost) {
        failureMessage = "❌ 캐시가 부족합니다.";
        return;
      }

      transaction.update(docRef, {'cash': currentCash - cost});
      transaction.update(itemRef, {'quantity': currentQuantity - 1});

      final purchasesRef = docRef.collection('purchases').doc();
      transaction.set(purchasesRef, {
        'itemId': item['id'],
        'name': item['name'],
        'type': item['type'] ?? '기타',
        'purchasedAt': FieldValue.serverTimestamp(),
        'used': false,
      });
    });

    if (!mounted) return;
    if (failureMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureMessage!)));
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("✅ ${item['name']} 구매 완료!")));
    await _loadCash();
    await _loadShopItems();
  }

  void _applySort() {
    setState(() {
      switch (_selectedSort) {
        case '가격 낮은 순':
          _shopItems.sort((a, b) => (a['cost'] as int).compareTo(b['cost']));
          _inventory.sort((a, b) => (a['cost'] as int).compareTo(b['cost']));
          _dailyItems.sort((a, b) => (a['cost'] as int).compareTo(b['cost']));
          break;
        case '가격 높은 순':
          _shopItems.sort((a, b) => (b['cost'] as int).compareTo(a['cost']));
          _inventory.sort((a, b) => (b['cost'] as int).compareTo(a['cost']));
          _dailyItems.sort((a, b) => (b['cost'] as int).compareTo(a['cost']));
          break;
        case '이름 가나다순':
          _shopItems.sort(
              (a, b) => (a['name'] as String).compareTo(b['name'] as String));
          _inventory.sort(
              (a, b) => (a['name'] as String).compareTo(b['name'] as String));
          _dailyItems.sort(
              (a, b) => (a['name'] as String).compareTo(b['name'] as String));
          break;
        case '수량 많은 순':
          _shopItems.sort(
              (a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));
          _inventory.sort(
              (a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));
          _dailyItems.sort(
              (a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));
          break;
      }
    });
  }

  Widget _buildSortDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: DropdownButton<String>(
        value: _selectedSort,
        items: [
          '가격 낮은 순',
          '가격 높은 순',
          '이름 가나다순',
          '수량 많은 순',
        ]
            .map((label) => DropdownMenuItem(value: label, child: Text(label)))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedSort = value!;
            _applySort();
          });
        },
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, {bool owned = false}) {
    final int quantity = item['quantity'] ?? 0;
    final bool isSoldOut = quantity <= 0;
    final String? purchasedAt = item['purchasedAt'] is Timestamp
        ? (item['purchasedAt'] as Timestamp)
            .toDate()
            .toLocal()
            .toString()
            .split(' ')[0]
        : null;
    final bool used = item['used'] == true;
    final int ownedCount = item['count'] ?? 1;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          owned
              ? (used ? Icons.check_circle_outline : Icons.inventory_2)
              : isSoldOut
                  ? Icons.block
                  : Icons.shopping_cart,
          color: owned
              ? (used ? Colors.grey : Colors.blue)
              : isSoldOut
                  ? Colors.red
                  : Colors.green,
        ),
        title: Text(item['name'] ?? '이름 없음'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['type'] ?? '기타'),
            if (owned && purchasedAt != null)
              Text("🛒 구매일: $purchasedAt",
                  style: const TextStyle(fontSize: 12)),
            if (owned)
              Text(
                used ? "✅ 사용됨" : "🟡 미사용",
                style: TextStyle(
                    fontSize: 12, color: used ? Colors.grey : Colors.black),
              ),
            Text(owned ? "내가 가진 수량: $ownedCount개" : "남은 수량: $quantity개")
          ],
        ),
        trailing: owned
            ? null
            : isSoldOut
                ? const Text("품절",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold))
                : TextButton(
                    onPressed: () => _buyItem(item),
                    child: Text("${item['cost']} 캐시"),
                  ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("💰 캐시 상점"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text("$_myCash 캐시", style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "상점"),
            Tab(text: "보유함"),
            Tab(text: "오늘의 상품"),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSortDropdown(),
          const Divider(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ListView(
                    children:
                        _shopItems.map((e) => _buildItemCard(e)).toList()),
                ListView(
                    children: _inventory
                        .map((e) => _buildItemCard(e, owned: true))
                        .toList()),
                ListView(
                    children:
                        _dailyItems.map((e) => _buildItemCard(e)).toList()),
              ],
            ),
          )
        ],
      ),
    );
  }
}
