import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';

class ManageEmp extends StatelessWidget {
  final TextEditingController fNameController = TextEditingController();
  final TextEditingController lNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController salaryController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();

  ManageEmp({super.key});

  String _getFingerprintHash() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return sha256.convert(utf8.encode(user.uid)).toString();
  }

  Future<void> _authenticateAndSave(BuildContext context) async {
    if (fNameController.text.isEmpty || salaryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("First Name and Salary are required"), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Scan fingerprint to add new employee',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      
      if (authenticated) {
        String fingerprint = _getFingerprintHash();
        double salaryValue = double.parse(salaryController.text);
        String fName = fNameController.text;
        
        // 1. Save to emp-data
        await FirebaseFirestore.instance.collection('emp-data').add({
          'first_name': fName,
          'last_name': lNameController.text,
          'email': emailController.text,
          'salary': salaryController.text,
          'verified': true,
          'fingerprint': fingerprint,
          'created_at': FieldValue.serverTimestamp(),
        });
        
        // 2. Automatically initialize/update salary-info for current month
        await _initializeSalaryInfo(fName, salaryValue);
        
        fNameController.clear();
        lNameController.clear();
        emailController.clear();
        salaryController.clear();
        
        Navigator.pop(context);
        _showSuccessSnippet(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _initializeSalaryInfo(String firstName, double salary) async {
    final DateTime now = DateTime.now();
    // Format: 2026-01
    final String yearMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    // Check if a row already exists for this employee this month
    var query = await FirebaseFirestore.instance
        .collection('salary-info')
        .where('first_name', isEqualTo: firstName)
        .where('year_month', isEqualTo: yearMonth)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      // Create new row with default values
      await FirebaseFirestore.instance.collection('salary-info').add({
        'first_name': firstName,
        'year_month': yearMonth,
        'base_salary': salary,
        'expenses': 0.0,            // Default LKR 0.00
        'balance_amount': salary,   // Default: Full salary
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      // Update existing row base salary if needed
      await query.docs.first.reference.update({
        'base_salary': salary,
        'balance_amount': salary - (query.docs.first['expenses'] ?? 0.0),
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  void _showSuccessSnippet(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text("Employee & Salary Info Added")]),
        backgroundColor: Colors.white,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text("Manage Employees", style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, elevation: 0),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blueGrey.shade900, Colors.black], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 380,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.2))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text("Add New Employee", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                      const SizedBox(height: 25),
                      _buildGlassField(controller: fNameController, label: "First Name", icon: Icons.person),
                      const SizedBox(height: 15),
                      _buildGlassField(controller: lNameController, label: "Last Name", icon: Icons.person_outline),
                      const SizedBox(height: 15),
                      _buildGlassField(controller: emailController, label: "Email (Optional)", icon: Icons.email, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 15),
                      _buildGlassField(controller: salaryController, label: "Salary (LKR)", icon: Icons.payments, keyboardType: TextInputType.number),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)), onPressed: () => fNameController.clear(), child: const Text("Clear"))),
                          const SizedBox(width: 15),
                          Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white), icon: const Icon(Icons.fingerprint), label: const Text("Save"), onPressed: () => _authenticateAndSave(context))),
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
    );
  }

  Widget _buildGlassField({required TextEditingController controller, required String label, required IconData icon, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
      ),
    );
  }
}