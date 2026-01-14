import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'emp-sal-adv.dart';
import 'ice-cost.dart';
import 'fuel-cost.dart';
import 'other-cost.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Expenses", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // 1. Deep Ocean Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade900, Colors.black],
              ),
            ),
          ),
          
          // 2. Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Latest Total Expense Display
                  _buildTotalExpenseHeader(),
                  
                  const SizedBox(height: 40),
                  
                  // Navigation Buttons
                  _buildGlassyButton(
                    context, 
                    "Salary Advances", 
                    Icons.payments_outlined, 
                    Colors.purpleAccent, 
                    EmpSalAdv()
                  ),
                  _buildGlassyButton(
                    context, 
                    "Ice Cost", 
                    Icons.ac_unit, 
                    Colors.lightBlueAccent, 
                    IceCostPage()
                  ),
                  _buildGlassyButton(
                    context, 
                    "Fuel Cost", 
                    Icons.local_gas_station, 
                    Colors.orangeAccent, 
                    FuelCostPage()
                  ),
                  _buildGlassyButton(
                    context, 
                    "Other Expenses", 
                    Icons.more_horiz, 
                    Colors.blueGrey, 
                    OtherCostPage()
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fetches the latest updated record from the monthly-tot-exp collection
  Widget _buildTotalExpenseHeader() {
    return StreamBuilder<QuerySnapshot>(
      // Sort by a single timestamp field instead of year+month for better performance
      stream: FirebaseFirestore.instance
          .collection('monthly-tot-exp')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // This usually indicates the Composite Index is still building
          return const Center(
            child: Text(
              "Waiting for Firestore Index...", 
              style: TextStyle(color: Colors.white70, fontSize: 14)
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        }

        String totalDisplay = "LKR. 0.00";

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final doc = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          
          // Extracts 'total-exp' column value from the latest row
          final num totalValue = doc['total-exp'] ?? 0;
          totalDisplay = "LKR. ${totalValue.toDouble().toStringAsFixed(2)}";
          
          // Ensure timestamp field exists for future queries
          if (!doc.containsKey('timestamp')) {
            snapshot.data!.docs.first.reference.update({
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }

        return Container(
          padding: const EdgeInsets.all(25),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              const Text(
                "Total Monthly Expenses", 
                style: TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 1.2)
              ),
              const SizedBox(height: 12),
              Text(
                totalDisplay, 
                style: const TextStyle(
                  color: Colors.redAccent, 
                  fontSize: 34, 
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(2, 2))]
                )
              ),
            ],
          ),
        );
      },
    );
  }

  /// Custom Glassy Button Widget
  Widget _buildGlassyButton(BuildContext context, String title, IconData icon, Color iconColor, Widget? targetPage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: InkWell(
            onTap: () {
              if (targetPage != null) {
                Navigator.push(context, _createSlideRoute(targetPage));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("$title page coming soon!")),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    title, 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Slide Animation for Navigation
  Route _createSlideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutQuart;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }
}