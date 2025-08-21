import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:billreciptapp/addproductscreen.dart';
import 'package:billreciptapp/databasehelper.dart';
import 'package:billreciptapp/usermodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReceiptScreen extends StatefulWidget {
  @override
  _ReceiptScreenState createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _searchController = TextEditingController();
  final Connectivity _connectivity = Connectivity();

  // Firestore listeners
  StreamSubscription<QuerySnapshot>? _productsListener;
  StreamSubscription<DocumentSnapshot>? _shopDetailsListener;

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
    'shareReceipt': {'ta': 'பகிர்', 'en': 'Share'},
    'saveReceipt': {'ta': 'சேமி', 'en': 'Save'},
    'lastSync': {'ta': 'கடைசி ஒத்திசைவு', 'en': 'Last Sync'},
    'addedToCart': {'ta': 'கூடையில் சேர்க்கப்பட்டது', 'en': 'Added to cart'},
    'alreadyInCart': {'ta': 'ஏற்கனவே கூடையில் உள்ளது', 'en': 'Already in cart'},
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
    'productsFound': {'ta': 'பொருட்கள் கிடைத்தது', 'en': 'products found'},
    'details': {'ta': 'விபரங்கள்', 'en': 'Details'},
    'qty': {'ta': 'அளவு', 'en': 'Qty'},
    'rate': {'ta': 'விலை', 'en': 'Rate'},
    'amount': {'ta': 'தொகை', 'en': 'Amount'},
    'thanks': {'ta': 'நன்றி', 'en': 'Thank You'},
    'visitAgain': {'ta': 'மீண்டும் வாருங்கள்', 'en': 'Visit Again'},
    'receipt': {'ta': 'மதிப்பீட்டு ரசீது', 'en': 'Receipt'},
    'savedSuccess': {
      'ta': 'ரசீது சேமிக்கப்பட்டது',
      'en': 'Receipt saved successfully',
    },
  };

  String tr(String key) {
    return translations[key]?[isTamil ? 'ta' : 'en'] ?? key;
  }

  // Shop Details from Firebase
  String shopNameTamil = "ரேவதி ஸ்டோர்";
  String shopNameEnglish = "Revathi Store";
  String addressTamil = "எண்.9, பச்சையப்பன் தெரு";
  String addressEnglish = "No.9, Pachaiappan Street";
  String cityTamil = "மேற்கு ஜாபர்கான்பேட்டை, சென்னை-2";
  String cityEnglish = "West Jafferkhanpet, Chennai-2";
  String phone = "8056115927";
  String headerText = "சேர்மன் சாமி துணை";
  String footerText1 = "★பொருட்களை சரிபார்த்து எடுத்துக்கொள்ளவும்★";
  String footerText2 = "கூகுள்பேயும்பார் 8925463455";
  String footerText3 = "24 முதல்29விடுமுறை";
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
    _setupRealtimeListeners();
    _loadShopDetails();
  }

  void _setupRealtimeListeners() {
    // Listen to products collection changes
    _productsListener = _firestore.collection('products').snapshots().listen((
      snapshot,
    ) {
      if (!isFirstLoad) {
        _handleProductsUpdate(snapshot);
      }
    });
  }

  void _handleProductsUpdate(QuerySnapshot snapshot) {
    final products = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return Product(
        id: doc.id,
        name: data['name'] ?? '',
        tamilName: data['tamilName'] ?? '',
        price: (data['price'] ?? 0.0).toDouble(),
        unit: data['unit'] ?? 'எண்',
        category: data['category'] ?? 'பொது',
        barcode: data['barcode'] ?? '',
        stock: (data['stock'] ?? 0.0).toDouble(),
        isLocal: false,
      );
    }).toList();

    setState(() {
      allProducts = products;
      if (_searchController.text.isNotEmpty) {
        _filterProducts(_searchController.text);
      }
    });

    // Update local database
    _updateLocalProducts(products);
  }

  Future<void> _updateLocalProducts(List<Product> products) async {
    final productMaps = products
        .map(
          (p) => {
            'id': p.id,
            'name': p.name,
            'tamilName': p.tamilName,
            'price': p.price,
            'unit': p.unit,
            'category': p.category,
            'barcode': p.barcode,
            'stock': p.stock,
            'lastSynced': DateTime.now().toIso8601String(),
            'isLocal': 0,
          },
        )
        .toList();

    await _dbHelper.batchInsertProducts(productMaps);
  }

  Future<void> _loadShopDetails() async {
    try {
      final doc = await _firestore.collection('settings').doc('shop').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          shopNameTamil = data['shopNameTamil'] ?? shopNameTamil;
          shopNameEnglish = data['shopNameEnglish'] ?? shopNameEnglish;
          addressTamil = data['addressTamil'] ?? addressTamil;
          addressEnglish = data['addressEnglish'] ?? addressEnglish;
          cityTamil = data['cityTamil'] ?? cityTamil;
          cityEnglish = data['cityEnglish'] ?? cityEnglish;
          phone = data['phone'] ?? phone;
          headerText = data['headerText'] ?? headerText;
          footerText1 = data['footerText1'] ?? footerText1;
          footerText2 = data['footerText2'] ?? footerText2;
          footerText3 = data['footerText3'] ?? footerText3;
        });
      }
    } catch (e) {
      print('Error loading shop details: $e');
    }
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
      await _dbHelper.database;
      await _checkConnectivity();
      await _loadReceiptNumber();
      await _loadLocalData();
      await _restoreCart();
      _setupConnectivityListener();

      if (allProducts.isEmpty && isFirstLoad) {
        await _addSampleProducts();
        await _loadLocalData();
      }

      setState(() {
        isFirstLoad = false;
        filteredProducts = [];
      });
    } catch (e) {
      print('Initialization error: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error initializing app: $e';
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
    } catch (e) {
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
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final localProducts = await _dbHelper.getProducts();

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
      });

      final syncStatus = await _dbHelper.getSyncStatus();
      if (syncStatus != null && syncStatus['lastProductSync'] != null) {
        lastSync = DateTime.parse(syncStatus['lastProductSync']);
      }

      if (isOnline && !isFirstLoad) {
        await _syncWithFirestore(reloadAfterSync: false);
      }
    } catch (e) {
      print('Error loading local data: $e');
      setState(() {
        errorMessage = 'Error loading data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _syncWithFirestore({bool reloadAfterSync = false}) async {
    if (!isOnline) return;

    try {
      final snapshot = await _firestore
          .collection('products')
          .orderBy('name')
          .get()
          .timeout(Duration(seconds: 5));

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

        await _dbHelper.batchInsertProducts(firestoreProducts);

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

            if (_searchController.text.isNotEmpty) {
              _filterProducts(_searchController.text);
            }
          });
        }
      }

      final unsyncedReceipts = await _dbHelper.getUnsyncedReceipts();
      for (var receipt in unsyncedReceipts) {
        try {
          final docRef = await _firestore.collection('receipts').add({
            'receiptNumber': receipt['receiptNumber'],
            'timestamp': receipt['timestamp'],
            'items': jsonDecode(receipt['items']),
            'totalAmount': receipt['totalAmount'],
            'shopName': isTamil ? shopNameTamil : shopNameEnglish,
          });

          await _dbHelper.markReceiptSynced(receipt['id'], docRef.id);
        } catch (e) {
          print('Error syncing receipt: $e');
        }
      }

      await _dbHelper.updateSyncStatus('products', DateTime.now());
      setState(() {
        lastSync = DateTime.now();
      });

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

  bool _isProductInCart(String productId) {
    return cartItems.any((item) => item.product.id == productId);
  }

  void _showQuantityDialog(Product product) {
    // Check if already in cart
    if (_isProductInCart(product.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${isTamil ? product.tamilName : product.name} ${tr("alreadyInCart")}',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
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

      if (quantity <= 0) {
        await _removeFromCart(index);
      } else {
        await _dbHelper.updateCartItem(item.product.id, quantity);
        setState(() {
          cartItems[index].quantity = quantity;
        });
      }
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

  Future<void> _generateAndActionPDF(String action) async {
    try {
      final Uint8List pdf = await _generatePDF();

      if (action == 'print') {
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf);
      } else if (action == 'save') {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/receipt_$receiptNumber.pdf');
        await file.writeAsBytes(pdf);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('savedSuccess')),
            backgroundColor: Colors.green,
          ),
        );
      } else if (action == 'share') {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/receipt_$receiptNumber.pdf');
        await file.writeAsBytes(pdf);

        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              '${isTamil ? shopNameTamil : shopNameEnglish} - Receipt #$receiptNumber',
        );
      }

      await _saveReceiptToLocal();
      if (isOnline) {
        await _saveReceiptToFirestore();
      }
      await _incrementReceiptNumber();
      _clearCart();
    } catch (e) {
      print('Error with PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<Uint8List> _generatePDF() async {
    final pdf = pw.Document();

    final tamilFont = await PdfGoogleFonts.notoSansTamilRegular();
    final tamilFontBold = await PdfGoogleFonts.notoSansTamilBold();
    final englishFont = await PdfGoogleFonts.robotoRegular();
    final englishFontBold = await PdfGoogleFonts.robotoBold();

    final font = isTamil ? tamilFont : englishFont;
    final fontBold = isTamil ? tamilFontBold : englishFontBold;

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
              if (isTamil)
                pw.Text(
                  headerText,
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              pw.Text(
                isTamil ? 'மதிப்பீட்டு ரசீது' : 'Receipt',
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
              pw.Text(
                isTamil ? shopNameTamil : shopNameEnglish,
                style: pw.TextStyle(font: fontBold, fontSize: 14),
              ),
              pw.Text(
                isTamil ? addressTamil : addressEnglish,
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.Text(
                isTamil ? cityTamil : cityEnglish,
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.Text(
                'Phone: $phone',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'No: $receiptNumber',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                  pw.Text(
                    DateFormat('hh:mm:ss a dd/MM/yyyy').format(DateTime.now()),
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                ],
              ),
              pw.Divider(),

              // Table Header
              pw.Row(
                children: [
                  pw.Container(width: 15, child: pw.Text('')),
                  pw.Container(
                    width: 105,
                    child: pw.Text(
                      tr('details'),
                      style: pw.TextStyle(font: fontBold, fontSize: 10),
                    ),
                  ),
                  pw.Container(
                    width: 40,
                    child: pw.Text(
                      tr('qty'),
                      style: pw.TextStyle(font: fontBold, fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Container(
                    width: 35,
                    child: pw.Text(
                      tr('rate'),
                      style: pw.TextStyle(font: fontBold, fontSize: 10),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Container(
                    width: 45,
                    child: pw.Text(
                      tr('amount'),
                      style: pw.TextStyle(font: fontBold, fontSize: 10),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.Divider(),

              // Items
              ...cartItems.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final item = entry.value;

                return pw.Padding(
                  padding: pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 15,
                        child: pw.Text(
                          '$index',
                          style: pw.TextStyle(font: font, fontSize: 9),
                        ),
                      ),
                      pw.Container(
                        width: 105,
                        child: pw.Text(
                          isTamil ? item.product.tamilName : item.product.name,
                          style: pw.TextStyle(font: font, fontSize: 9),
                        ),
                      ),
                      pw.Container(
                        width: 40,
                        child: pw.Text(
                          '${item.quantity}${item.product.unit}',
                          style: pw.TextStyle(font: font, fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        width: 35,
                        child: pw.Text(
                          item.product.price.toStringAsFixed(2),
                          style: pw.TextStyle(font: font, fontSize: 9),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Container(
                        width: 45,
                        child: pw.Text(
                          item.total.toStringAsFixed(2),
                          style: pw.TextStyle(font: font, fontSize: 9),
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
                children: [
                  pw.Container(
                    width: 195,
                    child: pw.Text(
                      tr('total'),
                      style: pw.TextStyle(font: fontBold, fontSize: 11),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Container(
                    width: 45,
                    child: pw.Text(
                      totalAmount.toStringAsFixed(2),
                      style: pw.TextStyle(font: fontBold, fontSize: 11),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Text(
                tr('thanks'),
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.Text(
                tr('visitAgain'),
                style: pw.TextStyle(font: font, fontSize: 10),
              ),

              if (isTamil) ...[
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.Text(
                  footerText1,
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
                pw.Text(
                  footerText2,
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
                pw.Text(
                  footerText3,
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
              ],
            ],
          );
        },
      ),
    );

    return pdf.save(); // This returns Future<Uint8List>
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
        'shopName': isTamil ? shopNameTamil : shopNameEnglish,
        'isSynced': isOnline ? 1 : 0,
      };

      await _dbHelper.insertReceipt(receiptData);
    } catch (e) {
      print('Error saving receipt locally: $e');
    }
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.5,
              color: Colors.white,
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
                            onPressed: () {
                              _clearCart();
                              setModalState(() {});
                            },
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
                                      onPressed: () {
                                        _updateQuantity(
                                          index,
                                          item.quantity - 1,
                                        );
                                        setModalState(() {});
                                      },
                                    ),
                                    Text(
                                      '${item.quantity.toStringAsFixed(0)}',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.add_circle,
                                        color: Colors.green,
                                      ),
                                      onPressed: () {
                                        _updateQuantity(
                                          index,
                                          item.quantity + 1,
                                        );
                                        setModalState(() {});
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        _removeFromCart(index);
                                        setModalState(() {});
                                      },
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

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: cartItems.isEmpty
                                    ? null
                                    : () => _generateAndActionPDF('print'),
                                icon: Icon(Icons.print),
                                label: Text(tr('printReceipt')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            IconButton(
                              onPressed: cartItems.isEmpty
                                  ? null
                                  : () => _generateAndActionPDF('save'),
                              icon: Icon(Icons.download),
                              tooltip: tr('saveReceipt'),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            IconButton(
                              onPressed: cartItems.isEmpty
                                  ? null
                                  : () => _generateAndActionPDF('share'),
                              icon: Icon(Icons.share),
                              tooltip: tr('shareReceipt'),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        // ElevatedButton.icon(
                        //   onPressed: cartItems.isEmpty
                        //       ? null
                        //       : () {
                        //           Navigator.pop(
                        //             context,
                        //           ); // Close bottom sheet before generating PDF
                        //           // _generatePDFWithTable();
                        //         },
                        //   icon: Icon(Icons.print),
                        //   label: Text(tr('printReceipt')),
                        //   style: ElevatedButton.styleFrom(
                        //     minimumSize: Size(double.infinity, 50),
                        //     backgroundColor: Colors.green,
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
        'shopName': isTamil ? shopNameTamil : shopNameEnglish,
        'language': isTamil ? 'ta' : 'en',
      });
    } catch (e) {
      print('Error saving receipt to Firestore: $e');
    }
  }

  @override
  void dispose() {
    _productsListener?.cancel();
    _shopDetailsListener?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            Expanded(child: FittedBox(child: Text(tr('title')))),
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
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.shopping_cart),
                if (cartItems.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${cartItems.length}',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showCartBottomSheet,
            tooltip: tr('cart'),
          ),
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

          // Search Section with count
          Container(
            padding: EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
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
                if (isSearching && filteredProducts.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '${filteredProducts.length} ${tr("productsFound")}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // Products Grid
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
                        // OutlinedButton.icon(
                        //   onPressed: () {
                        //     Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder: (context) =>
                        //             AddProductScreen(isOnline: isOnline),
                        //       ),
                        //     ).then((_) => _loadLocalData());
                        //   },
                        //   icon: Icon(Icons.add),
                        //   label: Text(tr('addProduct')),
                        // ),
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
                      final inCart = _isProductInCart(product.id);

                      return Card(
                        elevation: 2,
                        color: inCart ? Colors.green[50] : null,
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
                              if (inCart)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              if (product.isLocal)
                                Positioned(
                                  top: 4,
                                  left: 4,
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

          // Divider(thickness: 2),

          // Cart Section
          // Expanded(
          //   flex: 2,
          //   child: Column(
          //     children: [
          //       Padding(
          //         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //         child: Row(
          //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //           children: [
          //             Text(
          //               '${tr("cart")} (${cartItems.length})',
          //               style: TextStyle(
          //                 fontSize: 16,
          //                 fontWeight: FontWeight.bold,
          //               ),
          //             ),
          //             if (cartItems.isNotEmpty)
          //               TextButton(
          //                 onPressed: _clearCart,
          //                 child: Text(
          //                   tr('clear'),
          //                   style: TextStyle(color: Colors.red),
          //                 ),
          //               ),
          //           ],
          //         ),
          //       ),
          //       Expanded(
          //         child: cartItems.isEmpty
          //             ? Center(child: Text(tr('emptyCart')))
          //             : ListView.builder(
          //                 itemCount: cartItems.length,
          //                 itemBuilder: (context, index) {
          //                   final item = cartItems[index];
          //                   return ListTile(
          //                     title: Text(
          //                       isTamil
          //                           ? item.product.tamilName
          //                           : item.product.name,
          //                     ),
          //                     subtitle: Text(
          //                       '₹${item.product.price} × ${item.quantity}${item.product.unit}',
          //                     ),
          //                     trailing: Row(
          //                       mainAxisSize: MainAxisSize.min,
          //                       children: [
          //                         Text(
          //                           '₹${item.total.toStringAsFixed(2)}',
          //                           style: TextStyle(
          //                             fontWeight: FontWeight.bold,
          //                           ),
          //                         ),
          //                         IconButton(
          //                           icon: Icon(
          //                             Icons.remove_circle,
          //                             color: item.quantity == 1
          //                                 ? Colors.grey
          //                                 : Colors.orange,
          //                           ),
          //                           onPressed: item.quantity == 1
          //                               ? null
          //                               : () => _updateQuantity(
          //                                   index,
          //                                   item.quantity - 1,
          //                                 ),
          //                         ),
          //                         IconButton(
          //                           icon: Icon(
          //                             Icons.add_circle,
          //                             color: Colors.green,
          //                           ),
          //                           onPressed: () => _updateQuantity(
          //                             index,
          //                             item.quantity + 1,
          //                           ),
          //                         ),
          //                         IconButton(
          //                           icon: Icon(Icons.delete, color: Colors.red),
          //                           onPressed: () => _removeFromCart(index),
          //                         ),
          //                       ],
          //                     ),
          //                   );
          //                 },
          //               ),
          //       ),
          //       Container(
          //         padding: EdgeInsets.all(16),
          //         decoration: BoxDecoration(
          //           color: Colors.grey[200],
          //           borderRadius: BorderRadius.only(
          //             topLeft: Radius.circular(16),
          //             topRight: Radius.circular(16),
          //           ),
          //         ),
          //         child: Column(
          //           children: [
          //             Row(
          //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //               children: [
          //                 Text(
          //                   '${tr("total")}:',
          //                   style: TextStyle(
          //                     fontSize: 20,
          //                     fontWeight: FontWeight.bold,
          //                   ),
          //                 ),
          //                 Text(
          //                   '₹${totalAmount.toStringAsFixed(2)}',
          //                   style: TextStyle(
          //                     fontSize: 20,
          //                     fontWeight: FontWeight.bold,
          //                   ),
          //                 ),
          //               ],
          //             ),
          //             SizedBox(height: 10),
          //             Row(
          //               children: [
          //                 Expanded(
          //                   child: ElevatedButton.icon(
          //                     onPressed: cartItems.isEmpty
          //                         ? null
          //                         : () => _generateAndActionPDF('print'),
          //                     icon: Icon(Icons.print),
          //                     label: Text(tr('printReceipt')),
          //                     style: ElevatedButton.styleFrom(
          //                       backgroundColor: Colors.green,
          //                     ),
          //                   ),
          //                 ),
          //                 SizedBox(width: 8),
          //                 IconButton(
          //                   onPressed: cartItems.isEmpty
          //                       ? null
          //                       : () => _generateAndActionPDF('save'),
          //                   icon: Icon(Icons.download),
          //                   tooltip: tr('saveReceipt'),
          //                   style: IconButton.styleFrom(
          //                     backgroundColor: Colors.blue,
          //                     foregroundColor: Colors.white,
          //                   ),
          //                 ),
          //                 SizedBox(width: 8),
          //                 IconButton(
          //                   onPressed: cartItems.isEmpty
          //                       ? null
          //                       : () => _generateAndActionPDF('share'),
          //                   icon: Icon(Icons.share),
          //                   tooltip: tr('shareReceipt'),
          //                   style: IconButton.styleFrom(
          //                     backgroundColor: Colors.orange,
          //                     foregroundColor: Colors.white,
          //                   ),
          //                 ),
          //               ],
          //             ),
          //           ],
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}
