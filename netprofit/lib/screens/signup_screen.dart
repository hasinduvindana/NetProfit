import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glass_container.dart';
import '../widgets/fish_animation.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fName = TextEditingController();
  final TextEditingController _lName = TextEditingController();
  final TextEditingController _email = TextEditingController();

  void _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(child: CircularProgressIndicator()),
        );

        // Create user account with Firebase Auth using anonymous sign-in
        UserCredential userCredential = await FirebaseAuth.instance
            .signInAnonymously();

        // After successful authentication, save user data to Firestore
        await FirebaseFirestore.instance
            .collection('user-data')
            .doc(userCredential.user!.uid)
            .set({
          'first_name': _fName.text.trim(),
          'last_name': _lName.text.trim(),
          'email': _email.text.trim(),
          'user-name': _fName.text.trim(),
          'user-type': 'admin',
          'uid': userCredential.user!.uid,
          'created_at': FieldValue.serverTimestamp(),
        });

        // Close loading dialog
        Navigator.pop(context);
        
        // Show success popup
        _showSuccessPopup();
      } catch (e) {
        // Close loading dialog if it's open
        Navigator.pop(context);
        
        // Show error popup
        _showErrorPopup('Registration failed: ${e.toString()}');
      }
    }
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            SizedBox(height: 16),
            Text(
              "Registration Successful!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
    
    // Wait 3 seconds, then close dialog and go back to login
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pop(context); // Close success dialog
      Navigator.pop(context); // Go back to login screen
    });
  }

  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text("Registration Failed", style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(image: DecorationImage(image: AssetImage("assets/login-bg.jpg"), fit: BoxFit.cover))),
          
          // Animated Swimming Fish
          SwimmingFish(fishImage: 'assets/fish1.png'),
          SwimmingFish(fishImage: 'assets/fish2.png'),
          SwimmingFish(fishImage: 'assets/fish3.png'),
          SwimmingFish(fishImage: 'assets/fish4.png'),
          
          Center(
            child: GlassContainer(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Register", style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _fName,
                      decoration: InputDecoration(labelText: "First Name"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: _lName,
                      decoration: InputDecoration(labelText: "Last Name"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: _email,
                      decoration: InputDecoration(labelText: "Gmail Address"),
                      validator: (v) {
                        if (v == null || !v.endsWith("@gmail.com")) return "Only Gmail allowed";
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(onPressed: _register, child: Text("Register Now")),
                    TextButton(onPressed: () => Navigator.pop(context), child: Text("Back to Login", style: TextStyle(color: Colors.white)))
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}