import 'package:computer_based_test/database/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:computer_based_test/database/accountcreation.dart';
import 'package:computer_based_test/database/mcq_result_db.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'dart:io';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  final TextEditingController _searchController = TextEditingController();
  // New state variable to track the loading status for PDF generation
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await Database_helper.instance.getAllSummaries();
    List<Map<String, dynamic>> mergedData = [];

    for (var row in data) {
      final empId = row['empId'];
      final empInfo = await Database_helper.instance.getEmployeeById(empId);

      final mergedRow = {
        ...row,
        'department': empInfo?['department'] ?? '',
        'image_path': empInfo?['image_path'] ?? '',
      };

      mergedData.add(mergedRow);
    }

    setState(() {
      _allData = mergedData;
      _filteredData = mergedData;
    });
  }

  void _filterByEmpId(String empId) {
    setState(() {
      _filteredData = _allData
          .where((row) =>
              row['empId'].toString().toLowerCase().contains(empId.toLowerCase()))
          .toList();
    });
  }

  Future<void> _generatePdf(Map<String, dynamic> row) async {
    // 1. Set loading state and show a loading dialog
    setState(() {
      _isGeneratingPdf = true;
    });

    // Show a persistent loading dialog right away
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents closing by tapping outside
      builder: (context) => const AlertDialog(
        title: Text('Generating PDF'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text('Please wait...'),
          ],
        ),
      ),
    );

    // After showing the dialog, the first Navigator.of(context).pop()
    // will dismiss it.
    
    try {
      final pdf = pw.Document();
      const PdfColor primaryColor = PdfColor.fromInt(0xFF1A237E);
      const PdfColor secondaryColor = PdfColor.fromInt(0xFF3F51B5);
      const PdfColor textColor = PdfColor.fromInt(0xFF333333);
      const PdfColor passColor = PdfColor.fromInt(0xFF4CAF50);
      const PdfColor failColor = PdfColor.fromInt(0xFFF44336);

      pw.Widget imageWidget = pw.Container(
        height: 100,
        width: 100,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey, width: 1),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Text("No Image",
              style: pw.TextStyle(color: PdfColors.grey, fontSize: 12)),
        ),
      );

      final String? absoluteImagePath = row['image_path'];
      if (absoluteImagePath != null && absoluteImagePath.isNotEmpty) {
        try {
          final imageFile = File(absoluteImagePath);
          if (await imageFile.exists()) {
            final image = pw.MemoryImage(await imageFile.readAsBytes());
            imageWidget = pw.Container(
              height: 120,
              width: 150,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Image(image, fit: pw.BoxFit.cover),
            );
          }
        } catch (e) {
          debugPrint('Failed to load image for PDF: $e');
        }
      }

      final isPass = (row['status'] ?? '').toString().toLowerCase() == 'pass';

      pdf.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
          ),
          build: (pw.Context context) {
            final double? percentage = double.tryParse(row['percentage']?.toString() ?? '0');
            final String formattedPercentage =
                percentage != null ? percentage.toStringAsFixed(2) : '0.00';

            return pw.Container(
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: primaryColor, width: 2),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Employee MCQ Test Report',
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Visteon India Pvt. Ltd.',
                          style: pw.TextStyle(
                            fontSize: 16,
                            color: const PdfColor.fromInt(0xFFFF9800),
                          ),
                        ),
                        pw.SizedBox(height: 15),
                        pw.Divider(thickness: 1, color: secondaryColor),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _pdfDetailText("Employee ID",
                                row['empId']?.toString() ?? '', textColor),
                            _pdfDetailText(
                                "Name", row['empName']?.toString() ?? '', textColor),
                            _pdfDetailText(
                                "Department", row['department']?.toString() ?? '', textColor),
                            _pdfDetailText("Module", row['module']?.toString() ?? '', textColor),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 20),
                      pw.Expanded(flex: 1, child: imageWidget),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.Divider(thickness: 1, color: secondaryColor),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Test Results',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  _pdfDetailText("Score", row['score']?.toString() ?? '', textColor),
                  _pdfDetailText("Percentage", "$formattedPercentage%", textColor),
                  pw.Row(
                    children: [
                      pw.Text('Status: ',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, color: textColor)),
                      pw.Text(
                        row['status']?.toString() ?? 'N/A',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: isPass ? passColor : failColor,
                        ),
                      ),
                    ],
                  ),
                  _pdfDetailText("Date", row['date']?.toString() ?? '', textColor),
                  pw.SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      );

      final documentsDir = await getApplicationDocumentsDirectory();
      final folderPath = path.join(documentsDir.path, 'MCQ_VIS_Results');
      final directory = Directory(folderPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filePath = path.join(
        folderPath,
        "${row['empId']}_${row['module']}_${DateTime.now().microsecondsSinceEpoch}_mcq_report.pdf"
            .replaceAll(" ", "_"),
      );

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // 2. Dismiss the loading dialog *before* showing the success dialog
      // We check if the widget is still mounted before interacting with the UI
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss the loading dialog

      // 3. Show the success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('PDF Downloaded'),
          content: Text('✅ PDF saved to: $filePath'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
       // Catch any error during PDF generation/saving
      debugPrint('Error generating PDF: $e');

      // Dismiss the loading dialog on error
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss the loading dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: const Text('❌ Failed to generate PDF.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      // 4. Clear the loading state
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  pw.Widget _pdfDetailText(String label, String value, PdfColor textColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          text: '$label: ',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: textColor,
            fontSize: 14,
          ),
          children: [
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.normal,
                color: textColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee MCQ Report'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search by Employee ID:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onChanged: _filterByEmpId,
              decoration: const InputDecoration(
                hintText: 'Enter emp_id...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Report Table:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _filteredData.isEmpty
                  ? const Center(child: Text('No data found.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(Colors.indigo.shade100),
                          dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.indigo.shade50;
                              }
                              return Colors.grey.shade100;
                            },
                          ),
                          columns: const [
                            DataColumn(label: Text('SN')),
                            DataColumn(label: Text('Emp ID')),
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Image')),
                            DataColumn(label: Text('Dept')),
                            DataColumn(label: Text('Module')),
                            DataColumn(label: Text('Score')),
                            DataColumn(label: Text('Percentage')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('PDF')),
                          ],
                          rows: _filteredData.asMap().entries.map((entry) {
                            int index = entry.key;
                            Map<String, dynamic> row = entry.value;

                            final sn = _filteredData.length - index;

                            final isPass = row['status']?.toString().toLowerCase() == 'pass';
                            final String? absoluteImagePath = row['image_path'];
                            
                            final double? percentage = double.tryParse(row['percentage']?.toString() ?? '0');
                            final String formattedPercentage = percentage != null
                                ? percentage.toStringAsFixed(2)
                                : '0.00';

                            return DataRow(cells: [
                              DataCell(Text(sn.toString())),
                              DataCell(Text(row['empId'] ?? '')),
                              DataCell(Text(row['empName'] ?? '')),
                              DataCell(
                                (absoluteImagePath != null && File(absoluteImagePath).existsSync())
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(absoluteImagePath),
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.image_not_supported,
                                        color: Colors.grey),
                              ),
                              DataCell(Text(row['department'] ?? '')),
                              DataCell(Text(row['module'] ?? '')),
                              DataCell(Text('${row['score'] ?? 0}')),
                              DataCell(Text('$formattedPercentage%')),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isPass
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    row['status'] ?? '',
                                    style: TextStyle(
                                      color: isPass
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(row['date'] ?? '')),
                              DataCell(
                                IconButton(
                                  icon: _isGeneratingPdf
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.download, color: Colors.blue),
                                  // Disable button while loading
                                  onPressed: _isGeneratingPdf 
                                    ? null 
                                    : () => _generatePdf(row),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}