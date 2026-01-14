import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';


class EmpSalAdv extends StatefulWidget {
  @override
  _EmpSalAdvState createState() => _EmpSalAdvState();
}

class _EmpSalAdvState extends State<EmpSalAdv> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final LocalAuthentication _auth = LocalAuthentication();

  // Stable fingerprint token: SHA-256 of current user's UID
  String _getFingerprintHash() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return sha256.convert(utf8.encode(user.uid)).toString();
  }

  Future<void> _handleConfirm() async {
    // Validate inputs
    if (_nameController.text.isEmpty || _amountController.text.isEmpty) {
      _showError("Please fill in all required fields");
      return;
    }

    double advanceAmount;
    try {
      advanceAmount = double.parse(_amountController.text);
    } catch (e) {
      _showError("Invalid amount format");
      return;
    }

    try {
      // Check if biometrics are available
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        // Fallback: Direct confirmation
        await _processAdvance(advanceAmount, "Admin");
        return;
      }

      bool authenticated = await _auth.authenticate(
        localizedReason: 'Scan fingerprint to confirm salary advance',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (authenticated) {
        String hashedVal = _getFingerprintHash();

        // Find employee in emp-data with matching fingerprint hash
        var empQuery = await FirebaseFirestore.instance
            .collection('emp-data')
            .where('fingerprint', isEqualTo: hashedVal)
            .limit(1)
            .get();

        if (empQuery.docs.isNotEmpty) {
          String adminName = empQuery.docs.first['first_name'];
          await _processAdvance(advanceAmount, adminName);
        } else {
          _showError("No matching employee found for this fingerprint.");
        }
      }
    } catch (e) {
      print("Biometric error: $e");
      // Fallback to direct confirmation
      await _processAdvance(advanceAmount, "Admin");
    }
  }

  Future<void> _processAdvance(double advanceAmount, String confirmedBy) async {
    try {
      DateTime now = DateTime.now();
      int year = now.year;
      int month = now.month;

      // Add to sal-adv collection
      await FirebaseFirestore.instance.collection('sal-adv').add({
        'name': _nameController.text,
        'description': _descController.text,
        'amount': advanceAmount,
        'date_time': FieldValue.serverTimestamp(),
        'confirmed_by': confirmedBy,
        'year': year,
        'month': month,
      });

      // Update monthly-tot-exp collection
      await _updateMonthlyExpense(year, month, advanceAmount);

      _showSuccessAndPop();
    } catch (e) {
      _showError("Error processing advance: $e");
    }
  }

  Future<void> _updateMonthlyExpense(int year, int month, double amount) async {
    try {
      // Check if document exists for this year and month
      var query = await FirebaseFirestore.instance
          .collection('monthly-tot-exp')
          .where('year', isEqualTo: year)
          .where('month', isEqualTo: month)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        // Document exists, increment total-exp
        var doc = query.docs.first;
        double currentExp = (doc.data()['total-exp'] ?? 0.0).toDouble();
        double newTotal = currentExp + amount;

        await FirebaseFirestore.instance
            .collection('monthly-tot-exp')
            .doc(doc.id)
            .update({
              'total-exp': newTotal,
              'timestamp': FieldValue.serverTimestamp(),
            });
      } else {
        // Create new document
        await FirebaseFirestore.instance.collection('monthly-tot-exp').add({
          'year': year,
          'month': month,
          'total-exp': amount,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print("Error updating monthly expense: $e");
    }
  }

  void _showSuccessAndPop() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Inserted Successful"), backgroundColor: Colors.green),
    );
    Future.delayed(Duration(seconds: 3), () => Navigator.pop(context));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Salary Advance", style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        children: [
          // Subtle gradient background to fit glass theme
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A1F44), Color(0xFF0C305F)],
              ),
            ),
          ),
          // Glassy card
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Request Details",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.95),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _glassField(
                            label: "Recipient Name",
                            controller: _nameController,
                            keyboardType: TextInputType.name,
                          ),
                          const SizedBox(height: 12),
                          _glassField(
                            label: "Advance Amount (LKR)",
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            prefix: "LKR ",
                          ),
                          const SizedBox(height: 12),
                          _glassField(
                            label: "Description (Optional)",
                            controller: _descController,
                            keyboardType: TextInputType.multiline,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Date: ${DateTime.now().toString().split('.')[0]}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _glassButton(
                                  label: "Clear",
                                  color: Colors.white.withOpacity(0.12),
                                  borderColor: Colors.white24,
                                  textColor: Colors.white,
                                  onTap: () {
                                    _nameController.clear();
                                    _amountController.clear();
                                    _descController.clear();
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _glassButton(
                                  label: "Cancel",
                                  color: Colors.white.withOpacity(0.08),
                                  borderColor: Colors.white24,
                                  textColor: Colors.white,
                                  onTap: () => Navigator.pop(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _glassButton(
                                  label: "Confirm",
                                  color: Colors.greenAccent.withOpacity(0.18),
                                  borderColor: Colors.greenAccent.withOpacity(0.4),
                                  textColor: Colors.white,
                                  onTap: _handleConfirm,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? prefix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        prefixText: prefix,
        prefixStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 1.6),
        ),
      ),
    );
  }

  Widget _glassButton({
    required String label,
    required Color color,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}