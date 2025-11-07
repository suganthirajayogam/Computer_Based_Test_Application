import 'package:computer_based_test/certification/certificate_screen.dart';
import 'package:computer_based_test/certification/certification_class.dart';
import 'package:computer_based_test/certification/certification_login.dart';
import 'package:computer_based_test/screens/video_upload_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:computer_based_test/Vision/Vision_report.dart';
import 'package:computer_based_test/Vision/vis_que_list.dart';
import 'package:computer_based_test/Vision/vision_exam_result.dart';
import 'package:computer_based_test/Vision/vision_exam_screen.dart';
import 'package:computer_based_test/Vision/vision_login.dart';
import 'package:computer_based_test/Vision/vision_test_page.dart';
import 'package:computer_based_test/Vision_exam/bloc/vision_exam_bloc.dart';
import 'package:computer_based_test/exam_mcq/bloc/exam_mcq_bloc.dart';
import 'package:computer_based_test/models/mcq_ques_model.dart';
import 'package:computer_based_test/models/vis_ques_model.dart';
import 'package:computer_based_test/screens/1.a__login_page.dart';
import 'package:computer_based_test/screens/c_account_creation_emp.dart';
import 'package:computer_based_test/screens/exam_mcq_screen.dart';
import 'package:computer_based_test/screens/exam_result_screen.dart';
import 'package:computer_based_test/screens/main_dashboard.dart';
import 'package:computer_based_test/screens/mcq_report_page.dart';
import 'package:computer_based_test/screens/b__test_page.dart';
import 'package:computer_based_test/screens/report_page_division.dart';
import 'package:computer_based_test/screens/settings.screen.dart';
import 'package:computer_based_test/screens/welcome_screen.dart';
import 'package:computer_based_test/screens/admin_login_screen.dart';
import 'package:computer_based_test/screens/mcq_question_upload.dart';
import 'package:computer_based_test/login/bloc/login_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<LoginBloc>(create: (_) => LoginBloc()),
        BlocProvider<ExamMCQBloc>(create: (_) => ExamMCQBloc()),
      ],
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Visteon App',
      theme: ThemeData.light(useMaterial3: true).copyWith(
        primaryColor: Colors.indigo,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        primaryColor: Colors.indigo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _themeMode,

      routes: {
        '/': (context) => WelcomeScreen(),
        '/login': (context) => CreateAccountScreen(onToggleTheme: toggleTheme),
        '/adminlogin': (context) => const AdminLoginScreen(),
        '/dashboard': (context) => const MCQDashboardPage(),
        '/maindashboard': (context) => const MainDashboard(),
        '/report': (context) => const ReportPage(),
        '/testpage': (context) => const TestPage(),
        '/accountcreation': (context) => const AdminEmpEntryScreen(),
        '/settings': (context) => SettingsScreen(onToggleTheme: toggleTheme),
        '/vision_login': (context) =>visionCreateAccountScreen(onToggleTheme: toggleTheme),
        '/vision_testpage': (context) => const VisionTestPage(),
        '/screen_report': (context) => const ReportMainPage(),
        '/vision_report': (context) => const VisionReportPage(),
        '/video_upload': (context) => VideoModuleManager(),
        '/certification_login': (context) =>  CertificationLogin(onToggleTheme: (bool p1) {  },),
      },

      onGenerateRoute: (settings) {
        if (settings.name == '/examquiz') {
          final args = settings.arguments;
          if (args is Map<String, dynamic>) {
            return MaterialPageRoute(
              builder: (_) => ExamMCQScreen(
                questions: args['questions'],
                subject: args['subject'],
                employee: args['employee'],
              ),
            );
          } else {
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text("Invalid route arguments")),
              ),
            );
          }
          
        } else if (settings.name == '/exam_result') {
          final args = settings.arguments as Map<String, dynamic>;
          final Map<int, String> selectedMap =
              Map<int, String>.from(args['selectedAnswers']);

          final List<Map<String, dynamic>> questionMaps =
              List<Map<String, dynamic>>.from(args['questions']);

          final List<MCQQuestion> questions =
              questionMaps.map((q) => MCQQuestion.fromMap(q)).toList();

          final List<String> selectedAnswers = List.generate(
            questions.length,
            (index) => selectedMap[index] ?? 'Not Answered',
          );

          return MaterialPageRoute(
            builder: (_) => ExamResultScreen(
              employee: args['employee'],
              total: args['total'],
              correct: args['correct'],
              questions: questions,
              selectedAnswers: selectedAnswers,
            ),
          );
        } else if (settings.name == '/vision_ques') {
          final args = settings.arguments as Map<String, dynamic>;
          final moduleName = args['subject'] as String;

          return MaterialPageRoute(
            builder: (_) => VisionQuestionListScreen(module: moduleName),
          );
        } else if (settings.name == '/vision_exam') {
          final args = settings.arguments as Map<String, dynamic>;

          final questions = args['questions'] as List<VisionQuestionModel>;
          final employee = args['employee'] as Map<String, dynamic>;

          return MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (_) => VisionExamBloc()
                ..add(
                  LoadVisionQuestions(
                    questions: questions,
                    empName: employee['employeeName'] ?? '',
                    empId: employee['employeeId'] ?? '',
                    module: employee['module'] ?? '',
                  ),
                ),
              child: VisionExamScreen(
                arguments: {
                  'questions': questions,
                  'employee': employee,
                },
              ),
            ),
          );
        } else if (settings.name == '/vision_result') {
          final args = settings.arguments as Map<String, dynamic>;

          // Safe casting with null checks
          final selectedAnswersRaw = args['selectedAnswers'] ?? {};
          final selectedReasonsRaw = args['selectedReasons'] ?? {};
          final questionsRaw = args['questions'] ?? [];

          final Map<int, String> selectedAnswers = {};
          if (selectedAnswersRaw is Map) {
            selectedAnswersRaw.forEach((key, value) {
              if (key is int && value is String) {
                selectedAnswers[key] = value;
              }
            });
          }

          final Map<int, List<String>> selectedReasons = {};
          if (selectedReasonsRaw is Map) {
            selectedReasonsRaw.forEach((key, value) {
              if (key is int && value is List) {
                selectedReasons[key] = value.cast<String>();
              }
            });
          }

          final List<VisionQuestionModel> questions = [];
          if (questionsRaw is List) {
            for (var item in questionsRaw) {
              if (item is VisionQuestionModel) {
                questions.add(item);
              }
            }
          }

          return MaterialPageRoute(
            builder: (_) => VisionResultScreen(
              empId: args['empId']?.toString() ?? '',
              empName: args['empName']?.toString() ?? 'Unknown',
              module: args['module']?.toString() ?? 'Unknown',
              selectedAnswers: selectedAnswers,
              selectedReasons: selectedReasons,
              questions: questions,
            ),
          );
        }else if (settings.name == '/certification_testpage') {
    final args = settings.arguments as Map<String, dynamic>?;
    
    if (args == null) {
      return MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text("Missing certification arguments")),
        ),
      );
    }
    
    return MaterialPageRoute(
      builder: (_) => VideoCertificationScreen(
        employee: args['employee'] as Map<String, dynamic>,
        module: args['module'] as String,
      ),
    );
  }

        // Fallback for undefined routes
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text("No route defined")),
          ),
        );
      },
    );
  }
}

