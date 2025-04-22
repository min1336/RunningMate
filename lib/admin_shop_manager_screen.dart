import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminShopManagerScreen extends StatefulWidget {
  const AdminShopManagerScreen({super.key});

  @override
  State<AdminShopManagerScreen> createState() => _AdminShopManagerScreenState();
}

Future<bool> isAdminUser() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;

  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  return doc.data()?['isAdmin'] == true;
}

class _AdminShopManagerScreenState extends State<AdminShopManagerScreen> {
  final _nameController = TextEditingController();
  final _costController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descController = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoadItems();
  }

  Future<void> _checkAdminAndLoadItems() async {
    final isAdmin = await isAdminUser();
    setState(() => _isAdmin = isAdmin);

    if (isAdmin) {
      final snapshot = await FirebaseFirestore.instance.collection('shop_items').get();
      final items = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      setState(() => _items = items);
    }
  }

  Future<void> _addItem() async {
    final name = _nameController.text.trim();
    final cost = int.tryParse(_costController.text.trim()) ?? 0;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final description = _descController.text.trim();

    if (name.isEmpty || cost <= 0 || quantity <= 0 || description.isEmpty) return;

    await FirebaseFirestore.instance.collection('shop_items').add({
      'name': name,
      'cost': cost,
      'quantity': quantity,
      'description': description,
    });

    _nameController.clear();
    _costController.clear();
    _quantityController.clear();
    _descController.clear();

    _checkAdminAndLoadItems();
  }

  Future<void> _deleteItem(String itemId) async {
    await FirebaseFirestore.instance.collection('shop_items').doc(itemId).delete();
    _checkAdminAndLoadItems();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text("상품 관리")),
        body: const Center(child: Text("🔒 관리자만 접근 가능합니다.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("🛒 상품 관리")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "상품 이름")),
            TextField(controller: _costController, decoration: const InputDecoration(labelText: "가격 (캐시)"), keyboardType: TextInputType.number),
            TextField(controller: _quantityController, decoration: const InputDecoration(labelText: "수량"), keyboardType: TextInputType.number),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: "설명")),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text("상품 등록"),
            ),
            const Divider(height: 30),
            Expanded(
              child: ListView(
                children: _items.map((item) {
                  return ListTile(
                    title: Text(item['name']),
                    subtitle: Text("${item['cost']} 캐시 | 수량: ${item['quantity']}\n${item['description']}"),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteItem(item['id']),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}