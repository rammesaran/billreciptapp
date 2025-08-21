import 'dart:convert';

import 'package:billreciptapp/addproductscreen.dart';
import 'package:billreciptapp/databasehelper.dart';
import 'package:billreciptapp/usermodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;

class ReceiptScreen extends StatefulWidget {
  @override
  _ReceiptScreenState createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _searchController = TextEditingController();
  final Connectivity _connectivity = Connectivity();

  List<CartItem> cartItems = [];
  List<Product> allProducts = [];
  List<Product> filteredProducts = [];

  // Language support
  bool isTamil = true;
  Map<String, Map<String, String>> translations = {
    'title': {'ta': 'ரசீது உருவாக்கி', 'en': 'Receipt Generator'},
    'online': {'ta': 'ஆன்லைன்', 'en': 'Online'},
    'offline': {'ta': 'ஆஃப்லைன்', 'en': 'Offline'},
    'sync': {'ta': 'ஒத்திசை', 'en': 'Sync'},
    'searchProduct': {'ta': 'பொருள் தேடு', 'en': 'Search Product'},
    'searchHint': {'ta': 'பெயர் அல்லது பார்கோடு', 'en': 'Name or Barcode'},
    'noProducts': {'ta': 'பொருட்கள் இல்லை', 'en': 'No Products'},
    'searchToFind': {
      'ta': 'பொருட்களை காண தேடவும்',
      'en': 'Search to find products',
    },
    'addProduct': {'ta': 'புதிய பொருள் சேர்', 'en': 'Add New Product'},
    'cart': {'ta': 'கூடை', 'en': 'Cart'},
    'clear': {'ta': 'அழி', 'en': 'Clear'},
    'emptyCart': {'ta': 'கூடை காலியாக உள்ளது', 'en': 'Cart is empty'},
    'total': {'ta': 'மொத்தம்', 'en': 'Total'},
    'printReceipt': {'ta': 'ரசீது அச்சிடு', 'en': 'Print Receipt'},
    'lastSync': {'ta': 'கடைசி ஒத்திசைவு', 'en': 'Last Sync'},
    'addedToCart': {'ta': 'கூடையில் சேர்க்கப்பட்டது', 'en': 'Added to cart'},
    'syncSuccess': {
      'ta': 'ஒத்திசைவு வெற்றிகரமாக முடிந்தது',
      'en': 'Sync completed successfully',
    },
    'syncFailed': {
      'ta': 'ஒத்திசைவு தோல்வி - உள்ளூர் முறையில் வேலை செய்கிறது',
      'en': 'Sync failed - Working offline',
    },
    'quantity': {'ta': 'அளவு', 'en': 'Quantity'},
    'price': {'ta': 'விலை', 'en': 'Price'},
    'add': {'ta': 'சேர்', 'en': 'Add'},
    'cancel': {'ta': 'ரத்து', 'en': 'Cancel'},
    'enterQuantity': {'ta': 'அளவை உள்ளிடவும்', 'en': 'Enter quantity'},
    'stock': {'ta': 'மிச்சம்', 'en': 'Stock'},
    'retry': {'ta': 'மீண்டும் முயற்சிக்கவும்', 'en': 'Retry'},
    'error': {'ta': 'பிழை ஏற்பட்டது', 'en': 'Error occurred'},
  };

  String tr(String key) {
    return translations[key]?[isTamil ? 'ta' : 'en'] ?? key;
  }

  // Shop Details
  String shopName = "ரேவதி ஸ்டோர்";
  String address = "எண்.9, பச்சையப்பன் தெரு";
  String city = "மேற்கு ஜாபர்கான்பேட்டை, சென்னை-2";
  String phone = "போன் 8056115927";
  int receiptNumber = 3386;

