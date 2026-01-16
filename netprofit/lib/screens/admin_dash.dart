import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'login_screen.dart';
import 'manage-emp.dart';
import 'view-emp.dart';
import 'salary_status.dart';
import 'expenses.dart';

class AdminDashboard extends StatelessWidget {
  final String userName;

  const AdminDashboard({Key? key, required this.userName}) : super(key: key);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getGreetingImage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'assets/morning.png';
    if (hour < 17) return 'assets/afternoon.png';
    return 'assets/evening.png';
  }

  // --- UPDATED LOGOUT LOGIC ---
  Future<void> _logout(BuildContext context) async {
    // 1. Show the glassy logout dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.blueAccent),
              const SizedBox(height: 20),
              const Text(
                "Logging out...",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // 2. Wait for 3 seconds as requested
      await Future.delayed(const Duration(seconds: 3));

      // 3. Perform actual sign out
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();

      // 4. Redirect to login screen
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('NetProfit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.white.withOpacity(0.05),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => _logout(context)),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildHeader(),
                const SizedBox(height: 20),
                
                // 2x2 Grid Arrangement
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.1,
                    children: [
                      _GlassyGridButton(
                        icon: Icons.badge,
                        title: 'Manage Emp',
                        onTap: () => Navigator.push(context, _createRoute(ManageEmp())),
                      ),
                      _GlassyGridButton(
                        icon: Icons.group,
                        title: 'Current Emp',
                        onTap: () => Navigator.push(context, _createRoute(ViewEmp())),
                      ),
                      _GlassyGridButton(
                        icon: Icons.monetization_on,
                        title: 'Salary Status',
                        onTap: () => Navigator.push(context, _createRoute(SalaryStatusPage())),
                      ),
                      _GlassyGridButton(
                        icon: Icons.account_balance_wallet,
                        title: 'Expenses',
                        onTap: () => Navigator.push(context, _createRoute(ExpensesPage())),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                _buildStatsSection(now),
                const SizedBox(height: 30),
                _buildFooter(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(DateTime now) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Monthly Overview", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24, height: 25),
                _buildStatItem("Total Employee Count", FirebaseFirestore.instance.collection('emp-data').snapshots(), isCount: true),
                _buildStatItem("Salary Advance Payments", FirebaseFirestore.instance.collection('sal-adv')
                    .where('year', isEqualTo: now.year).where('month', isEqualTo: now.month).snapshots()),
                _buildStatItem("Payments for ICE", FirebaseFirestore.instance.collection('ice-cost')
                    .where('year', isEqualTo: now.year).where('month', isEqualTo: now.month).snapshots()),
                _buildStatItem("Payments for Fuel", FirebaseFirestore.instance.collection('fuel-cost')
                    .where('year', isEqualTo: now.year).where('month', isEqualTo: now.month).snapshots()),
                _buildStatItem("Other Payments", FirebaseFirestore.instance.collection('other-cost')
                    .where('year', isEqualTo: now.year).where('month', isEqualTo: now.month).snapshots()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, Stream<QuerySnapshot> stream, {bool isCount = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        String value = "...";
        if (snapshot.hasData) {
          if (isCount) {
            value = snapshot.data!.docs.length.toString();
          } else {
            double total = snapshot.data!.docs.fold(0.0, (sum, doc) => sum + (doc['amount'] ?? 0.0));
            value = "LKR ${total.toStringAsFixed(2)}";
          }
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text("© ${DateTime.now().year} CoderixSoft Technologies", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        const SizedBox(height: 4),
        Text("Version 1.0.0", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 120,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [
            Image.asset(_getGreetingImage(), width: double.infinity, height: double.infinity, fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.blueGrey.shade800)),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), border: Border.all(color: Colors.white.withOpacity(0.2))),
                child: Row(
                  children: [
                    CircleAvatar(radius: 30, backgroundColor: Colors.blueAccent.withOpacity(0.6),
                      child: Text(userName[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 15),
                    Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getGreeting(), style: const TextStyle(color: Colors.white70, fontSize: 16)),
                        Text(userName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child));
  }
}

class _GlassyGridButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _GlassyGridButton({required this.icon, required this.title, required this.onTap});
  @override State<_GlassyGridButton> createState() => _GlassyGridButtonState();
}

class _GlassyGridButtonState extends State<_GlassyGridButton> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: InkWell(
              onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: _isHovered ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: Colors.blueAccent, size: 35),
                    const SizedBox(height: 10),
                    Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}