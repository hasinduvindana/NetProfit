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

  Future<String> _getFingerprint() async {
    try {
      // Use a stable, user-bound identifier (UID) as the fingerprint token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return '';
      final uidHash = sha256.convert(utf8.encode(user.uid)).toString();
      return uidHash;
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

  Widget _buildGlassField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Employees")),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 360,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Add New Employee",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      _buildGlassField(
                        controller: fNameController,
                        label: "First Name",
                        icon: Icons.person,
                      ),
                      SizedBox(height: 14),
                      _buildGlassField(
                        controller: lNameController,
                        label: "Last Name",
                        icon: Icons.person_outline,
                      ),
                      SizedBox(height: 14),
                      _buildGlassField(
                        controller: emailController,
                        label: "Email (Optional)",
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(height: 14),
                      _buildGlassField(
                        controller: salaryController,
                        label: "Salary (LKR)",
                        icon: Icons.payments,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white70),
                              ),
                              onPressed: () {
                                fNameController.clear();
                                lNameController.clear();
                                emailController.clear();
                                salaryController.clear();
                              },
                              child: Text("Clear"),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: Icon(Icons.fingerprint),
                              label: Text("Save Employee"),
                              onPressed: () => _authenticateAndSave(context),
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
    );
  }
}