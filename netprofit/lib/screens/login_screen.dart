import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glass_container.dart';
import '../widgets/fish_animation.dart';
import 'signup_screen.dart';
import 'admin_dash.dart';
import 'coadmin_dash.dart';
import 'user_dash.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _signInWithGoogle() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        Navigator.pop(context); 
        return; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      String userEmail = userCredential.user!.email!;

      QuerySnapshot querySnapshot = await _firestore
          .collection('user-data')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      Navigator.pop(context); 

      if (querySnapshot.docs.isEmpty) {
        _showErrorPopup('No account found with this email. Please sign up first.');
        await _auth.signOut();
        await GoogleSignIn().signOut();
        return;
      }

      var userData = querySnapshot.docs.first.data() as Map<String, dynamic>;
      String userType = userData['user-type'] ?? 'user';
      String userName = userData['user-name'] ?? 'User';

      _showSuccessPopup(userName, userType);

    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showErrorPopup('Login failed: ${e.toString()}');
    }
  }

  void _showSuccessPopup(String userName, String userType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            SizedBox(height: 16),
            Text(
              "Login Success!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (Navigator.canPop(context)) Navigator.pop(context);
      
      Widget dashboardPage;
      if (userType == 'admin') {
        dashboardPage = AdminDashboard(userName: userName);
      } else if (userType == 'co-admin') {
        dashboardPage = CoAdminDashboard(userName: userName);
      } else {
        dashboardPage = UserDashboard(userName: userName);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => dashboardPage),
      );
    });
  }

  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text("Login Failed", style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.blue)),
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
          // 1. Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/login-bg.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. Animated Fish Layers
          SwimmingFish(fishImage: 'assets/fish1.png'),
          SwimmingFish(fishImage: 'assets/fish2.png'),
          SwimmingFish(fishImage: 'assets/fish3.png'),
          SwimmingFish(fishImage: 'assets/fish4.png'),

          // 3. Main Content
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logo-rounded.png', width: 120),
                  const SizedBox(height: 10),
                  const Text(
                    "Fresh fish for best Prices",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: GlassContainer(
                      child: Column(
                        children: [
                          const Text(
                            "Login",
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 30),
                          
                          InkWell(
                            onTap: _signInWithGoogle,
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white30),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.login, color: Colors.white, size: 20),
                                  SizedBox(width: 10),
                                  Text("Signin with Google", style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SignUpScreen())),
                            child: const Text(
                              "Don't have an account? Sign Up",
                              style: TextStyle(color: Colors.white70, decoration: TextDecoration.underline),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Footer Copyright Claim [Added as requested]
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "© ${DateTime.now().year} CoderixSoft Technologies",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Version 1.0.0",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}