import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_screen.dart';
import 'manage-emp.dart';
import 'view-emp.dart';
import 'salary_status.dart'; // Add this with your other imports
import 'expenses.dart'; // Add this with your other imports



class AdminDashboard extends StatelessWidget {
  final String userName;

  const AdminDashboard({Key? key, required this.userName}) : super(key: key);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  String _getGreetingImage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'assets/morning.png';
    } else if (hour < 17) {
      return 'assets/afternoon.png';
    } else {
      return 'assets/evening.png';
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      print('Logout error: $e');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Greeting Header with Image
          Container(
            width: double.infinity,
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Image
                Image.asset(
                  _getGreetingImage(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade300, Colors.blue.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(Icons.wb_sunny, size: 100, color: Colors.white),
                    );
                  },
                ),
                // Overlay gradient for better text visibility
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.1),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Text Overlay
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getGreeting()}, $userName!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black.withOpacity(0.5),
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black.withOpacity(0.5),
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Dashboard Content
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildListTile(
                  icon: Icons.badge,
                  title: 'Manage Employee',
                  color: Colors.blueAccent,
                  onTap: () => Navigator.push(context, _createRoute(ManageEmp())),
                ),
                SizedBox(height: 12),
                _buildListTile(
                  icon: Icons.group,
                  title: 'Current Employees',
                  color: Colors.teal,
                  onTap: () => Navigator.push(context, _createRoute(ViewEmp())),
                ),
                SizedBox(height: 12),
                _buildListTile(
                icon: Icons.monetization_on,
                title: 'Salary Status',
                color: Colors.orangeAccent,
                onTap: () => Navigator.push(context, _createRoute(SalaryStatusPage())), // Ensure you import this page
                ),

                SizedBox(height: 12),
                _buildListTile(
                  icon: Icons.account_balance_wallet,
                  title: 'Manage Expenses',
                  color: Colors.redAccent,
                  onTap: () => Navigator.push(context, _createRoute(ExpensesPage())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Icon(Icons.arrow_forward, color: color),
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.ease));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }
}
