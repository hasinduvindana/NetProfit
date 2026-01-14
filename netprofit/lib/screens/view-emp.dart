import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewEmp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Current Employees")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('emp-data').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final firstName = data['first_name'] ?? 'N/A';
              final lastName = data['last_name'] ?? 'N/A';
              final salary = data['salary'] ?? 'N/A';
              
              return ListTile(
                title: Text("$firstName $lastName"),
                subtitle: Text("Salary: LKR $salary"),
                trailing: Icon(Icons.edit, color: Colors.blue),
                onTap: () => _showEditDeleteDialog(context, doc),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _showEditDeleteDialog(BuildContext context, DocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: Colors.orange),
              title: Text("Edit Data"),
              onTap: () { /* Logic to open edit form */ },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text("Delete Employee"),
              onTap: () async {
                await FirebaseFirestore.instance.collection('emp-data').doc(doc.id).delete();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Deleted Successfully")));
              },
            ),
          ],
        ),
      ),
    );
  }
}