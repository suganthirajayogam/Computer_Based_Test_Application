import 'package:computer_based_test/database/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:computer_based_test/database/accountcreation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ViewEmployeeDatabaseScreen extends StatefulWidget {
  const ViewEmployeeDatabaseScreen({super.key});

  @override
  State<ViewEmployeeDatabaseScreen> createState() =>
      _ViewEmployeeDatabaseScreenState();
}

class _ViewEmployeeDatabaseScreenState
    extends State<ViewEmployeeDatabaseScreen> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
    _searchController.addListener(_searchEmployee);
  }

  @override
  void dispose() {
    _searchController.removeListener(_searchEmployee);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    try {
      final data = await Database_helper.instance.getAllEmployees();
      setState(() {
        _employees = data;
        _filteredEmployees = data;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching employees: $e");
    }
  }

  void _searchEmployee() {
    final query = _searchController.text.trim();
    setState(() {
      _filteredEmployees = query.isEmpty
          ? _employees
          : _employees
              .where((emp) => emp['employee_id']
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()))
              .toList();
    });
  }

  Future<void> _confirmDelete(
      BuildContext context, String empId, VoidCallback onDeleted) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Confirmation'),
          content: const Text('Are you sure you want to delete this employee?\n\nThis will also delete all their exam records (MCQ & Vision).'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final db = await Database_helper.instance.database;
        
        // Delete from all related tables
        await db.delete('mcq_exam_results', where: 'empId = ?', whereArgs: [empId]);
        await db.delete('mcq_exam_summary', where: 'empId = ?', whereArgs: [empId]);
        await db.delete('vision_exam_results', where: 'empId = ?', whereArgs: [empId]);
        await db.delete('vision_exam_summary', where: 'empId = ?', whereArgs: [empId]);
        
        // Delete employee
        final rowsDeleted = await Database_helper.instance.deleteEmployee(empId.toString());
        
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(rowsDeleted > 0 ? 'Success' : 'Failed'),
            content: Text(rowsDeleted > 0
                ? 'Employee and all related exam records deleted successfully.'
                : 'Failed to delete the employee.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        if (rowsDeleted > 0) {
          onDeleted();
        }
      }
    } catch (e) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error'),
          content: Text('An error occurred while deleting:\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _editEmployee(Map<String, dynamic> emp) async {
    final empIdController = TextEditingController(text: emp['employee_id']);
    final nameController = TextEditingController(text: emp['employee_name']);
    final deptController = TextEditingController(text: emp['department']);
    String? currentImagePath = emp['image_path'];
    String? newImagePath;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Employee'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: empIdController,
                    decoration: const InputDecoration(labelText: 'Employee ID'),
                    readOnly: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: deptController,
                    decoration: const InputDecoration(labelText: 'Department'),
                  ),
                  const SizedBox(height: 20),
                  const Text('Employee Image:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (newImagePath != null || (currentImagePath != null && currentImagePath!.isNotEmpty))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(newImagePath ?? currentImagePath!),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    const Icon(Icons.person, size: 100, color: Colors.grey),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      if (result != null && result.files.single.path != null) {
                        setDialogState(() {
                          newImagePath = result.files.single.path;
                        });
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Change Image'),
                  ),
                  if (currentImagePath != null && currentImagePath!.isNotEmpty || newImagePath != null)
                    TextButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          newImagePath = null;
                          currentImagePath = null;
                        });
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final db = await Database_helper.instance.database;
                    
                    String? finalImagePath = currentImagePath;
                    
                    // Handle new image upload
                    if (newImagePath != null) {
                      final dir = Directory('C:\\CBT\\Emp_Images');
                      if (!await dir.exists()) {
                        await dir.create(recursive: true);
                      }
                      
                      final empId = empIdController.text.trim();
                      final destPath = '${dir.path}\\$empId.jpg';
                      await File(newImagePath!).copy(destPath);
                      finalImagePath = destPath;
                    }
                    
                    // Update database
                    await db.update(
                      'emp_db',
                      {
                        'employee_name': nameController.text.trim(),
                        'department': deptController.text.trim(),
                        'image_path': finalImagePath ?? '',
                      },
                      where: 'employee_id = ?',
                      whereArgs: [empIdController.text.trim()],
                    );
                    
                    Navigator.pop(context);
                    _fetchEmployees();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Employee updated successfully')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating employee: $e')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Employee Database'),
        backgroundColor: Colors.indigo,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search by Employee ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('SN')),
                        DataColumn(label: Text('Emp ID')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Department')),
                        DataColumn(label: Text('Image')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: List<DataRow>.generate(
                        _filteredEmployees.length,
                        (index) {
                          final sn = _filteredEmployees.length - index;
                          final emp = _filteredEmployees[index];
                          final imagePath = emp['image_path']?.toString() ?? '';
                          final fullImagePath = imagePath.isNotEmpty ? imagePath : null;

                          return DataRow(
                            color: WidgetStateProperty.all(
                              index.isEven ? Colors.grey[100] : Colors.white,
                            ),
                            cells: [
                              DataCell(Text(sn.toString())),
                              DataCell(Text(emp['employee_id'].toString())),
                              DataCell(Text(emp['employee_name'] ?? '')),
                              DataCell(Text(emp['department'] ?? '')),
                              DataCell(
                                fullImagePath != null && File(fullImagePath).existsSync()
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(fullImagePath),
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.image_not_supported, color: Colors.grey),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _editEmployee(emp),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _confirmDelete(
                                        context,
                                        emp['employee_id'].toString(),
                                        () => _fetchEmployees(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}