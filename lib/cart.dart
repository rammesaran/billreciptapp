import 'dart:typed_data';
import 'package:billreciptapp/usermodel.dart';
import 'package:billreciptapp/pdf_generator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final Function(int, double) onUpdateQuantity;
  final Function(int) onRemoveFromCart;
  final Function() onClearCart;
  final Function() onCartUpdated; // Callback to update parent
  final bool isTamil;
  final bool isOnline;

  // Shop details
  final String shopNameTamil;
  final String shopNameEnglish;
  final String addressTamil;
  final String addressEnglish;
  final String cityTamil;
  final String cityEnglish;
  final String phone;
  final String headerText;
  final String footerText1;
  final String footerText2;
  final String footerText3;
  final int receiptNumber;

  const CartScreen({
    Key? key,
    required this.cartItems,
    required this.onUpdateQuantity,
    required this.onRemoveFromCart,
    required this.onClearCart,
    required this.onCartUpdated,
    required this.isTamil,
    required this.isOnline,
    required this.shopNameTamil,
    required this.shopNameEnglish,
    required this.addressTamil,
    required this.addressEnglish,
    required this.cityTamil,
    required this.cityEnglish,
    required this.phone,
    required this.headerText,
    required this.footerText1,
    required this.footerText2,
    required this.footerText3,
    required this.receiptNumber,
  }) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, Map<String, String>> translations = {
    'cart': {'ta': 'கூடை', 'en': 'Cart'},
    'clear': {'ta': 'அழி', 'en': 'Clear'},
    'emptyCart': {'ta': 'கூடை காலியாக உள்ளது', 'en': 'Cart is empty'},
    'total': {'ta': 'மொத்தம்', 'en': 'Total'},
    'printReceipt': {'ta': 'ரசீது அச்சிடு', 'en': 'Print Receipt'},
    'shareReceipt': {'ta': 'பகிர்', 'en': 'Share'},
    'saveReceipt': {'ta': 'சேமி', 'en': 'Save'},
    'savedSuccess': {
      'ta': 'ரசீது சேமிக்கப்பட்டது',
      'en': 'Receipt saved successfully',
    },
    'details': {'ta': 'விபரங்கள்', 'en': 'Details'},
    'qty': {'ta': 'அளவு', 'en': 'Qty'},
    'rate': {'ta': 'விலை', 'en': 'Rate'},
    'amount': {'ta': 'தொகை', 'en': 'Amount'},
    'thanks': {'ta': 'நன்றி', 'en': 'Thank You'},
    'visitAgain': {'ta': 'மீண்டும் வாருங்கள்', 'en': 'Visit Again'},
    'receipt': {'ta': 'மதிப்பீட்டு ரசீது', 'en': 'Receipt'},
    'clearCartConfirm': {
      'ta': 'கூடையை அழிக்க விரும்புகிறீர்களா?',
      'en': 'Clear all items from cart?',
    },
    'yes': {'ta': 'ஆம்', 'en': 'Yes'},
    'no': {'ta': 'இல்லை', 'en': 'No'},
    'removeItem': {'ta': 'பொருளை நீக்க', 'en': 'Remove Item'},
    'removeConfirm': {
      'ta': 'இந்த பொருளை நீக்க விரும்புகிறீர்களா?',
      'en': 'Remove this item from cart?',
    },
  };

  String tr(String key) {
    return translations[key]?[widget.isTamil ? 'ta' : 'en'] ?? key;
  }

  double get totalAmount =>
      widget.cartItems.fold(0, (sum, item) => sum + item.total);

  void _updateQuantity(int index, double quantity) {
    widget.onUpdateQuantity(index, quantity);
    setState(() {});
    widget.onCartUpdated();
  }

  void _removeFromCart(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(tr('removeItem')),
          content: Text(tr('removeConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('no')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onRemoveFromCart(index);
                setState(() {});
                widget.onCartUpdated();
              },
              child: Text(tr('yes'), style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _clearCart() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(tr('clear')),
          content: Text(tr('clearCartConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('no')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onClearCart();
                setState(() {});
                widget.onCartUpdated();
              },
              child: Text(tr('yes'), style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateAndActionPDF(String action) async {
    try {
      // Prepare items for PDF generation
      final items = widget.cartItems
          .map(
            (item) => {
              'productName': widget.isTamil
                  ? item.product.tamilName
                  : item.product.name,
              'quantity': item.quantity,
              'price': item.product.price,
              'total': item.total,
              'unit': item.product.unit,
            },
          )
          .toList();

      final Uint8List? pdfBytes = await PdfGenerator.generatePdf(
        shopName: widget.isTamil
            ? widget.shopNameTamil
            : widget.shopNameEnglish,
        address: widget.isTamil ? widget.addressTamil : widget.addressEnglish,
        city: widget.isTamil ? widget.cityTamil : widget.cityEnglish,
        phone: widget.phone,
        headerText: widget.headerText,
        footerText1: widget.footerText1,
        footerText2: widget.footerText2,
        footerText3: widget.footerText3,
        receiptNumber: widget.receiptNumber,
        items: items,
        totalAmount: totalAmount,
        language: widget.isTamil ? 'ta' : 'en',
      );

      if (pdfBytes == null) {
        throw Exception('Failed to generate PDF');
      }

      bool success = false;
      if (action == 'print') {
        success = await PdfGenerator.printPdf(
          pdfBytes: pdfBytes,
          jobName: 'Receipt_${widget.receiptNumber}',
        );
      } else if (action == 'save') {
        success = await PdfGenerator.savePdf(
          pdfBytes: pdfBytes,
          fileName: 'receipt_${widget.receiptNumber}.pdf',
        );
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('savedSuccess')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (action == 'share') {
        success = await PdfGenerator.sharePdf(
          pdfBytes: pdfBytes,
          fileName: 'receipt_${widget.receiptNumber}.pdf',
          shareText:
              '${widget.isTamil ? widget.shopNameTamil : widget.shopNameEnglish} - Receipt #${widget.receiptNumber}',
        );
      }

      if (success || action == 'share') {
        // Save receipt and clear cart after successful action
        await _saveReceiptToFirestore();
        await _incrementReceiptNumber();
        widget.onClearCart();
        setState(() {});
        widget.onCartUpdated();

        // Navigate back to main screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error with PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // pw.Widget _buildItemRow(
  //   String item,
  //   String qty,
  //   String rate,
  //   String amount,
  //   pw.Font font,
  // ) {
  //   return pw.Padding(
  //     padding: pw.EdgeInsets.symmetric(vertical: 2),
  //     child: pw.Row(
  //       children: [
  //         pw.Container(
  //           width: 100,
  //           child: pw.Text(item, style: pw.TextStyle(font: font, fontSize: 9)),
  //         ),
  //         pw.Container(
  //           width: 40,
  //           child: pw.Text(
  //             qty,
  //             style: pw.TextStyle(font: font, fontSize: 9),
  //             textAlign: pw.TextAlign.center,
  //           ),
  //         ),
  //         pw.Container(
  //           width: 40,
  //           child: pw.Text(
  //             rate,
  //             style: pw.TextStyle(font: font, fontSize: 9),
  //             textAlign: pw.TextAlign.right,
  //           ),
  //         ),
  //         pw.Container(
  //           width: 50,
  //           child: pw.Text(
  //             amount,
  //             style: pw.TextStyle(font: font, fontSize: 9),
  //             textAlign: pw.TextAlign.right,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Future<Uint8List> _generatePDNew() async {
  //   final pdf = pw.Document();

  //   // Load fonts consistently
  //   pw.Font tamilFont;
  //   pw.Font tamilFontBold;
  //   pw.Font englishFont;
  //   pw.Font englishFontBold;

  //   try {
  //     // Load Tamil fonts from assets
  //     final regularFontData = await rootBundle.load(
  //       'assets/fonts/NotoSansTamil-Regular.ttf',
  //     );
  //     final boldFontData = await rootBundle.load(
  //       'assets/fonts/NotoSansTamil-Bold.ttf',
  //     );

  //     tamilFont = pw.Font.ttf(regularFontData);
  //     tamilFontBold = pw.Font.ttf(boldFontData);

  //     print("Tamil font loaded successfully: Regular and Bold");
  //   } catch (e) {
  //     print("Error loading local Tamil fonts: $e");
  //     try {
  //       // Fallback to Google Fonts
  //       tamilFont = await PdfGoogleFonts.notoSansTamilRegular();
  //       tamilFontBold = await PdfGoogleFonts.notoSansTamilBold();
  //       print("Using Google Fonts fallback for Tamil");
  //     } catch (e2) {
  //       print("Error loading Google Tamil fonts: $e2");
  //       // Final fallback to Mukti Malar
  //       tamilFont = await PdfGoogleFonts.muktaMalarRegular();
  //       tamilFontBold = await PdfGoogleFonts.muktaMalarBold();
  //     }
  //   }

  //   // Always load English fonts for numbers and English text
  //   englishFont = await PdfGoogleFonts.robotoRegular();
  //   englishFontBold = await PdfGoogleFonts.robotoBold();

  //   // Use consistent font selection
  //   final primaryFont = widget.isTamil ? tamilFont : englishFont;
  //   final primaryFontBold = widget.isTamil ? tamilFontBold : englishFontBold;

  //   final theme = pw.ThemeData.withFont(
  //     base: primaryFont,
  //     bold: primaryFontBold,
  //   );

  //   pdf.addPage(
  //     pw.Page(
  //       theme: theme,
  //       pageFormat: PdfPageFormat(
  //         80 * PdfPageFormat.mm,
  //         double.infinity,
  //         marginAll: 5 * PdfPageFormat.mm,
  //       ),
  //       build: (pw.Context context) {
  //         return pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.center,
  //           children: [
  //             if (widget.isTamil)
  //               pw.Text(
  //                 widget.headerText,
  //                 style: pw.TextStyle(
  //                   font: primaryFont,
  //                   fontSize: 10,
  //                   letterSpacing: 0,
  //                 ),
  //               ),
  //             pw.Text(
  //               widget.isTamil ? 'மதிப்பீட்டு ரசீது' : 'Receipt',
  //               style: pw.TextStyle(
  //                 font: primaryFontBold,
  //                 fontSize: 12,
  //                 letterSpacing: 0,
  //               ),
  //             ),
  //             pw.Text(
  //               widget.isTamil ? widget.shopNameTamil : widget.shopNameEnglish,
  //               style: pw.TextStyle(
  //                 font: primaryFontBold,
  //                 fontSize: 14,
  //                 letterSpacing: 0,
  //               ),
  //             ),
  //             pw.Text(
  //               widget.isTamil ? widget.addressTamil : widget.addressEnglish,
  //               style: pw.TextStyle(
  //                 font: primaryFont,
  //                 fontSize: 10,
  //                 letterSpacing: 0,
  //               ),
  //             ),
  //             pw.Text(
  //               widget.isTamil ? widget.cityTamil : widget.cityEnglish,
  //               style: pw.TextStyle(
  //                 font: primaryFont,
  //                 fontSize: 10,
  //                 letterSpacing: 0,
  //               ),
  //             ),
  //             pw.Text(
  //               'Phone: ${widget.phone}',
  //               style: pw.TextStyle(font: englishFont, fontSize: 10),
  //             ),
  //             pw.SizedBox(height: 5),
  //             pw.Row(
  //               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //               children: [
  //                 pw.Text(
  //                   'No: ${widget.receiptNumber}',
  //                   style: pw.TextStyle(font: englishFont, fontSize: 10),
  //                 ),
  //                 pw.Text(
  //                   DateFormat('hh:mm:ss a dd/MM/yyyy').format(DateTime.now()),
  //                   style: pw.TextStyle(font: englishFont, fontSize: 10),
  //                 ),
  //               ],
  //             ),
  //             pw.Divider(),

  //             // Table Header with consistent font usage
  //             pw.Row(
  //               children: [
  //                 pw.Container(width: 15, child: pw.Text('')),
  //                 pw.Container(
  //                   width: 105,
  //                   child: pw.Text(
  //                     widget.isTamil ? 'விபரங்கள்' : 'Details',
  //                     style: pw.TextStyle(
  //                       font: primaryFontBold,
  //                       fontSize: 10,
  //                       letterSpacing: 0,
  //                     ),
  //                   ),
  //                 ),
  //                 pw.Container(
  //                   width: 40,
  //                   child: pw.Text(
  //                     widget.isTamil ? 'அளவு' : 'Qty',
  //                     style: pw.TextStyle(
  //                       font: primaryFontBold,
  //                       fontSize: 10,
  //                       letterSpacing: 0,
  //                     ),
  //                     textAlign: pw.TextAlign.center,
  //                   ),
  //                 ),
  //                 pw.Container(
  //                   width: 35,
  //                   child: pw.Text(
  //                     widget.isTamil ? 'விலை' : 'Rate',
  //                     style: pw.TextStyle(
  //                       font: primaryFontBold,
  //                       fontSize: 10,
  //                       letterSpacing: 0,
  //                     ),
  //                     textAlign: pw.TextAlign.right,
  //                   ),
  //                 ),
  //                 pw.Container(
  //                   width: 45,
  //                   child: pw.Text(
  //                     widget.isTamil ? 'தொகை' : 'Amount',
  //                     style: pw.TextStyle(
  //                       font: primaryFontBold,
  //                       fontSize: 10,
  //                       letterSpacing: 0,
  //                     ),
  //                     textAlign: pw.TextAlign.right,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             pw.Divider(),

  //             // Items with consistent font usage
  //             ...widget.cartItems.asMap().entries.map((entry) {
  //               final index = entry.key + 1;
  //               final item = entry.value;

  //               return pw.Padding(
  //                 padding: pw.EdgeInsets.symmetric(vertical: 1),
  //                 child: pw.Row(
  //                   children: [
  //                     pw.Container(
  //                       width: 15,
  //                       child: pw.Text(
  //                         '$index',
  //                         style: pw.TextStyle(font: englishFont, fontSize: 9),
  //                       ),
  //                     ),
  //                     pw.Container(
  //                       width: 105,
  //                       child: pw.Text(
  //                         widget.isTamil
  //                             ? item.product.tamilName
  //                             : item.product.name,
  //                         style: pw.TextStyle(
  //                           font: primaryFont,
  //                           fontSize: 9,
  //                           letterSpacing: 0,
  //                         ),
  //                       ),
  //                     ),
  //                     pw.Container(
  //                       width: 40,
  //                       child: pw.Text(
  //                         '${item.quantity}${widget.isTamil ? item.product.unit : item.product.unit}',
  //                         style: pw.TextStyle(font: englishFont, fontSize: 9),
  //                         textAlign: pw.TextAlign.center,
  //                       ),
  //                     ),
  //                     pw.Container(
  //                       width: 35,
  //                       child: pw.Text(
  //                         item.product.price.toStringAsFixed(2),
  //                         style: pw.TextStyle(font: englishFont, fontSize: 9),
  //                         textAlign: pw.TextAlign.right,
  //                       ),
  //                     ),
  //                     pw.Container(
  //                       width: 45,
  //                       child: pw.Text(
  //                         item.total.toStringAsFixed(2),
  //                         style: pw.TextStyle(font: englishFont, fontSize: 9),
  //                         textAlign: pw.TextAlign.right,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               );
  //             }),

  //             pw.Divider(),

  //             // Total
  //             pw.Row(
  //               children: [
  //                 pw.Container(
  //                   width: 195,
  //                   child: pw.Text(
  //                     widget.isTamil ? 'மொத்தம்' : 'Total',
  //                     style: pw.TextStyle(
  //                       font: primaryFontBold,
  //                       fontSize: 11,
  //                       letterSpacing: 0,
  //                     ),
  //                     textAlign: pw.TextAlign.right,
  //                   ),
  //                 ),
  //                 pw.Container(
  //                   width: 45,
  //                   child: pw.Text(
  //                     totalAmount.toStringAsFixed(2),
  //                     style: pw.TextStyle(font: englishFontBold, fontSize: 11),
  //                     textAlign: pw.TextAlign.right,
  //                   ),
  //                 ),
  //               ],
  //             ),

  //             pw.SizedBox(height: 10),
  //             pw.Text(
  //               widget.isTamil ? 'நன்றி' : 'Thank You',
  //               style: pw.TextStyle(
  //                 font: primaryFont,
  //                 fontSize: 10,
  //                 letterSpacing: 0,
  //               ),
  //             ),
  //             pw.Text(
  //               widget.isTamil ? 'மீண்டும் வாருங்கள்' : 'Visit Again',
  //               style: pw.TextStyle(
  //                 font: primaryFont,
  //                 fontSize: 10,
  //                 letterSpacing: 0,
  //               ),
  //             ),

  //             if (widget.isTamil) ...[
  //               pw.SizedBox(height: 10),
  //               pw.Divider(),
  //               pw.Text(
  //                 widget.footerText1,
  //                 style: pw.TextStyle(
  //                   font: primaryFont,
  //                   fontSize: 8,
  //                   letterSpacing: 0,
  //                 ),
  //                 textAlign: pw.TextAlign.center,
  //               ),
  //               pw.Text(
  //                 widget.footerText2,
  //                 style: pw.TextStyle(
  //                   font: primaryFont,
  //                   fontSize: 8,
  //                   letterSpacing: 0,
  //                 ),
  //               ),
  //               pw.Text(
  //                 widget.footerText3,
  //                 style: pw.TextStyle(
  //                   font: primaryFont,
  //                   fontSize: 8,
  //                   letterSpacing: 0,
  //                 ),
  //               ),
  //             ],
  //           ],
  //         );
  //       },
  //     ),
  //   );

  //   return pdf.save();
  // }

  // Future<Uint8List> _generatePDF() async {
  //   final pdf = pw.Document();

  //   // final tamilFont = await PdfGoogleFonts.notoSansTamilRegular();
  //   // final tamilFontBold = await PdfGoogleFonts.notoSansTamilBold();
  //   final fontData = await rootBundle.load('assets/fonts/Latha.ttf');
  //   final tamilFont = pw.Font.ttf(fontData);
  //   print("the fontData is $fontData");
  //   print("the tamilfont is $tamilFont");
  //   //final tamilFont = await PdfGoogleFonts.lathaRegular();
  //   // final tamilFontBold = await PdfGoogleFonts.muktaMalarBold();
  //   final englishFont = await PdfGoogleFonts.robotoRegular();
  //   final englishFontBold = await PdfGoogleFonts.robotoBold();

  //   final font = widget.isTamil ? tamilFont : englishFont;
  //   final fontBold = widget.isTamil ? tamilFont : englishFontBold;

  //   pdf.addPage(
  //     pw.Page(
  //       pageFormat: PdfPageFormat(
  //         80 * PdfPageFormat.mm,
  //         double.infinity,
  //         marginAll: 5 * PdfPageFormat.mm,
  //       ),
  //       build: (pw.Context context) {
  //         return pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.center,
  //           children: [
  //             if (widget.isTamil)
  //               pw.Text(
  //                 widget.headerText,
  //                 style: pw.TextStyle(font: font, fontSize: 10),
  //               ),
  //             pw.Text(
  //               widget.isTamil ? 'மதிப்பீட்டு ரசீது' : 'Receipt',
  //               style: pw.TextStyle(font: fontBold, fontSize: 12),
  //             ),
  //             pw.Text(
  //               widget.isTamil ? widget.shopNameTamil : widget.shopNameEnglish,
  //               style: pw.TextStyle(font: fontBold, fontSize: 14),
  //             ),
  //             pw.Text(
  //               widget.isTamil ? widget.addressTamil : widget.addressEnglish,
  //               style: pw.TextStyle(font: font, fontSize: 10),
  //             ),
  //             pw.Text(
  //               widget.isTamil ? widget.cityTamil : widget.cityEnglish,
  //               style: pw.TextStyle(font: font, fontSize: 10),
  //             ),
  //             pw.Text(
  //               'Phone: ${widget.phone}',
  //               style: pw.TextStyle(font: font, fontSize: 10),
  //             ),
  //             pw.SizedBox(height: 5),
  //             pw.Row(
  //               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //               children: [
  //                 pw.Text(
  //                   'No: ${widget.receiptNumber}',
  //                   style: pw.TextStyle(font: font, fontSize: 10),
  //                 ),
  //                 pw.Text(
  //                   DateFormat('hh:mm:ss a dd/MM/yyyy').format(DateTime.now()),
  //                   style: pw.TextStyle(font: font, fontSize: 10),
  //                 ),
  //               ],
  //             ),
  //             pw.Divider(),

  //             // Table Header
  //             pw.Row(
  //               children: [
  //                 pw.Container(width: 15, child: pw.Text('')),
  //                 pw.Container(
  //                   width: 105,
  //                   child: pw.Text(
  //                     tr('details'),
  //                     style: pw.TextStyle(font: fontBold, fontSize: 10),
  //                   ),
  //                 ),
  //                 pw.Container(
  //                   width: 40,
  //                   child: pw.Text(
  //                     tr('qty'),
  //                     style: pw.TextStyle(font: fontBold, fontSize: 10),
  //                     textAlign: pw.TextAlign.center,
  //                   ),
  //                 ),
  //                 pw.Container(
  //                   width: 35,
  //                   child: pw.Text(
  //                     tr('rate'),
  //                     style: pw.TextStyle(font: fontBold, fontSize: 10),
  //                     textAlign: pw.TextAlign.right,
  //                   ),
  //                 ),
  //                 pw.Container(
  //                   width: 45,
  //                   child: pw.Text(
  //                     tr('amount'),
  //                     style: pw.TextStyle(font: fontBold, fontSize: 10),
  //                     textAlign: pw.TextAlign.right,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             pw.Divider(),

  //             // Items
  //             ...widget.cartItems.asMap().entries.map((entry) {
  //               final index = entry.key + 1;
  //               final item = entry.value;

  //               return pw.Padding(
  //                 padding: pw.EdgeInsets.symmetric(vertical: 1),
  //                 child: pw.Row(
  //                   children: [
  //                     pw.Container(
  //                       width: 15,
  //                       child: pw.Text(
  //                         '$index',
  //                         style: pw.TextStyle(font: font, fontSize: 9),
  //                       ),
  //                     ),
  //                     pw.Container(
  //                       width: 105,
  //                       child: pw.Text(
  //                         widget.isTamil
  //                             ? item.product.tamilName
  //                             : item.product.name,
  //                         style: pw.TextStyle(font: font, fontSize: 9),
  //                       ),
  //                     ),
  //                     pw.Container(
  //                       width: 40,
  //                       child: pw.Text(
  //                         '${item.quantity}${item.product.unit}',
  //                         style: pw.TextStyle(font: font, fontSize: 9),
  //                         textAlign: pw.TextAlign.center,
  //                       ),
  //                     ),
  //                     pw.Container(
  //                       width: 35,
  //                       child: pw.Text(
  //                         item.product.price.toStringAsFixed(2),
  //                         style: pw.TextStyle(font: font, fontSize: 9),
  //                         textAlign: pw.TextAlign.right,
  //                       ),
  //                     ),
  //                     pw.Container(
  //                       width: 45,
  //                       child: pw.Text(
  //                         item.total.toStringAsFixed(2),
  //                         style: pw.TextStyle(font: font, fontSize: 9),
  //                         textAlign: pw.TextAlign.right,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               );
  //             }),

  //             pw.Divider(),

  //             // Total
  //             pw.Row(
  //               children: [
  //                 pw.Container(
  //                   width: 195,
  //                   child: pw.Text(
  //                     tr('total'),
  //                     style: pw.TextStyle(font: fontBold, fontSize: 11),
  //                     textAlign: pw.TextAlign.right,
  //                   ),
  //                 ),
  //                 pw.Container(
  //                   width: 45,
  //                   child: pw.Text(
  //                     totalAmount.toStringAsFixed(2),
  //                     style: pw.TextStyle(font: fontBold, fontSize: 11),
  //                     textAlign: pw.TextAlign.right,
  //                   ),
  //                 ),
  //               ],
  //             ),

  //             pw.SizedBox(height: 10),
  //             pw.Text(
  //               tr('thanks'),
  //               style: pw.TextStyle(font: font, fontSize: 10),
  //             ),
  //             pw.Text(
  //               tr('visitAgain'),
  //               style: pw.TextStyle(font: font, fontSize: 10),
  //             ),

  //             if (widget.isTamil) ...[
  //               pw.SizedBox(height: 10),
  //               pw.Divider(),
  //               pw.Text(
  //                 widget.footerText1,
  //                 style: pw.TextStyle(font: font, fontSize: 8),
  //               ),
  //               pw.Text(
  //                 widget.footerText2,
  //                 style: pw.TextStyle(font: font, fontSize: 8),
  //               ),
  //               pw.Text(
  //                 widget.footerText3,
  //                 style: pw.TextStyle(font: font, fontSize: 8),
  //               ),
  //             ],
  //           ],
  //         );
  //       },
  //     ),
  //   );

  //   return pdf.save();
  // }

  Future<void> _saveReceiptToFirestore() async {
    if (!widget.isOnline) return;

    try {
      await _firestore.collection('receipts').add({
        'receiptNumber': widget.receiptNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'items': widget.cartItems
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
        'shopName': widget.isTamil
            ? widget.shopNameTamil
            : widget.shopNameEnglish,
        'language': widget.isTamil ? 'ta' : 'en',
      });
    } catch (e) {
      print('Error saving receipt to Firestore: $e');
    }
  }

  Future<void> _incrementReceiptNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('receiptNumber', widget.receiptNumber + 1);
    } catch (e) {
      print('Error incrementing receipt number: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${tr("cart")} (${widget.cartItems.length})'),
        actions: [
          if (widget.cartItems.isNotEmpty)
            TextButton(
              onPressed: _clearCart,
              child: Text(tr('clear'), style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 100,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 20),
                        Text(
                          tr('emptyCart'),
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.cartItems.length,
                    itemBuilder: (context, index) {
                      final item = widget.cartItems[index];
                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            widget.isTamil
                                ? item.product.tamilName
                                : item.product.name,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text(
                                '₹${item.product.price} × ${item.quantity}${item.product.unit}',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                                  '₹${item.total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: item.quantity == 1
                                          ? null
                                          : () => _updateQuantity(
                                              index,
                                              item.quantity - 1,
                                            ),
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.remove,
                                          size: 20,
                                          color: item.quantity == 1
                                              ? Colors.grey
                                              : Colors.orange,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        '${item.quantity.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _updateQuantity(
                                        index,
                                        item.quantity + 1,
                                      ),
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.add,
                                          size: 20,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeFromCart(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Total and Actions
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${tr("total")}:',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₹${totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.cartItems.isEmpty
                            ? null
                            : () => _generateAndActionPDF('print'),
                        icon: Icon(Icons.print),
                        label: Text(tr('printReceipt')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: widget.cartItems.isEmpty
                            ? Colors.grey[300]
                            : Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: widget.cartItems.isEmpty
                            ? null
                            : () => _generateAndActionPDF('save'),
                        icon: Icon(Icons.download, color: Colors.white),
                        tooltip: tr('saveReceipt'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: widget.cartItems.isEmpty
                            ? Colors.grey[300]
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: widget.cartItems.isEmpty
                            ? null
                            : () => _generateAndActionPDF('share'),
                        icon: Icon(Icons.share, color: Colors.white),
                        tooltip: tr('shareReceipt'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