  bool isLoading = false;
  bool isOnline = true;
  bool isSearching = false;
  DateTime? lastSync;
  String? errorMessage;
  bool isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isTamil = prefs.getBool('isTamil') ?? true;
    });
  }

  Future<void> _toggleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isTamil = !isTamil;
    });
    await prefs.setBool('isTamil', isTamil);
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize database first
      await _dbHelper.database;

      // Check connectivity
      await _checkConnectivity();

      // Load receipt number
      await _loadReceiptNumber();

      // Load local data
      await _loadLocalData();

      // Restore cart
      await _restoreCart();

      // Setup connectivity listener
      _setupConnectivityListener();

      // Add sample products if database is empty (first time)
      if (allProducts.isEmpty && isFirstLoad) {
        await _addSampleProducts();
        await _loadLocalData();
      }

      setState(() {
        isFirstLoad = false;
        // Don't show products by default
        filteredProducts = [];
      });
    } catch (e) {
      print('Initialization error: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'பயன்பாட்டை துவக்குவதில் பிழை: $e';
      });
    }
  }

  Future<void> _addSampleProducts() async {
    print('Adding sample products...');

    final sampleProducts = [
      {
        'id': 'sample_1',
        'name': 'Rice 5kg',
        'tamilName': 'அரிசி 5கிலோ',
        'price': 250.0,
        'unit': 'பை',
        'category': 'மளிகை',
        'barcode': '1234567890',
        'stock': 50.0,
        'lastSynced': DateTime.now().toIso8601String(),
        'isLocal': 1,
      },
      {
        'id': 'sample_2',
        'name': 'Maggi',
        'tamilName': 'மேகி',
        'price': 14.0,
        'unit': 'பாக்கெட்',
        'category': 'உணவு',
        'barcode': '8901058894857',
        'stock': 100.0,
        'lastSynced': DateTime.now().toIso8601String(),
        'isLocal': 1,
      },
      {
        'id': 'sample_3',
        'name': 'Milk Bikis',
        'tamilName': 'பால் பிகிஸ்',
        'price': 10.0,
        'unit': 'பாக்கெட்',
        'category': 'பிஸ்கட்',
        'barcode': '8901063138803',
        'stock': 200.0,
        'lastSynced': DateTime.now().toIso8601String(),
        'isLocal': 1,
      },
      {
        'id': 'sample_4',
        'name': 'Sugar 1kg',
        'tamilName': 'சர்க்கரை 1கிலோ',
        'price': 42.0,
        'unit': 'பாக்கெட்',
        'category': 'மளிகை',
        'barcode': '2345678901',
        'stock': 60.0,
        'lastSynced': DateTime.now().toIso8601String(),
        'isLocal': 1,
      },
      {
        'id': 'sample_5',
        'name': 'Tea Powder',
        'tamilName': 'டீ பவுடர்',
        'price': 55.0,
        'unit': 'பாக்கெட்',
        'category': 'பானம்',
        'barcode': '8901063174577',
        'stock': 80.0,
        'lastSynced': DateTime.now().toIso8601String(),
        'isLocal': 1,
      },
    ];

    try {
      await _dbHelper.batchInsertProducts(sampleProducts);
      print('Sample products added successfully');
    } catch (e) {
      print('Error adding sample products: $e');
    }
  }

  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      final wasOffline = !isOnline;
      setState(() {
        isOnline = result != ConnectivityResult.none;
      });

      // Only sync when coming back online from offline
      if (isOnline && wasOffline && !isLoading) {
        _syncWithFirestore(reloadAfterSync: true);
      }
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      setState(() {
        isOnline = result != ConnectivityResult.none;
      });
      print('Connectivity status: $isOnline');
    } catch (e) {
      print('Connectivity check error: $e');
      setState(() {
        isOnline = false;
      });
    }
  }

  Future<void> _loadReceiptNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        receiptNumber = prefs.getInt('receiptNumber') ?? 3386;
      });
      print('Receipt number loaded: $receiptNumber');
    } catch (e) {
      print('Error loading receipt number: $e');
    }
  }

  Future<void> _incrementReceiptNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        receiptNumber++;
      });
      await prefs.setInt('receiptNumber', receiptNumber);
    } catch (e) {
      print('Error incrementing receipt number: $e');
    }
  }

  Future<void> _loadLocalData() async {
    print('Loading local data...');
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Load products from local database
      final localProducts = await _dbHelper.getProducts();
      print('Loaded ${localProducts.length} products from local database');

      setState(() {
        allProducts = localProducts.map((data) {
          return Product(
            id: data['id'] ?? '',
            name: data['name'] ?? '',
            tamilName: data['tamilName'] ?? '',
            price: (data['price'] ?? 0.0).toDouble(),
            unit: data['unit'] ?? 'எண்',
            category: data['category'] ?? 'பொது',
            barcode: data['barcode'] ?? '',
            stock: (data['stock'] ?? 0.0).toDouble(),
            isLocal: data['isLocal'] == 1,
          );
        }).toList();
        // Don't set filteredProducts here, keep it empty until search
      });

      // Load sync status
      final syncStatus = await _dbHelper.getSyncStatus();
      if (syncStatus != null && syncStatus['lastProductSync'] != null) {
        lastSync = DateTime.parse(syncStatus['lastProductSync']);
        print('Last sync: $lastSync');
      }

      // Try to sync with Firestore if online (only if not first load)
      if (isOnline && !isFirstLoad) {
        print('Attempting to sync with Firestore...');
        await _syncWithFirestore(
          reloadAfterSync: false,
        ); // Don't reload to avoid loop
      }
    } catch (e) {
      print('Error loading local data: $e');
      setState(() {
        errorMessage = 'தரவை ஏற்றுவதில் பிழை: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _syncWithFirestore({bool reloadAfterSync = false}) async {
    if (!isOnline) {
      print('Cannot sync - offline mode');
      return;
    }

    print('Starting Firestore sync...');

    try {
      // Check if Firestore is available
      final testConnection = await _firestore
          .collection('products')
          .limit(1)
          .get()
          .timeout(Duration(seconds: 5));

      print('Firestore connection successful');

      // Sync products from Firestore to local
      final snapshot = await _firestore
          .collection('products')
          .orderBy('name')
          .get();

      print('Fetched ${snapshot.docs.length} products from Firestore');

      if (snapshot.docs.isNotEmpty) {
        final firestoreProducts = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'tamilName': data['tamilName'] ?? '',
            'price': (data['price'] ?? 0.0).toDouble(),
            'unit': data['unit'] ?? 'எண்',
            'category': data['category'] ?? 'பொது',
            'barcode': data['barcode'] ?? '',
            'stock': (data['stock'] ?? 0.0).toDouble(),
            'lastSynced': DateTime.now().toIso8601String(),
            'isLocal': 0,
          };
        }).toList();

        // Batch insert products to local database
        await _dbHelper.batchInsertProducts(firestoreProducts);
        print('Products synced to local database');

        // Update the local products list without calling _loadLocalData
        if (reloadAfterSync) {
          setState(() {
            allProducts = firestoreProducts.map((data) {
              return Product(
                id: data['id'],
                name: data['name'] ?? '',
                tamilName: data['tamilName'] ?? '',
                price: (data['price'] ?? 0.0).toDouble(),
                unit: data['unit'] ?? 'எண்',
                category: data['category'] ?? 'பொது',
                barcode: data['barcode'] ?? '',
                stock: (data['stock'] ?? 0.0).toDouble(),
                isLocal: data['isLocal'] == 1,
              );
            }).toList();
            // Keep filteredProducts based on current search
            if (_searchController.text.isNotEmpty) {
              _filterProducts(_searchController.text);
            }
          });
        }
      }

      // Sync unsynced receipts to Firestore
      final unsyncedReceipts = await _dbHelper.getUnsyncedReceipts();
      print('Found ${unsyncedReceipts.length} unsynced receipts');

      for (var receipt in unsyncedReceipts) {
        try {
          final docRef = await _firestore.collection('receipts').add({
            'receiptNumber': receipt['receiptNumber'],
            'timestamp': receipt['timestamp'],
            'items': jsonDecode(receipt['items']),
            'totalAmount': receipt['totalAmount'],
            'shopName': receipt['shopName'],
          });

          await _dbHelper.markReceiptSynced(receipt['id'], docRef.id);
          print('Receipt ${receipt['receiptNumber']} synced');
        } catch (e) {
          print('Error syncing receipt ${receipt['receiptNumber']}: $e');
        }
      }

      // Update sync status
      await _dbHelper.updateSyncStatus('products', DateTime.now());
      setState(() {
        lastSync = DateTime.now();
      });

      print('Sync completed successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('syncSuccess')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('syncFailed')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _restoreCart() async {
    try {
      final cartData = await _dbHelper.getCartItems();
      print('Restored ${cartData.length} cart items');

      setState(() {
        cartItems = cartData.map((item) {
          return CartItem(
            product: Product(
              id: item['productId'] ?? '',
              name: item['productName'] ?? '',
              tamilName: item['productTamilName'] ?? '',
              price: (item['price'] ?? 0.0).toDouble(),
              unit: item['unit'] ?? 'எண்',
              category: '',
              barcode: '',
              stock: 0,
              isLocal: false,
            ),
            quantity: (item['quantity'] ?? 1.0).toDouble(),
          );
        }).toList();
      });
    } catch (e) {
      print('Error restoring cart: $e');
    }
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredProducts = [];
        isSearching = false;
      } else {
        isSearching = true;
        filteredProducts = allProducts.where((product) {
          return product.name.toLowerCase().contains(query.toLowerCase()) ||
              product.tamilName.toLowerCase().contains(query.toLowerCase()) ||
              product.barcode.contains(query);
        }).toList();
      }
    });
  }

  void _showQuantityDialog(Product product) {
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isTamil ? product.tamilName : product.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${tr("price")}:'),
                  Text('₹${product.price.toStringAsFixed(2)}/${product.unit}'),
                ],
              ),
              if (product.stock < 10)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${tr("stock")}:'),
                    Text(
                      '${product.stock}',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              SizedBox(height: 16),
              TextField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: tr('enterQuantity'),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity =
                    double.tryParse(quantityController.text) ?? 1.0;
                if (quantity > 0) {
                  _addToCartWithQuantity(product, quantity);
                  Navigator.of(context).pop();
                }
              },
              child: Text(tr('add')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addToCartWithQuantity(Product product, double quantity) async {
    try {
      // Check if item already exists in cart
      final existingIndex = cartItems.indexWhere(
        (item) => item.product.id == product.id,
      );

      if (existingIndex != -1) {
        // Update existing item quantity
        final newQuantity = cartItems[existingIndex].quantity + quantity;
        await _dbHelper.updateCartItem(product.id, newQuantity);
        setState(() {
          cartItems[existingIndex].quantity = newQuantity;
        });
      } else {
        // Add new item to cart
        await _dbHelper.addToCart({
          'productId': product.id,
          'productName': product.name,
          'productTamilName': product.tamilName,
          'price': product.price,
          'quantity': quantity,
          'unit': product.unit,
        });
        setState(() {
          cartItems.add(CartItem(product: product, quantity: quantity));
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${isTamil ? product.tamilName : product.name} ${tr("addedToCart")}',
          ),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error adding to cart: $e');
    }
  }

  Future<void> _updateQuantity(int index, double quantity) async {
    try {
      final item = cartItems[index];
      await _dbHelper.updateCartItem(item.product.id, quantity);

      setState(() {
        if (quantity <= 0) {
          cartItems.removeAt(index);
        } else {
          cartItems[index].quantity = quantity;
        }
      });
    } catch (e) {
      print('Error updating quantity: $e');
    }
  }

  Future<void> _removeFromCart(int index) async {
    try {
      final item = cartItems[index];
      await _dbHelper.updateCartItem(item.product.id, 0);

      setState(() {
        cartItems.removeAt(index);
      });
    } catch (e) {
      print('Error removing from cart: $e');
    }
  }

  Future<void> _clearCart() async {
    try {
      await _dbHelper.clearCart();
      setState(() {
        cartItems.clear();
      });
    } catch (e) {
      print('Error clearing cart: $e');
    }
  }

  double get totalAmount => cartItems.fold(0, (sum, item) => sum + item.total);

  Future<void> _generatePDF() async {
    try {
      final pdf = pw.Document();

      // Load Tamil font
      final tamilFont = await PdfGoogleFonts.notoSansTamilRegular();
      final tamilFontBold = await PdfGoogleFonts.notoSansTamilBold();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            80 * PdfPageFormat.mm,
            double.infinity,
            marginAll: 5 * PdfPageFormat.mm,
          ),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header
                pw.Text(
                  'சேர்மன் சாமி துணை',
                  style: pw.TextStyle(font: tamilFont, fontSize: 10),
                ),
                pw.Text(
                  'மதிப்பீட்டு ரசீது',
                  style: pw.TextStyle(font: tamilFontBold, fontSize: 12),
                ),
                pw.Text(
                  shopName,
                  style: pw.TextStyle(font: tamilFontBold, fontSize: 14),
                ),
                pw.Text(
                  address,
                  style: pw.TextStyle(font: tamilFont, fontSize: 10),
                ),
                pw.Text(
                  city,
                  style: pw.TextStyle(font: tamilFont, fontSize: 10),
                ),
                pw.Text(
                  phone,
                  style: pw.TextStyle(font: tamilFont, fontSize: 10),
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'No: $receiptNumber',
                      style: pw.TextStyle(font: tamilFont, fontSize: 10),
                    ),
                    pw.Text(
                      DateFormat(
                        'hh:mm:ss a dd/MM/yyyy',
                      ).format(DateTime.now()),
                      style: pw.TextStyle(font: tamilFont, fontSize: 10),
                    ),
                  ],
                ),
                pw.Divider(),

                // Table Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'விபரங்கள்',
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'அளவு',
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'விலை',
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'தொகை',
                        style: pw.TextStyle(font: tamilFontBold, fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.Divider(),

                // Items
                ...cartItems.asMap().entries.map((entry) {
                  final item = entry.value;
                  return pw.Padding(
                    padding: pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(
                            '${item.product.tamilName}',
                            style: pw.TextStyle(font: tamilFont, fontSize: 10),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            '${item.quantity}${item.product.unit}',
                            style: pw.TextStyle(font: tamilFont, fontSize: 10),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            item.product.price.toStringAsFixed(2),
                            style: pw.TextStyle(font: tamilFont, fontSize: 10),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            item.total.toStringAsFixed(2),
                            style: pw.TextStyle(font: tamilFont, fontSize: 10),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                pw.Divider(),

                // Total
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'மொத்தம்',
                      style: pw.TextStyle(font: tamilFontBold, fontSize: 12),
                    ),
                    pw.Text(
                      totalAmount.toStringAsFixed(2),
                      style: pw.TextStyle(font: tamilFontBold, fontSize: 12),
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),
                pw.Text(
                  'நன்றி',
                  style: pw.TextStyle(font: tamilFont, fontSize: 10),
                ),
                pw.Text(
                  'மீண்டும் வாருங்கள்',
                  style: pw.TextStyle(font: tamilFont, fontSize: 10),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      // Save receipt to local database
      await _saveReceiptToLocal();

      // Try to sync with Firestore if online
      if (isOnline) {
        await _saveReceiptToFirestore();
      }

      // Increment receipt number for next receipt
      await _incrementReceiptNumber();

      // Clear cart after printing
      _clearCart();
    } catch (e) {
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF உருவாக்குவதில் பிழை: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveReceiptToLocal() async {
    try {
      final receiptData = {
        'receiptNumber': receiptNumber,
        'timestamp': DateTime.now().toIso8601String(),
        'items': jsonEncode(
          cartItems
              .map(
                (item) => {
                  'productId': item.product.id,
                  'productName': item.product.tamilName,
                  'quantity': item.quantity,
                  'price': item.product.price,
                  'total': item.total,
                },
              )
              .toList(),
        ),
        'totalAmount': totalAmount,
        'shopName': shopName,
        'isSynced': isOnline ? 1 : 0,
      };

      await _dbHelper.insertReceipt(receiptData);
      print('Receipt saved locally');
    } catch (e) {
      print('Error saving receipt locally: $e');
    }
  }

  Future<void> _saveReceiptToFirestore() async {
    if (!isOnline) return;

    try {
      await _firestore.collection('receipts').add({
        'receiptNumber': receiptNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'items': cartItems
            .map(
              (item) => {
                'productId': item.product.id,
                'productName': item.product.tamilName,
                'quantity': item.quantity,
                'price': item.product.price,
                'total': item.total,
              },
            )
            .toList(),
        'totalAmount': totalAmount,
        'shopName': shopName,
      });
      print('Receipt saved to Firestore');
    } catch (e) {
      print('Error saving receipt to Firestore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error screen if there's a critical error
    if (errorMessage != null && allProducts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('title'))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                tr('error'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeApp,
                child: Text(tr('retry')),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(tr('title')),
            SizedBox(width: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOnline ? Icons.cloud_done : Icons.cloud_off,
                    size: 16,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    tr(isOnline ? 'online' : 'offline'),
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: isOnline && !isLoading
                ? () => _syncWithFirestore(reloadAfterSync: true)
                : null,
            tooltip: tr('sync'),
          ),
          // Language toggle button
          IconButton(
            icon: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isTamil ? 'EN' : 'தமிழ்',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            onPressed: _toggleLanguage,
            tooltip: isTamil ? 'Switch to English' : 'தமிழுக்கு மாற்று',
          ),
        ],
      ),
      body: Column(
        children: [
          // Sync Status Bar
          if (lastSync != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Colors.grey[200],
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '${tr("lastSync")}: ${DateFormat('dd/MM hh:mm a').format(lastSync!)}',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

          // Search Section
          Container(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: tr('searchProduct'),
                hintText: tr('searchHint'),
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterProducts('');
                        },
                      )
                    : null,
              ),
              onChanged: _filterProducts,
            ),
          ),

          // Products Grid / Search Instructions
          Expanded(
            flex: 3,
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : !isSearching
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          tr('searchToFind'),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddProductScreen(isOnline: isOnline),
                              ),
                            ).then((_) => _loadLocalData());
                          },
                          icon: Icon(Icons.add),
                          label: Text(tr('addProduct')),
                        ),
                      ],
                    ),
                  )
                : filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                        Text(tr('noProducts')),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddProductScreen(isOnline: isOnline),
                              ),
                            ).then((_) => _loadLocalData());
                          },
                          child: Text(tr('addProduct')),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.all(8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return Card(
                        elevation: 2,
                        child: InkWell(
                          onTap: () => _showQuantityDialog(product),
                          child: Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isTamil
                                          ? product.tamilName
                                          : product.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '₹${product.price.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (product.isLocal)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.offline_pin,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Divider(thickness: 2),

          // Cart Section
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${tr("cart")} (${cartItems.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (cartItems.isNotEmpty)
                        TextButton(
                          onPressed: _clearCart,
                          child: Text(
                            tr('clear'),
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: cartItems.isEmpty
                      ? Center(child: Text(tr('emptyCart')))
                      : ListView.builder(
                          itemCount: cartItems.length,
                          itemBuilder: (context, index) {
                            final item = cartItems[index];
                            return ListTile(
                              title: Text(
                                isTamil
                                    ? item.product.tamilName
                                    : item.product.name,
                              ),
                              subtitle: Text(
                                '₹${item.product.price} × ${item.quantity}${item.product.unit}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${item.total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.remove_circle,
                                      color: Colors.orange,
                                    ),
                                    onPressed: () => _updateQuantity(
                                      index,
                                      item.quantity - 1,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.add_circle,
                                      color: Colors.green,
                                    ),
                                    onPressed: () => _updateQuantity(
                                      index,
                                      item.quantity + 1,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeFromCart(index),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${tr("total")}:',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₹${totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: cartItems.isEmpty ? null : _generatePDF,
                        icon: Icon(Icons.print),
                        label: Text(tr('printReceipt')),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
