import 'dart:io';
import 'package:flutter/material.dart';
import 'package:computer_based_test/database/database_helper.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VisionReportPage extends StatefulWidget {
  const VisionReportPage({super.key});

  @override
  State<VisionReportPage> createState() => _VisionReportPageState();
}

class _VisionReportPageState extends State<VisionReportPage> {
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  final TextEditingController _searchController = TextEditingController();

  // Map to track the loading state for each report row
  // Key: Unique row ID (e.g., combination of empId and date)
  // Value: bool (true if loading)
  final Map<String, bool> _isGeneratingPdf = {};

  // Helper to create a unique ID for a report row
  String _getReportKey(Map<String, dynamic> row) {
    return '${row['employee_id']}-${row['module']}-${row['date']}';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Get vision exam summaries from the database
      final db = await Database_helper.instance.database;
      final summaryResults = await db.query('vision_exam_summary');

      final employees = await Database_helper.instance.getAllEmployees();

      final employeeMap = {
        for (var e in employees) e['employee_id'].toString().trim(): e,
      };

      final mergedData = summaryResults.map((summary) {
        final empId = summary['empId'].toString().trim();
        final empDetails = employeeMap[empId];

        return {
          'employee_id': summary['empId'],
          'employee_name': empDetails?['employee_name'] ?? 'N/A',
          'department': empDetails?['department'] ?? 'N/A',
          'image_path': empDetails?['image_path'],
          'module': summary['module'],
          'score': summary['score'],
          'percentage': summary['percentage'],
          'status': summary['status'],
          'date': summary['date'],
        };
      }).toList();

      setState(() {
        _allData = mergedData;
        _filteredData = mergedData;
      });
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading report data')),
        );
      }
    }
  }

  void _filterByEmpId(String empId) {
    setState(() {
      _filteredData = _allData
          .where((row) => row['employee_id']
              .toString()
              .toLowerCase()
              .contains(empId.toLowerCase()))
          .toList();
    });
  }

  Future<File?> _getEmployeeImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    // Try direct path first
    File file = File(imagePath);
    if (await file.exists()) return file;

    // Try C:\CBT path (common for Windows desktop apps)
    file = File('C:\\CBT\\$imagePath');
    if (await file.exists()) return file;

    return null;
  }

  Future<void> _generatePdf(Map<String, dynamic> row) async {
    final reportKey = _getReportKey(row);
    if (_isGeneratingPdf[reportKey] == true) return; // Prevent double tap

    // 1. Set loading state for this specific row and rebuild the widget
    setState(() {
      _isGeneratingPdf[reportKey] = true;
    });

    // 2. Show a persistent loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
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

    try {
      final pdf = pw.Document();

      const PdfColor primaryColor = PdfColor.fromInt(0xFF1A237E);
      const PdfColor secondaryColor = PdfColor.fromInt(0xFF3F51B5);
      const PdfColor textColor = PdfColor.fromInt(0xFF333333);
      const PdfColor passColor = PdfColor.fromInt(0xFF4CAF50);
      const PdfColor failColor = PdfColor.fromInt(0xFFF44336);

      // Image handling logic
      pw.Widget imageWidget;
      final String? imagePath = row['image_path'];
      File? imageFile = await _getEmployeeImage(imagePath);

      if (imageFile != null && await imageFile.exists()) {
        final imageBytes = await imageFile.readAsBytes();
        final image = pw.MemoryImage(imageBytes);
        imageWidget = pw.Container(
          height: 120,
          width: 150,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey, width: 1),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Image(image, fit: pw.BoxFit.cover),
        );
      } else {
        imageWidget = pw.Container(
          height: 100,
          width: 100,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey, width: 1),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Center(
            child: pw.Text(
              "No Image",
              style: pw.TextStyle(color: PdfColors.grey, fontSize: 12),
            ),
          ),
        );
      }

      final isPass = (row['status']?.toString().toLowerCase().trim() == 'passed');

      pdf.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData(
              defaultTextStyle: pw.TextStyle(
                font: pw.Font.courier(),
              ),
            ),
          ),
          build: (pw.Context context) {
            final double? percentage = double.tryParse(row['percentage']?.toString() ?? '0');
            final String formattedPercentage = percentage != null ? percentage.toStringAsFixed(2) : '0.00';

            return pw.Container(
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: primaryColor, width: 2),
                borderRadius: pw.BorderRadius.circular(10),
                color: PdfColors.white,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Vision Test Report',
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
                            _pdfDetailText("Employee ID", row['employee_id'].toString(), textColor),
                            _pdfDetailText("Name", row['employee_name'], textColor),
                            _pdfDetailText("Department", row['department'], textColor),
                            _pdfDetailText("Module", row['module'], textColor),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 20),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Container(
                              width: 100,
                              height: 100,
                              child: imageWidget,
                            ),
                          ],
                        ),
                      ),
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
                  pw.SizedBox(height: 10),
                  _pdfDetailText("Score", row['score'].toString(), textColor),
                  _pdfDetailText("Percentage", "$formattedPercentage%", textColor),
                  pw.Row(
                    children: [
                      pw.Text('Status: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: textColor, fontSize: 14)),
                      pw.Text(
                        row['status'] ?? 'N/A',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: isPass ? passColor : failColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  _pdfDetailText("Date", row['date'], textColor),
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

      final fileName =
          "${row['employee_id']}_${row['module']}_${DateTime.now().microsecondsSinceEpoch}_vision_report.pdf"
              .replaceAll(" ", "_");
      final filePath = path.join(folderPath, fileName);
      
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // 3. Dismiss the loading dialog
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog

      // 4. Show the success dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('PDF Downloaded'),
            content: Text('✅ PDF saved to:\n${file.path}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('PDF generation error: $e');
      if (!mounted) return;

      // Dismiss the loading dialog on error
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error generating PDF: ${e.toString()}')),
      );
    } finally {
      // 5. Reset loading state
      if (mounted) {
        setState(() {
          _isGeneratingPdf.remove(reportKey);
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
        title: const Text('Vision Report Page'),
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
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _filteredData.isEmpty
                      ? const Center(child: Text('No data found.'))
                      : DataTable(
                          headingRowColor: MaterialStateProperty.all(Colors.indigo.shade100),
                          dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.selected)) {
                                return Colors.indigo.shade50;
                              }
                              return Colors.grey.shade100;
                            },
                          ),
                          columns: const [
                            DataColumn(label: Text('SN', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Emp ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Image', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Dept', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Module', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Score', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Percentage', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('PDF', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _filteredData.asMap().entries.map((entry) {
                            int index = entry.key;
                            Map<String, dynamic> row = entry.value;
                            final sn = _filteredData.length - index;
                            final isPass = (row['status']?.toString().toLowerCase().trim() == 'passed');
                            final imagePath = row['image_path'];
                            final reportKey = _getReportKey(row);
                            final isLoading = _isGeneratingPdf[reportKey] == true;

                            final percentage = double.tryParse(row['percentage'].toString())?.toStringAsFixed(2) ?? '0.00';

                            return DataRow(cells: [
                              DataCell(Text(sn.toString())),
                              DataCell(Text(row['employee_id'] ?? '')),
                              DataCell(Text(row['employee_name'] ?? '')),
                              DataCell(
                                imagePath != null
                                    ? FutureBuilder<File?>(
                                        future: _getEmployeeImage(imagePath),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                                            return ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.file(
                                                snapshot.data!,
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                              ),
                                            );
                                          } else {
                                            return const Icon(Icons.image_not_supported, color: Colors.grey);
                                          }
                                        },
                                      )
                                    : const Icon(Icons.image_not_supported, color: Colors.grey),
                              ),
                              DataCell(Text(row['department'] ?? '')),
                              DataCell(Text(row['module'] ?? '')),
                              DataCell(Text('${row['score'] ?? 0}')),
                              DataCell(Text(
                                '$percentage%',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              )),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPass ? Colors.green.shade100 : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    row['status'] ?? '',
                                    style: TextStyle(
                                      color: isPass ? Colors.green.shade800 : Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(row['date'] ?? '')),
                              DataCell(
                                IconButton(
                                  icon: isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.download, color: Colors.blue),
                                  // Disable button while loading
                                  onPressed: isLoading
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