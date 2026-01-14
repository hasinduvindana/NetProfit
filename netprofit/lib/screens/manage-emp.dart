import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class ManageEmp extends StatelessWidget {
  final TextEditingController fNameController = TextEditingController();
  final TextEditingController lNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController salaryController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();

  void _showAddEmpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add New Employee"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: fNameController, decoration: InputDecoration(labelText: "First Name")),
              TextField(controller: lNameController, decoration: InputDecoration(labelText: "Last Name")),
              TextField(controller: emailController, decoration: InputDecoration(labelText: "Email (Optional)")),
              TextField(controller: salaryController, decoration: InputDecoration(labelText: "Salary (LKR)"), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () { fNameController.clear(); lNameController.clear(); }, child: Text("Clear")),
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(onPressed: () => _authenticateAndSave(context), child: Text("Add")),
        ],
      ),
    );
  }

  Future<String> _getFingerprint() async {
    try {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      bool isDeviceSupported = await auth.isDeviceSupported();
      
      if (!canCheckBiometrics || !isDeviceSupported) {
        return '';
      }
      
      List<BiometricType> availableBiometrics = await auth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        return '';
      }
      
      // Generate a unique fingerprint hash based on device and biometric
      String fingerprintData = availableBiometrics.toString() + DateTime.now().toString();
      String fingerprint = sha256.convert(utf8.encode(fingerprintData)).toString();
      
      return fingerprint;
    } catch (e) {
      print('Error getting fingerprint: $e');
      return '';
    }
  }

  Future<void> _authenticateAndSave(BuildContext context) async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Scan fingerprint to add new employee',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      if (authenticated) {
        // Get fingerprint hash
        String fingerprint = await _getFingerprint();
        
        // Add employee with fingerprint
        await FirebaseFirestore.instance.collection('emp-data').add({
          'first_name': fNameController.text,
          'last_name': lNameController.text,
          'email': emailController.text,
          'salary': salaryController.text,
          'verified': true,
          'fingerprint': fingerprint,
          'created_at': FieldValue.serverTimestamp(),
          'created_by_fingerprint': true,
        });
        
        fNameController.clear();
        lNameController.clear();
        emailController.clear();
        salaryController.clear();
        
        Navigator.pop(context);
        _showSuccessSnippet(context);
      }
    } on Exception catch (e) {
      print('Authentication error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessSnippet(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text("Employee Added Successful")]),
        backgroundColor: Colors.white,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Employees")),
      body: Center(
        child: ElevatedButton.icon(
          icon: Icon(Icons.add),
          label: Text("Add New Employee"),
          onPressed: () => _showAddEmpDialog(context),
        ),
      ),
    );
  }
}