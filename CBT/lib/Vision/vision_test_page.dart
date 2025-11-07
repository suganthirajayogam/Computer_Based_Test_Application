import 'package:computer_based_test/database/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:computer_based_test/models/vis_ques_model.dart';

class VisionTestPage extends StatelessWidget {
  const VisionTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final empName = data['employeeName'];
    final empId = data['employeeId'];
    final module = data['module'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision Test Page'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $empName',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator()),
                    );

                    print('Fetching questions for module: $module');

                    // Correct method name from database_helper.dart
                    List<VisionQuestionModel> questions =
                        await Database_helper.instance.getVisionQuestionsByModule(module);

                    print('Questions fetched: ${questions.length}');

                    Navigator.pop(context); // Close loading

                    if (questions.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No questions available.')),
                      );
                      return;
                    }

                    Navigator.pushNamed(
                      context,
                      '/vision_exam',
                      arguments: {
                        'questions': questions,
                        'employee': {
                          'employeeName': empName,
                          'employeeId': empId,
                          'module': module,
                        },
                      },
                    );
                  } catch (e, stack) {
                    Navigator.pop(context); // Close loading if open
                    print('Error in Proceed: $e');
                    print(stack);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                ),
                child: const Text('Proceed'),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}