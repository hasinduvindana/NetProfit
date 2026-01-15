import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';

class ViewEmp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Current Employees"),
        backgroundColor: Colors.teal,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade900, Colors.teal.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder(
          stream: FirebaseFirestore.instance.collection('emp-data').snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  "No Employees Found",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              );
            }

            return ListView(
              padding: EdgeInsets.all(12),
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final firstName = data['first_name'] ?? 'N/A';
                final lastName = data['last_name'] ?? 'N/A';
                final email = data['email'] ?? 'N/A';
                final salary = data['salary'] ?? 'N/A';

                return _buildGlassCard(
                  context,
                  doc,
                  firstName,
                  lastName,
                  email,
                  salary,
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlassCard(
    BuildContext context,
    DocumentSnapshot doc,
    String firstName,
    String lastName,
    String email,
    String salary,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name (Bold & Large)
                Text(
                  "$firstName $lastName",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),

                // Email (Blue)
                if (email != 'N/A')
                  Text(
                    "📧 $email",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.lightBlue.shade200,
                    ),
                  ),
                SizedBox(height: 8),

                // Salary (Green)
                Text(
                  "💰 Salary: LKR $salary",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.greenAccent.shade200,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(Icons.edit),
                        label: Text("Edit"),
                        onPressed: () => _showEditDialog(context, doc, firstName, lastName, email, salary),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(Icons.delete),
                        label: Text("Delete"),
                        onPressed: () => _showDeleteConfirmation(context, doc),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    DocumentSnapshot doc,
    String firstName,
    String lastName,
    String email,
    String salary,
  ) {
    final TextEditingController firstNameController = TextEditingController(text: firstName);
    final TextEditingController lastNameController = TextEditingController(text: lastName);
    final TextEditingController emailController = TextEditingController(text: email);
    final TextEditingController salaryController = TextEditingController(text: salary);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text("Edit Employee Details"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(labelText: "First Name"),
              ),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(labelText: "Last Name"),
              ),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: salaryController,
                decoration: InputDecoration(labelText: "Salary (LKR)"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showUpdateConfirmation(
                context,
                doc,
                firstNameController.text,
                lastNameController.text,
                emailController.text,
                salaryController.text,
              );
            },
            child: Text("Update"),
          ),
        ],
      ),
    );
  }

  void _showUpdateConfirmation(
    BuildContext context,
    DocumentSnapshot doc,
    String firstName,
    String lastName,
    String email,
    String salary,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text("Confirm Update"),
        content: Text("Are you sure you want to update this employee's details?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updateEmployeeData(context, doc, firstName, lastName, email, salary);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEmployeeData(
    BuildContext context,
    DocumentSnapshot doc,
    String firstName,
    String lastName,
    String email,
    String salary,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('emp-data').doc(doc.id).update({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'salary': salary,
      });

      // Show success message with delay
      Future.delayed(Duration(milliseconds: 300), () {
        if (context.mounted) {
          _showSuccessMessage(context, "Employee Details Updated");
        }
      });
    } catch (e) {
      print('Update error: $e');
      
      Future.delayed(Duration(milliseconds: 300), () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating employee: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  void _showDeleteConfirmation(BuildContext context, DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
        title: Text("Are you sure?"),
        content: Text("Delete this Employee? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteEmployee(context, doc);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Yes, Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEmployee(BuildContext context, DocumentSnapshot doc) async {
    try {
      await FirebaseFirestore.instance.collection('emp-data').doc(doc.id).delete();
      
      // Show success message with delay
      Future.delayed(Duration(milliseconds: 300), () {
        if (context.mounted) {
          _showSuccessMessage(context, "Employee Deleted Successfully");
        }
      });
    } catch (e) {
      print('Delete error: $e');
      
      Future.delayed(Duration(milliseconds: 300), () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting employee: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text(message, style: TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: Duration(seconds: 3),
      ),
    );
  }
}