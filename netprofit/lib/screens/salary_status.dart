import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalaryStatusPage extends StatefulWidget {
  const SalaryStatusPage({super.key});

  @override
  State<SalaryStatusPage> createState() => _SalaryStatusPageState();
}

class _SalaryStatusPageState extends State<SalaryStatusPage> {
  DateTime _selectedDate = DateTime.now();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: "LKR ", decimalDigits: 2);

  String get _currentYearMonth => "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}";

  // --- LOGIC: 25th Day Transition ---
  // This logic is triggered when viewing the dashboard to ensure the next month is initialized
  Future<void> _checkAndInitializeNextMonth() async {
    final now = DateTime.now();
    // Logic: If today is 25th or later, ensure next month row exists
    if (now.day >= 25) {
      final nextMonthDate = DateTime(now.year, now.month + 1, 1);
      final nextYM = "${nextMonthDate.year}-${nextMonthDate.month.toString().padLeft(2, '0')}";
      
      final employees = await FirebaseFirestore.instance.collection('emp-data').get();
      
      for (var empDoc in employees.docs) {
        final fName = empDoc['first_name'];
        final baseSal = double.tryParse(empDoc['salary'].toString()) ?? 0.0;

        // Check if next month already exists
        final existing = await FirebaseFirestore.instance.collection('salary-info')
            .where('first_name', isEqualTo: fName)
            .where('year_month', isEqualTo: nextYM)
            .limit(1).get();

        if (existing.docs.isEmpty) {
          // Get current month balance to check for debt
          final currentYM = "${now.year}-${now.month.toString().padLeft(2, '0')}";
          final currentRecord = await FirebaseFirestore.instance.collection('salary-info')
              .where('first_name', isEqualTo: fName)
              .where('year_month', isEqualTo: currentYM)
              .limit(1).get();

          double debt = 0.0;
          if (currentRecord.docs.isNotEmpty) {
            double balance = (currentRecord.docs.first['balance_amount'] ?? 0.0).toDouble();
            if (balance < 0) {
              debt = balance.abs(); // Logic: Carry forward negative balance as expense
            } else {
              // Logic: At 24th midnight (effectively 25th), add positive balances to total expenses
              await _updateMonthlyTotalExpense(now.year, now.month, balance);
            }
          }

          // Create new row for next month
          await FirebaseFirestore.instance.collection('salary-info').add({
            'first_name': fName,
            'year_month': nextYM,
            'base_salary': baseSal,
            'expenses': debt, // Add previous negative balance to expenses
            'balance_amount': baseSal - debt,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }

  Future<void> _updateMonthlyTotalExpense(int year, int month, double amount) async {
    final query = await FirebaseFirestore.instance.collection('monthly-tot-exp')
        .where('year', isEqualTo: year).where('month', isEqualTo: month).limit(1).get();

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({
        'total-exp': FieldValue.increment(amount),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await FirebaseFirestore.instance.collection('monthly-tot-exp').add({
        'year': year, 'month': month, 'total-exp': amount, 'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Salary Status"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search, color: Colors.blue),
                const SizedBox(width: 10),
                Text("Viewing: $_currentYearMonth", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('salary-info')
                  .where('year_month', isEqualTo: _currentYearMonth)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index];
                    double balance = (data['balance_amount'] ?? 0.0).toDouble();
                    double base = (data['base_salary'] ?? 0.0).toDouble();
                    double exp = (data['expenses'] ?? 0.0).toDouble();

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['first_name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const Divider(),
                            _buildSalaryRow("Base Salary", _currencyFormat.format(base), Colors.yellow.shade800),
                            _buildSalaryRow("Expenses", _currencyFormat.format(exp), Colors.red),
                            _buildSalaryRow(
                              "Balance", 
                              _currencyFormat.format(balance), 
                              balance >= 0 ? Colors.green : Colors.red,
                              isBold: true
                            ),
                            const SizedBox(height: 5),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                "Updated: ${data['timestamp'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((data['timestamp'] as Timestamp).toDate()) : 'Pending'}",
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _checkAndInitializeNextMonth(),
        label: const Text("Run 25th Logic"),
        icon: const Icon(Icons.sync),
      ),
    );
  }

  Widget _buildSalaryRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
        ],
      ),
    );
  }
}