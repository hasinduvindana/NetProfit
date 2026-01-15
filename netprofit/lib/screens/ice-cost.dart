import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:convert'; // Required for utf8 encoding
import 'package:crypto/crypto.dart'; // Required for SHA-256 hashing
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class IceCostPage extends StatefulWidget {
  const IceCostPage({super.key});

  @override
  _IceCostPageState createState() => _IceCostPageState();
}

class _IceCostPageState extends State<IceCostPage> {
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isMonthFilter = false;

  // SHA-256 Hashing for PIN comparison
  String _hashPin(String pin) {
    var bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  // --- SUBMISSION LOGIC ---
  Future<void> _handleSubmit() async {
    if (_qtyController.text.isEmpty || _amountController.text.isEmpty) {
      _showSnackBar("Please fill Quantity and Amount", Colors.red);
      return;
    }
    
    // Directly move to PIN input as requested
    await _promptForPinDirectly();
  }

  Future<void> _promptForPinDirectly() async {
    final TextEditingController pinEntryController = TextEditingController();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Authorize Ice Payment"),
        content: TextField(
          controller: pinEntryController,
          obscureText: true, // Secure PIN entry
          maxLength: 4,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Enter your 4-digit PIN"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              String enteredHash = _hashPin(pinEntryController.text.trim());
              
              // Verify PIN against 'emp-data' collection
              var query = await FirebaseFirestore.instance
                  .collection('emp-data')
                  .where('pin', isEqualTo: enteredHash)
                  .limit(1)
                  .get();

              if (query.docs.isNotEmpty) {
                String authorizingName = query.docs.first['first_name'];
                Navigator.pop(context); // Close PIN dialog
                await _processPayment(authorizingName);
              } else {
                _showSnackBar("Invalid PIN. Access Denied.", Colors.red);
              }
            },
            child: const Text("Verify & Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment(String adminName) async {
    try {
      final double amount = double.tryParse(_amountController.text) ?? 0.0;
      final double qty = double.tryParse(_qtyController.text) ?? 0.0;
      final DateTime now = DateTime.now();

      // 1. Add record to 'ice-cost'
      await FirebaseFirestore.instance.collection('ice-cost').add({
        'quantity': qty,
        'amount': amount,
        'description': _descController.text,
        'date_time': FieldValue.serverTimestamp(),
        'confirmed_by': adminName,
        'year': now.year,
        'month': now.month,
        'day': now.day,
      });

      // 2. Update the total monthly expense (Fixed logic)
      await _updateMonthlyExpense(now.year, now.month, amount);

      _showSnackBar("Payment recorded by $adminName", Colors.green);
      _qtyController.clear(); 
      _amountController.clear(); 
      _descController.clear();
      setState(() {}); // Refresh the history stream
    } catch (e) {
      _showSnackBar("Processing Error: $e", Colors.red);
    }
  }

  Future<void> _updateMonthlyExpense(int year, int month, double amount) async {
    // Exact match query for Year/Month integers
    var query = await FirebaseFirestore.instance
        .collection('monthly-tot-exp')
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      // Use atomic increment to prevent update conflicts
      await query.docs.first.reference.update({
        'total-exp': FieldValue.increment(amount),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      // Create record if this is the first expense of the month
      await FirebaseFirestore.instance.collection('monthly-tot-exp').add({
        'year': year, 
        'month': month, 
        'total-exp': amount, 
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  // --- PDF GENERATION ---
  Future<void> _generatePdf(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    double total = docs.fold(0, (sum, item) => sum + (item['amount'] as num).toDouble());

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("ICE PAYMENT REPORT", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text("Rukmal Fish Delivery"),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Qty', 'Amount', 'By'],
            data: docs.map((doc) {
              final Timestamp? ts = doc['date_time'];
              final date = ts != null ? ts.toDate() : DateTime.now();
              return ["${date.day}/${date.month}", doc['quantity'], doc['amount'], doc['confirmed_by']];
            }).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Total: LKR ${total.toStringAsFixed(2)}")),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text("Ice Cost Management", style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0D47A1), Colors.black]))),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildGlassyInput("Quantity (Boxes)", _qtyController, TextInputType.number),
                  _buildGlassyInput("Amount (LKR)", _amountController, TextInputType.number),
                  _buildGlassyInput("Description", _descController, TextInputType.text, maxLines: 2),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _buildActionButton("Clear", Colors.grey, () => setState(() { _qtyController.clear(); _amountController.clear(); _descController.clear(); })),
                    _buildActionButton("Submit", Colors.green, _handleSubmit),
                  ]),
                  const SizedBox(height: 30),
                  _buildHistorySection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    Query query = FirebaseFirestore.instance.collection('ice-cost')
        .where('year', isEqualTo: _selectedDate.year)
        .where('month', isEqualTo: _selectedDate.month);
    
    if (!_isMonthFilter) query = query.where('day', isEqualTo: _selectedDate.day);

    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("History", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Row(children: [
            Switch(value: _isMonthFilter, onChanged: (v) => setState(() => _isMonthFilter = v)),
            IconButton(icon: const Icon(Icons.calendar_today, color: Colors.white), onPressed: () async {
              DateTime? p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2100));
              if (p != null) setState(() => _selectedDate = p);
            }),
          ]),
        ]),
        StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            
            if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("No history found", style: TextStyle(color: Colors.white70)));

            // Fixed DataCell rendering for Pixel 7 performance
            return Column(children: [
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                columns: const [DataColumn(label: Text("Date")), DataColumn(label: Text("Qty")), DataColumn(label: Text("LKR")), DataColumn(label: Text("By"))],
                rows: docs.map((d) {
                  // Pre-extract data to avoid redundant work inside the build loop
                  final Timestamp? ts = d['date_time'];
                  final dateStr = ts != null ? "${ts.toDate().day}/${ts.toDate().month}" : "...";
                  
                  return DataRow(cells: [
                    DataCell(Text(dateStr, style: const TextStyle(color: Colors.white))),
                    DataCell(Text("${d['quantity']}", style: const TextStyle(color: Colors.white))),
                    DataCell(Text("${d['amount']}", style: const TextStyle(color: Colors.white))),
                    DataCell(Text("${d['confirmed_by']}", style: const TextStyle(color: Colors.white))),
                  ]);
                }).toList(),
              )),
              if (docs.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 15),
                child: ElevatedButton.icon(onPressed: () => _generatePdf(docs), icon: const Icon(Icons.picture_as_pdf), label: const Text("Download PDF")),
              ),
            ]);
          },
        ),
      ],
    );
  }

  Widget _buildGlassyInput(String label, TextEditingController controller, TextInputType type, {int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15), 
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
      child: TextField(
        controller: controller, 
        keyboardType: type, 
        maxLines: maxLines, 
        style: const TextStyle(color: Colors.white), 
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white70), border: InputBorder.none, contentPadding: const EdgeInsets.all(15))
      )
    );
  }

  Widget _buildActionButton(String label, Color col, VoidCallback p) {
    return ElevatedButton(
      onPressed: p, 
      style: ElevatedButton.styleFrom(backgroundColor: col, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)), 
      child: Text(label, style: const TextStyle(color: Colors.white))
    );
  }

  void _showSnackBar(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }
}