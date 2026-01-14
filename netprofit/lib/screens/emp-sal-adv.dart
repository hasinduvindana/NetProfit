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

class EmpSalAdv extends StatefulWidget {
  const EmpSalAdv({super.key});

  @override
  _EmpSalAdvState createState() => _EmpSalAdvState();
}

class _EmpSalAdvState extends State<EmpSalAdv> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final LocalAuthentication _auth = LocalAuthentication();

  DateTime _selectedDate = DateTime.now();
  bool _isMonthFilter = false;

  String _getFingerprintHash() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return sha256.convert(utf8.encode(user.uid)).toString();
  }

  // --- SUBMISSION LOGIC ---
  Future<void> _handleConfirm() async {
    if (_nameController.text.isEmpty || _amountController.text.isEmpty) {
      _showSnackBar("Please fill in all required fields", Colors.red);
      return;
    }

    double advanceAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (advanceAmount <= 0) {
      _showSnackBar("Invalid amount format", Colors.red);
      return;
    }

    try {
      bool canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) {
        await _processAdvance(advanceAmount, "Admin");
        return;
      }

      bool authenticated = await _auth.authenticate(
        localizedReason: 'Scan fingerprint to confirm salary advance',
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
          await _processAdvance(advanceAmount, adminName);
        } else {
          _showSnackBar("Fingerprint not recognized", Colors.red);
        }
      }
    } on PlatformException catch (e) {
      _showSnackBar("Security Error: ${e.message}", Colors.red);
    }
  }

  Future<void> _processAdvance(double advanceAmount, String confirmedBy) async {
    final DateTime now = DateTime.now();
    try {
      await FirebaseFirestore.instance.collection('sal-adv').add({
        'name': _nameController.text,
        'description': _descController.text,
        'amount': advanceAmount,
        'date_time': FieldValue.serverTimestamp(),
        'confirmed_by': confirmedBy,
        'year': now.year,
        'month': now.month,
        'day': now.day,
      });

      await _updateGeneralMonthlyExpense(now.year, now.month, advanceAmount);
      await _updateEmployeeSalaryInfo(confirmedBy, advanceAmount);

      _showSnackBar("Inserted Successfully", Colors.green);
      _nameController.clear(); _amountController.clear(); _descController.clear();
      setState(() {});
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  Future<void> _updateGeneralMonthlyExpense(int year, int month, double amount) async {
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

  Future<void> _updateEmployeeSalaryInfo(String firstName, double amount) async {
    final DateTime now = DateTime.now();
    final String currentYM = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    var query = await FirebaseFirestore.instance
        .collection('salary-info')
        .where('first_name', isEqualTo: firstName)
        .where('year_month', isEqualTo: currentYM)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({
        'expenses': FieldValue.increment(amount),
        'balance_amount': FieldValue.increment(-amount),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await _createNewMonthWithDebt(firstName, amount, currentYM);
    }
  }

  Future<void> _createNewMonthWithDebt(String fName, double amount, String ym) async {
    var lastRecord = await FirebaseFirestore.instance
        .collection('salary-info')
        .where('first_name', isEqualTo: fName)
        .orderBy('year_month', descending: true)
        .limit(1)
        .get();

    var emp = await FirebaseFirestore.instance
        .collection('emp-data')
        .where('first_name', isEqualTo: fName)
        .limit(1)
        .get();

    double baseSal = double.tryParse(emp.docs.first['salary'].toString()) ?? 0.0;
    double debt = 0.0;

    if (lastRecord.docs.isNotEmpty) {
      double bal = (lastRecord.docs.first['balance_amount'] ?? 0.0).toDouble();
      if (bal < 0) debt = bal.abs();
    }

    double totalExp = debt + amount;

    await FirebaseFirestore.instance.collection('salary-info').add({
      'first_name': fName,
      'year_month': ym,
      'base_salary': baseSal,
      'expenses': totalExp,
      'balance_amount': baseSal - totalExp,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- PDF GENERATION WITH NULL SAFETY ---
  Future<void> _generatePdf(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    final logo = await imageFromAssetBundle('assets/images/logo-rounded.png');
    double total = docs.fold(0, (sum, item) => sum + (item['amount'] as num).toDouble());

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) => pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(logo, width: 60),
              pw.Text("Rukmal Fish Delivery - Salary Advance", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Recipient', 'Amount', 'By'],
            data: docs.map((d) {
              // Safe timestamp check for PDF
              final Timestamp? ts = d['date_time'];
              final dateString = ts != null 
                  ? "${ts.toDate().day}/${ts.toDate().month}" 
                  : "Pending";
              return [dateString, d['name'], d['amount'], d['confirmed_by']];
            }).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Total: LKR ${total.toStringAsFixed(2)}")),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text("Salary Advance", style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0A1F44), Color(0xFF0C305F)]))),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildGlassyCard(),
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

  Widget _buildGlassyCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.18))),
          child: Column(
            children: [
              _buildInput("Recipient Name", _nameController, TextInputType.name),
              _buildInput("Amount (LKR)", _amountController, TextInputType.number),
              _buildInput("Description", _descController, TextInputType.multiline, maxLines: 2),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _buildBtn("Clear", Colors.grey, () => setState(() { _nameController.clear(); _amountController.clear(); _descController.clear(); }))),
                const SizedBox(width: 10),
                Expanded(child: _buildBtn("Confirm", Colors.green, _handleConfirm)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    Query query = FirebaseFirestore.instance.collection('sal-adv')
        .where('year', isEqualTo: _selectedDate.year)
        .where('month', isEqualTo: _selectedDate.month);
    if (!_isMonthFilter) query = query.where('day', isEqualTo: _selectedDate.day);

    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("History", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Row(children: [
            Switch(value: _isMonthFilter, onChanged: (v) => setState(() => _isMonthFilter = v)),
            IconButton(icon: const Icon(Icons.calendar_month, color: Colors.white), onPressed: () async {
              DateTime? p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2025), lastDate: DateTime(2100));
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
                columns: const [DataColumn(label: Text("Date")), DataColumn(label: Text("Recipient")), DataColumn(label: Text("LKR")), DataColumn(label: Text("By"))],
                rows: docs.map((d) => DataRow(cells: [
                  // Safe Null Check for Table Rendering
                  DataCell(
                    Builder(builder: (context) {
                      final dynamic ts = d['date_time'];
                      if (ts == null) return const Text("...", style: TextStyle(color: Colors.white70));
                      final DateTime dt = (ts as Timestamp).toDate();
                      return Text("${dt.day}/${dt.month}", style: const TextStyle(color: Colors.white));
                    }),
                  ),
                  DataCell(Text("${d['name']}", style: const TextStyle(color: Colors.white))),
                  DataCell(Text("${d['amount']}", style: const TextStyle(color: Colors.white))),
                  DataCell(Text("${d['confirmed_by']}", style: const TextStyle(color: Colors.white))),
                ])).toList(),
              )),
              if (docs.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 15),
                child: ElevatedButton.icon(onPressed: () => _generatePdf(docs), icon: const Icon(Icons.download), label: const Text("Download PDF")),
              ),
            ]);
          },
        ),
      ],
    );
  }

  Widget _buildInput(String l, TextEditingController c, TextInputType t, {int maxLines = 1}) {
    return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.2))),
    child: TextField(controller: c, keyboardType: t, maxLines: maxLines, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: l, labelStyle: const TextStyle(color: Colors.white70), border: InputBorder.none, contentPadding: const EdgeInsets.all(15))));
  }

  Widget _buildBtn(String l, Color col, VoidCallback p) {
    return ElevatedButton(onPressed: p, style: ElevatedButton.styleFrom(backgroundColor: col, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text(l, style: const TextStyle(color: Colors.white)));
  }

  void _showSnackBar(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }
}