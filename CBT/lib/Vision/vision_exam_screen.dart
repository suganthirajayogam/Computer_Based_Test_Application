import 'dart:io';
import 'package:computer_based_test/database/database_helper.dart';
import 'package:computer_based_test/models/vis_ques_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:computer_based_test/Vision/vision_exam_result.dart';
import 'package:computer_based_test/Vision_exam/bloc/vision_exam_bloc.dart';
import 'package:computer_based_test/Vision_exam/bloc/vision_exam_event.dart' hide VisionExamAnswerSelected, VisionExamQuestionChanged, VisionExamReasonSelectedList;
import 'package:computer_based_test/Vision_exam/bloc/vision_exam_state.dart' hide VisionExamState;
import 'package:photo_view/photo_view.dart';
import 'package:intl/intl.dart';

class VisionExamScreen extends StatelessWidget {
  final Map<String, dynamic> arguments;

  const VisionExamScreen({super.key, required this.arguments});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VisionExamBloc, VisionExamState>(
      builder: (context, state) {
        final questions = state.questions;
        final currentIndex = state.currentIndex;
        if (questions.isEmpty || currentIndex >= questions.length) {
          return const Scaffold(
            body: Center(child: Text("No questions available.")),
          );
        }

        final currentQuestion = questions[currentIndex];
        final selectedAnswers = state.selectedAnswers;
        final selectedReasons = state.selectedReasons;
        final employee = arguments['employee'] as Map<String, dynamic>;
        final module = employee['module'];
        final selected = selectedReasons[currentIndex] ?? <String>[];

        return Scaffold(
          backgroundColor: const Color(0xFFFFE6F0),
          body: SafeArea(
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(questions.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          backgroundColor: index == currentIndex
                              ? Colors.blue
                              : Colors.grey[300],
                          foregroundColor: Colors.black,
                          minimumSize: const Size(40, 40),
                        ),
                        onPressed: () {
                          context.read<VisionExamBloc>().add(
                                VisionExamQuestionChanged(index, newIndex: index),
                              );
                        },
                        child: Text("${index + 1}"),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text("Name:",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Text("${employee['employeeName']}",
                              style: const TextStyle(color: Colors.blue)),
                          const SizedBox(width: 20),
                          const Text("Module:",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Text("$module"),
                          const Spacer(),
                          Text(
                            "Question ${currentIndex + 1} of ${questions.length}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.red),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            currentQuestion.questionText ?? "",
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            color: Colors.white,
                          ),
                          child: currentQuestion.imagePath != null &&
                                  File(currentQuestion.imagePath!).existsSync()
                              ? ClipRect(
                                  child: PhotoView(
                                    imageProvider:
                                        FileImage(File(currentQuestion.imagePath!)),
                                    backgroundDecoration:
                                        const BoxDecoration(color: Colors.white),
                                    initialScale:
                                        PhotoViewComputedScale.contained,
                                    minScale: PhotoViewComputedScale.contained,
                                    maxScale:
                                        PhotoViewComputedScale.covered * 2.5,
                                    basePosition: Alignment.center,
                                    enableRotation: false,
                                  ),
                                )
                              : const Center(
                                  child: Text("No Image",
                                      style: TextStyle(
                                          fontSize: 18, color: Colors.grey)),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    context.read<VisionExamBloc>().add(
                                          VisionExamAnswerSelected(
                                              index: currentIndex,
                                              answer: 'Good'),
                                        );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(140, 45),
                                    side: const BorderSide(color: Colors.black),
                                    backgroundColor:
                                        selectedAnswers[currentIndex] == 'Good'
                                            ? Colors.green[100]
                                            : Colors.white,
                                  ),
                                  child: const Text("Good",
                                      style: TextStyle(color: Colors.black)),
                                ),
                                OutlinedButton(
                                  onPressed: () {
                                    context.read<VisionExamBloc>().add(
                                          VisionExamAnswerSelected(
                                              index: currentIndex,
                                              answer: 'Not Good'),
                                        );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(140, 45),
                                    side: const BorderSide(color: Colors.black),
                                    backgroundColor:
                                        selectedAnswers[currentIndex] == 'Not Good'
                                            ? Colors.red[100]
                                            : Colors.white,
                                  ),
                                  child: const Text("Not Good",
                                      style: TextStyle(color: Colors.black)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (selectedAnswers[currentIndex] == 'Not Good')
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: currentQuestion.allReasons.map<Widget>((reason) {
                                    final isSelected = selected.contains(reason);
                                    return CheckboxListTile(
                                      value: isSelected,
                                      dense: true,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                                      onChanged: (checked) {
                                        final updated = List<String>.from(selected);
                                        if (checked == true && !updated.contains(reason)) {
                                          updated.add(reason);
                                        } else if (checked == false && updated.contains(reason)) {
                                          updated.remove(reason);
                                        }
                                        context.read<VisionExamBloc>().add(
                                          VisionExamReasonSelectedList(
                                            index: currentIndex,
                                            reasons: updated,
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: 20),
                            if (currentIndex == questions.length - 1)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 20.0),
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final List<VisionQuestionModel> visionQuestions =
                                          questions.map((q) => q as VisionQuestionModel).toList();

                                      context.read<VisionExamBloc>().add(VisionExamSubmitted());

                                      // Get database instance
                                      final db = await Database_helper.instance.database;
                                      int correctAnswers = 0;

                                      // Insert individual results
                                      for (int i = 0; i < visionQuestions.length; i++) {
                                        final q = visionQuestions[i];
                                        final answer = state.selectedAnswers[i] ?? '';
                                        final reasons = state.selectedReasons[i] ?? [];

                                        if (answer == q.correctAnswer) {
                                          correctAnswers++;
                                        }

                                        await db.insert('vision_exam_results', {
                                          'empId': employee['employeeId'],
                                          'empName': employee['employeeName'],
                                          'module': module,
                                          'questionId': q.id,
                                          'questionText': q.questionText ?? '',
                                          'correctAnswer': q.correctAnswer,
                                          'selectedAnswer': answer,
                                          'selectedReasons': reasons.join(','),
                                        });
                                      }

                                      // Calculate and insert summary
                                      final total = visionQuestions.length;
                                      final percentage = (correctAnswers / total) * 100;
                                      final status = percentage >= 60 ? 'Passed' : 'Failed';

                                      await db.insert('vision_exam_summary', {
                                        'empId': employee['employeeId'],
                                        'empName': employee['employeeName'],
                                        'module': module,
                                        'score': correctAnswers,
                                        'percentage': percentage,
                                        'status': status,
                                        'date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                                      });

                                      // Navigate to results
                                      if (context.mounted) {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => VisionResultScreen(
                                              empId: employee['employeeId'],
                                              empName: employee['employeeName'],
                                              module: module,
                                              selectedAnswers: state.selectedAnswers,
                                              selectedReasons: state.selectedReasons,
                                              questions: visionQuestions,
                                            ),
                                          ),
                                          (Route<dynamic> route) => route.isFirst,
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                    ),
                                    icon: const Icon(Icons.check, color: Colors.white),
                                    label: const Text(
                                      "Submit",
                                      style: TextStyle(fontSize: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}