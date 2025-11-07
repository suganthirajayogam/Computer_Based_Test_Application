import 'package:computer_based_test/database/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:computer_based_test/database/mcq_question_db.dart';
import 'package:computer_based_test/models/mcq_ques_model.dart';
import 'package:computer_based_test/database/modules_db.dart'; // ✅ Import this

class EmployeeLoginForm extends StatefulWidget {
  final void Function(Map<String, dynamic> formData) onSubmit;

  const EmployeeLoginForm({super.key, required this.onSubmit});

  @override
  State<EmployeeLoginForm> createState() => _EmployeeLoginFormState();
}

class _EmployeeLoginFormState extends State<EmployeeLoginForm> {
  final _formKey = GlobalKey<FormState>();
  String? selectedSubject;
  List<String> subjects = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final baseSubjects = ['Safety', 'ESD', 'SMT', 'FA'];
    final dynamicModules = await Database_helper.instance.getMCQModules();
    setState(() {
      subjects = [...baseSubjects, ...dynamicModules];
      if (subjects.isNotEmpty) selectedSubject = subjects.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDropdownField(),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate() && selectedSubject != null) {
                try {
                  List<MCQQuestion> questions =
                      await Database_helper.instance.getMCQQuestionsBySubject(selectedSubject!);

                  if (questions.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No questions found for this subject")),
                    );
                    return;
                  }

                  widget.onSubmit({
                    'subject': selectedSubject,
                    'questions': questions,
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
            ),
            child: const Text('Start Test'),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: DropdownButtonFormField<String>(
        value: selectedSubject,
        decoration: const InputDecoration(
          labelText: "Select Subject",
          border: OutlineInputBorder(),
        ),
        items: subjects.map((String subject) {
          return DropdownMenuItem<String>(
            value: subject,
            child: Text(subject),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedSubject = value!;
          });
        },
      ),
    );
  }
}
