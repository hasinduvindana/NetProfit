import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FuelCostPage extends StatefulWidget {
  const FuelCostPage({super.key});

  @override
  _FuelCostPageState createState() => _FuelCostPageState();
}

class _FuelCostPageState extends State<FuelCostPage> {
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final LocalAuthentication _auth = LocalAuthentication();

  String _fuelType = "Diesel"; // Default value
  DateTime _selectedDate = DateTime.now();
  bool _isMonthFilter = false;

  String _getFingerprintHash() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return sha256.convert(utf8.encode(user.uid)).toString();
  }

  // --- SUBMISSION LOGIC ---
  Future<void> _handleSubmit() async {
    if (_amountController.text.isEmpty) {
      _showSnackBar("Please enter the amount", Colors.red);
      return;
    }

    try {
      bool canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) {
        _showSnackBar("Biometrics not available", Colors.orange);
        return;
      }

      bool authenticated = await _auth.authenticate(
        localizedReason: 'Scan fingerprint to confirm Fuel Payment',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );

      if (authenticated) {
        String hashedVal = _getFingerprintHash();
        var empQuery = await FirebaseFirestore.instance
            .collection('emp-data')
            .where('fingerprint', isEqualTo: hashedVal)
            .limit(1)
            .get();

        if (empQuery.docs.isNotEmpty) {
          String adminName = empQuery.docs.first['first_name'];
          await _processPayment(adminName);
        } else {
          _showSnackBar("Fingerprint not recognized", Colors.red);
        }
      }
    } on PlatformException catch (e) {
      _showSnackBar("Security Error: ${e.message}", Colors.red);
    }
  }

  Future<void> _processPayment(String adminName) async {
    final double amount = double.parse(_amountController.text);
    final DateTime now = DateTime.now();

    await FirebaseFirestore.instance.collection('fuel-cost').add({
      'vehicle_no': _vehicleController.text.isEmpty ? "N/A" : _vehicleController.text,
      'fuel_type': _fuelType,
      'amount': amount,
      'description': _descController.text,
      'date_time': FieldValue.serverTimestamp(),
      'confirmed_by': adminName,
      'year': now.year,
      'month': now.month,
      'day': now.day,
    });

    await _updateMonthlyExpense(now.year, now.month, amount);
    _showSnackBar("Fuel Record Saved Successfully", Colors.green);
    _vehicleController.clear(); _amountController.clear(); _descController.clear();
    setState(() {});
  }

  Future<void> _updateMonthlyExpense(int year, int month, double amount) async {
    var query = await FirebaseFirestore.instance
        .collection('monthly-tot-exp')
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .limit(1)
        .get();

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

  // --- PDF GENERATION ---
  Future<void> _generatePdf(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    final logo = await imageFromAssetBundle('assets/images/logo-rounded.png');
    double total = docs.fold(0, (sum, item) => sum + (item['amount'] as num).toDouble());

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(logo, width: 60, height: 60),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text("Rukmal Fish Delivery", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text("Fuel Report Downloaded: ${DateTime.now().toString().split('.')[0]}"),
                pw.Text("Filter Mode: ${_isMonthFilter ? 'Monthly' : 'Daily'}"),
              ]),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Vehicle', 'Type', 'Amount', 'By'],
            data: docs.map((doc) {
              final date = (doc['date_time'] as Timestamp).toDate();
              return ["${date.day}/${date.month}/${date.year}", doc['vehicle_no'], doc['fuel_type'], doc['amount'], doc['confirmed_by']];
            }).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Total Fuel Cost: LKR ${total.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Fuel_Payment_History.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text("Payments for Fuel", style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.orange.shade900, Colors.black]))),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildGlassyInput("Vehicle Number (Optional)", _vehicleController, TextInputType.text),
                  
                  // Fuel Type Selection
                  Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Fuel Type", style: TextStyle(color: Colors.white70)),
                        DropdownButton<String>(
                          value: _fuelType,
                          dropdownColor: Colors.grey.shade900,
                          style: const TextStyle(color: Colors.white),
                          underline: Container(),
                          items: ["Diesel", "Petrol"].map((String value) {
                            return DropdownMenuItem<String>(value: value, child: Text(value));
                          }).toList(),
                          onChanged: (String? newValue) => setState(() => _fuelType = newValue!),
                        ),
                      ],
                    ),
                  ),

                  _buildGlassyInput("Amount (LKR)", _amountController, TextInputType.number),
                  _buildGlassyInput("Description (Optional)", _descController, TextInputType.text, maxLines: 2),
                  
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _buildActionButton("Clear", Colors.grey, () => setState(() { _vehicleController.clear(); _amountController.clear(); _descController.clear(); })),
                    _buildActionButton("Submit", Colors.green, _handleSubmit),
                  ]),
                  
                  const SizedBox(height: 30),
                  const Divider(color: Colors.white24),
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
    Query query = FirebaseFirestore.instance.collection('fuel-cost')
        .where('year', isEqualTo: _selectedDate.year)
        .where('month', isEqualTo: _selectedDate.month);
    
    if (!_isMonthFilter) query = query.where('day', isEqualTo: _selectedDate.day);

    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Fuel History", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Row(children: [
            const Text("Month", style: TextStyle(color: Colors.white70, fontSize: 12)),
            Switch(value: _isMonthFilter, onChanged: (v) => setState(() => _isMonthFilter = v)),
            IconButton(icon: const Icon(Icons.calendar_today, color: Colors.white, size: 20), onPressed: () async {
              DateTime? p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2100));
              if (p != null) setState(() => _selectedDate = p);
            }),
          ]),
        ]),
        StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final docs = snapshot.data!.docs;
            return Column(children: [
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                columns: const [
                  DataColumn(label: Text("Vehicle", style: TextStyle(color: Colors.white))),
                  DataColumn(label: Text("LKR", style: TextStyle(color: Colors.white))),
                  DataColumn(label: Text("By", style: TextStyle(color: Colors.white)))
                ],
                rows: docs.map((d) => DataRow(cells: [
                  DataCell(Text("${d['vehicle_no']}", style: const TextStyle(color: Colors.white))),
                  DataCell(Text("${d['amount']}", style: const TextStyle(color: Colors.white))),
                  DataCell(Text("${d['confirmed_by']}", style: const TextStyle(color: Colors.white))),
                ])).toList(),
              )),
              if (docs.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: ElevatedButton.icon(onPressed: () => _generatePdf(docs), icon: const Icon(Icons.download), label: const Text("Download PDF"), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey)),
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
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller, 
        keyboardType: type, 
        maxLines: maxLines, 
        style: const TextStyle(color: Colors.white), 
        decoration: InputDecoration(
          labelText: label, 
          labelStyle: const TextStyle(color: Colors.white70), 
          border: InputBorder.none, 
          contentPadding: const EdgeInsets.all(15)
        )
      )
    );
  }

  Widget _buildActionButton(String label, Color col, VoidCallback p) {
    return ElevatedButton(onPressed: p, style: ElevatedButton.styleFrom(backgroundColor: col, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text(label, style: const TextStyle(color: Colors.white)));
  }

  void _showSnackBar(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }
}