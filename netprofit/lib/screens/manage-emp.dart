import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // Required for utf8.encode
import 'package:crypto/crypto.dart'; // Required for sha256
import 'dart:ui';

class ManageEmp extends StatefulWidget {
  const ManageEmp({super.key});

  @override
  State<ManageEmp> createState() => _ManageEmpState();
}

class _ManageEmpState extends State<ManageEmp> {
  final TextEditingController fNameController = TextEditingController();
  final TextEditingController lNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController salaryController = TextEditingController();
  final TextEditingController pinController = TextEditingController();
  bool _pinVisible = false; // Toggle for PIN visibility

  // Hashing function: Converts the PIN into a secure 256-bit string
  String _hashPin(String pin) {
    var bytes = utf8.encode(pin); 
    return sha256.convert(bytes).toString(); 
  }

  // Ensures that the same hashed PIN does not already exist in the database
  Future<bool> _isPinUnique(String hashedPin) async {
    final query = await FirebaseFirestore.instance
        .collection('emp-data')
        .where('pin', isEqualTo: hashedPin)
        .limit(1)
        .get();
    return query.docs.isEmpty; 
  }

  Future<void> _saveEmployee(BuildContext context) async {
    String pin = pinController.text.trim();

    // Validation: Check for empty fields and 4-digit length
    if (fNameController.text.isEmpty || salaryController.text.isEmpty || pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields and a 4-digit PIN are required"), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      String hashedPin = _hashPin(pin);

      // Verify uniqueness
      bool unique = await _isPinUnique(hashedPin);
      if (!unique) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This PIN is already registered. Choose another."), backgroundColor: Colors.orange),
        );
        return;
      }

      // 1. Save to emp-data with hashed PIN
      await FirebaseFirestore.instance.collection('emp-data').add({
        'first_name': fNameController.text,
        'last_name': lNameController.text,
        'email': emailController.text,
        'salary': salaryController.text,
        'pin': hashedPin, // Never save plaintext PINs
        'created_at': FieldValue.serverTimestamp(),
      });

      // 2. Initialize salary-info
      await _initializeSalaryInfo(fNameController.text, double.parse(salaryController.text));

      Navigator.pop(context);
      _showSuccessSnippet(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _initializeSalaryInfo(String firstName, double salary) async {
    final DateTime now = DateTime.now();
    final String yearMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    var query = await FirebaseFirestore.instance
        .collection('salary-info')
        .where('first_name', isEqualTo: firstName)
        .where('year_month', isEqualTo: yearMonth)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      await FirebaseFirestore.instance.collection('salary-info').add({
        'first_name': firstName,
        'year_month': yearMonth,
        'base_salary': salary,
        'expenses': 0.0,
        'balance_amount': salary,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  void _showSuccessSnippet(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text("Employee & PIN Saved Successfully")]),
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
                      const Text("Register Employee", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                      const SizedBox(height: 25),
                      _buildGlassField(controller: fNameController, label: "First Name", icon: Icons.person),
                      const SizedBox(height: 15),
                      _buildGlassField(controller: lNameController, label: "Last Name", icon: Icons.person_outline),
                      const SizedBox(height: 15),
                      _buildGlassField(controller: emailController, label: "Email", icon: Icons.email),
                      const SizedBox(height: 15),
                      _buildGlassField(controller: salaryController, label: "Salary (LKR)", icon: Icons.payments, keyboardType: TextInputType.number),
                      const SizedBox(height: 15),
                      // PIN Field with toggle visibility
                      TextField(
                        controller: pinController,
                        obscureText: !_pinVisible, // Dynamically toggle
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "4-Digit PIN",
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                          suffixIcon: IconButton(
                            icon: Icon(_pinVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white70),
                            onPressed: () => setState(() => _pinVisible = !_pinVisible),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                        icon: const Icon(Icons.save),
                        label: const Text("Save Employee"),
                        onPressed: () => _saveEmployee(context),
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
      ),
    );
  }
}