import 'package:billreciptapp/homescreen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(TamilReceiptApp());
}

class TamilReceiptApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ரசீது உருவாக்கி',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'NotoSansTamil'),
      home: ReceiptScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
