import 'package:billreciptapp/databasehelper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddProductScreen extends StatefulWidget {
  final bool isOnline;

  AddProductScreen({required this.isOnline});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tamilNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitController = TextEditingController(text: 'எண்');
  final _categoryController = TextEditingController(text: 'பொது');
  final _barcodeController = TextEditingController();
  final _stockController = TextEditingController(text: '100');
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        final productId = DateTime.now().millisecondsSinceEpoch.toString();

        // Save to local database
        await _dbHelper.insertProduct({
          'id': productId,
          'name': _nameController.text,
          'tamilName': _tamilNameController.text,
          'price': double.parse(_priceController.text),
          'unit': _unitController.text,
          'category': _categoryController.text,
          'barcode': _barcodeController.text,
          'stock': double.parse(_stockController.text),
          'lastSynced': DateTime.now().toIso8601String(),
          'isLocal': widget.isOnline ? 0 : 1,
        });

        // Save to Firestore if online
        if (widget.isOnline) {
          await FirebaseFirestore.instance
              .collection('products')
              .doc(productId)
              .set({
                'name': _nameController.text,
                'tamilName': _tamilNameController.text,
                'price': double.parse(_priceController.text),
                'unit': _unitController.text,
                'category': _categoryController.text,
                'barcode': _barcodeController.text,
                'stock': double.parse(_stockController.text),
                'createdAt': FieldValue.serverTimestamp(),
              });
        }

        // Save category if new
        await _dbHelper.insertCategory({
          'name': _categoryController.text,
          'orderIndex': 999,
        });

        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('பொருள் சேர்க்கப்பட்டது')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('பிழை: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('புதிய பொருள் சேர்')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            if (!widget.isOnline)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ஆஃப்லைன் முறையில் சேர்க்கப்படுகிறது',
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 10),
            TextFormField(
              controller: _tamilNameController,
              decoration: InputDecoration(
                labelText: 'பொருள் பெயர் (தமிழ்)',
                hintText: 'உதா: மேகி, பால் பிகிஸ்',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? 'பெயர் தேவை' : null,
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Product Name (English)',
                hintText: 'Ex: Maggi, Milk Bikis',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'விலை',
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => value!.isEmpty ? 'விலை தேவை' : null,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _unitController,
                    decoration: InputDecoration(
                      labelText: 'அலகு',
                      hintText: 'எண், கிலோ, லிட்டர்',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: 'வகை',
                hintText: 'உதா: மளிகை, பால் பொருட்கள்',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'பார்கோடு (விருப்பம்)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: _stockController,
              decoration: InputDecoration(
                labelText: 'கையிருப்பு',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saveProduct,
              icon: Icon(Icons.save),
              label: Text('சேமி'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
