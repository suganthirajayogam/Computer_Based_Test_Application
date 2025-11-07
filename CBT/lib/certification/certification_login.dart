import 'package:computer_based_test/database/database_helper.dart';
import 'package:flutter/material.dart';

class CertificationLogin extends StatefulWidget {
  final void Function(bool) onToggleTheme;

  const CertificationLogin({Key? key, required this.onToggleTheme})
      : super(key: key);

  @override
  State<CertificationLogin> createState() => _CertificationLoginState();
}

class _CertificationLoginState extends State<CertificationLogin> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _empIdController = TextEditingController();
  final TextEditingController _empNameController = TextEditingController();

  List<String> modules = ['Select Module'];
  String? selectedModule = 'Select Module';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadModules();
  }

  Future<void> _loadModules() async {
    try {
      final fetchedModules = await Database_helper.instance.getVideoModules();
      final defaultModules = [];

      final combined = {
        ...defaultModules,
        ...fetchedModules,
      }.toList();

      setState(() {
        modules = ['Select Module', ...combined];
      });

      print('Modules loaded successfully: $modules');
    } catch (e) {
      print('Module loading failed: $e');
    }
  }

  void _autoFillName(String empId) async {
    if (empId.trim().isEmpty) return;
    final employee = await Database_helper.instance.getEmployeeById(empId);
    if (employee != null) {
      _empNameController.text = employee['employee_name'] ?? '';
    } else {
      _empNameController.clear();
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final empId = _empIdController.text.trim();

      if (selectedModule == null || selectedModule == 'Select Module') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid module.')),
        );
        return;
      }

      if (_empNameController.text.trim().isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Employee Not Found'),
              ],
            ),
            content: const Text(
              'Please enter a valid Employee ID. No name found in database.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final employee = await Database_helper.instance.getEmployeeById(empId);
      if (employee == null) return;

      final rowsAffected =
          await Database_helper.instance.updateModule(empId, selectedModule!);

      if (rowsAffected > 0) {
        Navigator.pushNamed(
      context,
      '/certification_testpage',
      arguments: {
        'employee': {
          'employeeId': _empIdController.text.trim(),
          'employeeName': _empNameController.text.trim(),
          'module': selectedModule,
        },
        'module': selectedModule,
      },
    );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7EEFF),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 79, 14, 109),
        title: const Text('VISTEON'),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              'Certification Login',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 100, 6, 162),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _empIdController,
                            onChanged: _autoFillName,
                            decoration: const InputDecoration(
                              labelText: 'Employee ID',
                              hintText: 'Eg. 1234',
                              labelStyle: TextStyle(fontSize: 14),
                              hintStyle: TextStyle(fontSize: 13),
                              prefixIcon: Icon(Icons.badge, size: 20),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Enter Employee ID'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _empNameController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Employee Name',
                              hintText: 'Auto-filled from DB',
                              labelStyle: TextStyle(fontSize: 14),
                              hintStyle: TextStyle(fontSize: 13),
                              prefixIcon: Icon(Icons.person, size: 20),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Select Module',
                                style: TextStyle(fontSize: 14),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh,
                                    color: Colors.indigo),
                                tooltip: 'Refresh Modules',
                                onPressed: () async {
                                  await _loadModules();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Modules refreshed')),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedModule,
                            decoration: const InputDecoration(
                              labelStyle: TextStyle(fontSize: 14),
                              prefixIcon: Icon(Icons.category, size: 20),
                              border: OutlineInputBorder(),
                            ),
                            items: modules.map((module) {
                              return DropdownMenuItem<String>(
                                value: module,
                                child: Text(module),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedModule = value!;
                              });
                            },
                            validator: (value) =>
                                value == null || value == 'Select Module'
                                    ? 'Select a module'
                                    : null,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                              foregroundColor: const Color.fromARGB(255, 63, 81, 181),
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text(
                              'Start Training',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      final empId = _empIdController.text.trim();
                      if (empId.isNotEmpty) {
                        Navigator.pushNamed(context, '/settings',
                                arguments: {'empId': empId})
                            .then((_) => _loadModules());
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Enter Employee ID to view settings')),
                        );
                      }
                    },
                    child: const Text('Settings',
                        style: TextStyle(fontSize: 14, color: Colors.indigo)),
                  ),
                  const Text('|', style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () {
                      // Navigate to the admin login screen
                      Navigator.pushNamed(context, '/adminlogin').then((_) {
                        // This code runs when the admin screen is popped (closed)
                        _loadModules(); // 👈 Call _loadModules() to refresh the list
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Modules refreshed after admin action')),
                        );
                      });
                    },
                    child: const Text('Admin',
                        style: TextStyle(fontSize: 14, color: Colors.indigo)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
