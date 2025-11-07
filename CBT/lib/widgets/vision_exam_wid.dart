// import 'package:flutter/material.dart';

// class VisionExamQuestionBox extends StatelessWidget {
//   final int currentQuestion;
//   final int totalQuestions;
//   final Widget questionContent;
//   final VoidCallback onGoodPressed;
//   final VoidCallback onNotGoodPressed;
//   final List<String> reasons;
//   final List<String> selectedReasons;
//   final Function(String) onReasonToggle;

//   const VisionExamQuestionBox({
//     Key? key,
//     required this.currentQuestion,
//     required this.totalQuestions,
//     required this.questionContent,
//     required this.onGoodPressed,
//     required this.onNotGoodPressed,
//     required this.reasons,
//     required this.selectedReasons,
//     required this.onReasonToggle,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.pink[100],
//       appBar: AppBar(
//         backgroundColor: Colors.pink[100],
//         elevation: 0,
//         leading: BackButton(color: Colors.black),
//         title: Row(
//           children: [
//             Text("Name: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
//             Text("Suganthi", style: TextStyle(color: Colors.blue)),
//             SizedBox(width: 20),
//             Text("Module: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
//             Text("B", style: TextStyle(color: Colors.black)),
//           ],
//         ),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.all(12.0),
//             child: Text(
//               "Question $currentQuestion of $totalQuestions",
//               style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
//             ),
//           )
//         ],
//       ),
//       body: Row(
//         children: [
//           // Left question navigation dots
//           Container(
//             width: 50,
//             color: Colors.transparent,
//             child: ListView.builder(
//               itemCount: totalQuestions,
//               itemBuilder: (context, index) {
//                 bool isCurrent = (index + 1) == currentQuestion;
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 8),
//                   child: CircleAvatar(
//                     radius: 15,
//                     backgroundColor: isCurrent ? Colors.blue : Colors.grey[300],
//                     child: Text(
//                       '${index + 1}',
//                       style: TextStyle(color: isCurrent ? Colors.white : Colors.black54),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),

//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   // Question box with white background and nice border radius
//                   Expanded(
//                     child: Container(
//                       width: double.infinity,
//                       padding: EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(10),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black12,
//                             blurRadius: 5,
//                             offset: Offset(0, 3),
//                           ),
//                         ],
//                       ),
//                       child: SingleChildScrollView(
//                         child: questionContent,
//                       ),
//                     ),
//                   ),

//                   SizedBox(height: 20),

//                   // Buttons Good / Not Good
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       ElevatedButton(
//                         onPressed: onGoodPressed,
//                         style: ElevatedButton.styleFrom(
//                           foregroundColor: Colors.black, backgroundColor: Colors.white,
//                           side: BorderSide(color: Colors.black),
//                           shape: StadiumBorder(),
//                           padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                         ),
//                         child: Text("Good"),
//                       ),
//                       ElevatedButton(
//                         onPressed: onNotGoodPressed,
//                         style: ElevatedButton.styleFrom(
//                           foregroundColor: Colors.black, backgroundColor: Colors.pink[100],
//                           shape: StadiumBorder(),
//                           padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                         ),
//                         child: Text("Not Good"),
//                       ),
//                     ],
//                   ),

//                   SizedBox(height: 20),

//                   // If Not Good selected, show reason checkboxes
//                   if (selectedReasons.isNotEmpty || reasons.isNotEmpty)
//                     Container(
//                       alignment: Alignment.centerLeft,
//                       child: Wrap(
//                         spacing: 10,
//                         children: reasons.map((reason) {
//                           bool checked = selectedReasons.contains(reason);
//                           return FilterChip(
//                             label: Text(reason),
//                             selected: checked,
//                             onSelected: (_) => onReasonToggle(reason),
//                           );
//                         }).toList(),
//                       ),
//                     ),

//                   SizedBox(height: 20),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
