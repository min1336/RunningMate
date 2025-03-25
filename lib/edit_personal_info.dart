import 'package:flutter/material.dart';

class EditPersonalInfoScreen extends StatefulWidget {
  final String name;
  final String height;
  final String weight;

  const EditPersonalInfoScreen({super.key,
    required this.name,
    required this.height,
    required this.weight,
  });

  @override
  // ignore: library_private_types_in_public_api
  _EditPersonalInfoScreenState createState() => _EditPersonalInfoScreenState();
}

class _EditPersonalInfoScreenState extends State<EditPersonalInfoScreen> {
  late TextEditingController _nameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _heightController = TextEditingController(text: widget.height);
    _weightController = TextEditingController(text: widget.weight);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('개인정보 편집')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: '이름'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _heightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '키 (cm)'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '체중 (kg)'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'name': _nameController.text,
                  'height': _heightController.text,
                  'weight': _weightController.text,
                });
              },
              child: Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}