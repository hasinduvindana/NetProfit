import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

class IceCostPage extends StatefulWidget {
  @override
  _IceCostPageState createState() => _IceCostPageState();
}

class _IceCostPageState extends State<IceCostPage> {
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final LocalAuthentication _auth = LocalAuthentication();

  // Generates hash to match against emp-data collection
  String _getFingerprintHash() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return sha256.convert(utf8.encode(user.uid)).toString();
  }

  Future<void> _handleSubmit() async {
    if (_qtyController.text.isEmpty || _amountController.text.isEmpty) {
      _showSnackBar("Please fill required fields", Colors.red);
      return;
    }

    try {
    // Check if the device has biometrics set up (fingerprints registered)
    bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    bool isBiometricSupported = await _auth.isDeviceSupported();
    bool canCheck = canAuthenticateWithBiometrics || isBiometricSupported;

    if (!canCheck) {
      _showSnackBar("Please set up a fingerprint/lock on your device first.", Colors.orange);
      return;
    }

    // Attempt authentication
    bool authenticated = await _auth.authenticate(
      localizedReason: 'Scan fingerprint to confirm Ice Payment',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true, // Helps prevent the "Security credentials not available" drop
      ),
    );

    if (authenticated) {
      // ... same logic to save data ...
    }
  } on PlatformException catch (e) {
    if (e.code == 'NotAvailable') {
      _showSnackBar("Biometrics not available. Please check device security settings.", Colors.red);
    } else {
      _showSnackBar("Error: ${e.message}", Colors.red);
    }
  }
  }

  Future<void> _processPayment(String adminName) async {
    final double amount = double.parse(_amountController.text);
    final double qty = double.parse(_qtyController.text);
    final DateTime now = DateTime.now();

    // 1. Add to ice-cost collection
    await FirebaseFirestore.instance.collection('ice-cost').add({
      'date_time': FieldValue.serverTimestamp(),
      'quantity': qty,
      'amount': amount,
      'description': _descController.text,
      'confirmed_by': adminName,
      'year': now.year,
      'month': now.month,
    });

    // 2. Update monthly total
    await _updateMonthlyTotal(now.year, now.month, amount);

    _showSnackBar("Payment Recorded Successfully", Colors.green);
    Future.delayed(Duration(seconds: 2), () => Navigator.pop(context));
  }

  Future<void> _updateMonthlyTotal(int year, int month, double amount) async {
    var query = await FirebaseFirestore.instance
        .collection('monthly-tot-exp')
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      var doc = query.docs.first;
      await doc.reference.update({
        'total-exp': FieldValue.increment(amount),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await FirebaseFirestore.instance.collection('monthly-tot-exp').add({
        'year': year,
        'month': month,
        'total-exp': amount,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      appBar: AppBar(title: Text("Payments for ICE"), backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildGlassyInput("Quantity (Boxes)", _qtyController, TextInputType.numberWithOptions(decimal: true)),
            _buildGlassyInput("Amount (LKR)", _amountController, TextInputType.number),
            _buildGlassyInput("Description (Optional)", _descController, TextInputType.text, maxLines: 3),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () => setState(() { _qtyController.clear(); _amountController.clear(); _descController.clear(); }), child: Text("Clear")),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: _handleSubmit, child: Text("Submit")),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGlassyInput(String label, TextEditingController controller, TextInputType type, {int maxLines = 1}) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          contentPadding: EdgeInsets.all(15),
        ),
      ),
    );
  }
}