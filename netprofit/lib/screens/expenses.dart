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
                  
                  const SizedBox(height: 30),
                  
                  // Navigation Grid (2x2 Arrangement)
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.1,
                      children: [
                        _buildGlassyGridButton(
                          context, 
                          "Salary\nAdvances", 
                          Icons.payments_outlined, 
                          Colors.purpleAccent, 
                          EmpSalAdv()
                        ),
                        _buildGlassyGridButton(
                          context, 
                          "Ice\nCost", 
                          Icons.ac_unit, 
                          Colors.lightBlueAccent, 
                          IceCostPage()
                        ),
                        _buildGlassyGridButton(
                          context, 
                          "Fuel\nCost", 
                          Icons.local_gas_station, 
                          Colors.orangeAccent, 
                          FuelCostPage()
                        ),
                        _buildGlassyGridButton(
                          context, 
                          "Other\nExpenses", 
                          Icons.more_horiz, 
                          Colors.blueGrey, 
                          OtherCostPage()
                        ),
                      ],
                    ),
                  ),

                  // 3. Footer Copyright Section
                  _buildFooter(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalExpenseHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('monthly-tot-exp')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        }

        String totalDisplay = "LKR. 0.00";

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final doc = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final num totalValue = doc['total-exp'] ?? 0;
          totalDisplay = "LKR. ${totalValue.toDouble().toStringAsFixed(2)}";
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
                  fontSize: 32, 
                  fontWeight: FontWeight.bold,
                )
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassyGridButton(BuildContext context, String title, IconData icon, Color iconColor, Widget page) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: () => Navigator.push(context, _createSlideRoute(page)),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  title, 
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 16, 
                    fontWeight: FontWeight.w600,
                    height: 1.2
                  )
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          "© ${DateTime.now().year} CoderixSoft Technologies",
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Version 1.0.0",
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

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