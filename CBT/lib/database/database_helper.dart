import 'dart:io';
import 'dart:async';
import 'package:computer_based_test/models/exam_result.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:computer_based_test/models/mcq_ques_model.dart';
import 'package:computer_based_test/models/vis_ques_model.dart';
import 'package:computer_based_test/models/admin_log.dart';
import 'package:computer_based_test/models/Vision_result_model.dart';

class Database_helper {
  static final Database_helper instance = Database_helper._init();
  static Database? _database;

  Database_helper._init();

  // ✅ Stream Controllers for real-time updates
  final _mcqModulesController = StreamController<List<String>>.broadcast();
  final _visionModulesController = StreamController<List<String>>.broadcast();
  final _videoModulesController = StreamController<List<String>>.broadcast();
  final _employeesController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _videosController = StreamController<List<Map<String, dynamic>>>.broadcast();

  // ✅ Public streams to listen for changes
  Stream<List<String>> get mcqModulesStream => _mcqModulesController.stream;
  Stream<List<String>> get visionModulesStream => _visionModulesController.stream;
  Stream<List<String>> get videoModulesStream => _videoModulesController.stream;
  Stream<List<Map<String, dynamic>>> get employeesStream => _employeesController.stream;
  Stream<List<Map<String, dynamic>>> get videosStream => _videosController.stream;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('visteon_app.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbDir = Directory('C:\\CBT');
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
      print('✅ Created DB directory at: ${dbDir.path}');
    }

    final dbPath = join(dbDir.path, fileName);
    print('📂 Using Unified DB path: $dbPath');

    return await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
        onOpen: (db) => print('✅ Unified Database Opened Successfully'),
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. EMPLOYEE TABLE
    await db.execute('''
      CREATE TABLE emp_db (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id TEXT NOT NULL UNIQUE,
        employee_name TEXT NOT NULL,
        department TEXT,
        module TEXT,
        image_path TEXT
      )
    ''');
    print('✅ Table emp_db created');

    // 2. ADMIN TABLE
    await db.execute('''
      CREATE TABLE admins (
        username TEXT PRIMARY KEY,
        password TEXT NOT NULL
      )
    ''');
    print('✅ Table admins created');

    // 3. MCQ MODULES TABLE
    await db.execute('''
      CREATE TABLE mcq_modules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        module TEXT NOT NULL UNIQUE
      )
    ''');
    print('✅ Table mcq_modules created');

    // 4. MCQ QUESTIONS TABLE
    await db.execute('''
      CREATE TABLE mcq_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject TEXT,
        questionText TEXT,
        questionImagePath TEXT,
        optionA TEXT,
        optionAImagePath TEXT,
        optionB TEXT,
        optionBImagePath TEXT,
        optionC TEXT,
        optionCImagePath TEXT,
        optionD TEXT,
        optionDImagePath TEXT,
        correctAnswer TEXT
      )
    ''');
    print('✅ Table mcq_questions created');

    // 5. MCQ EXAM RESULTS TABLE
    await db.execute('''
      CREATE TABLE mcq_exam_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        empId TEXT,
        empName TEXT,
        subject TEXT,
        module TEXT,
        questionId INTEGER,
        questionText TEXT,
        correctAnswer TEXT,
        attempted TEXT,
        imagePath TEXT,
        totalQuestions INTEGER
      )
    ''');
    print('✅ Table mcq_exam_results created');

    // 6. MCQ EXAM SUMMARY TABLE
    await db.execute('''
      CREATE TABLE mcq_exam_summary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        empId TEXT,
        empName TEXT,
        subject TEXT,
        module TEXT,
        totalQuestions INTEGER,
        attempted INTEGER,
        correct INTEGER,
        score INTEGER,
        percentage REAL,
        status TEXT,
        date TEXT
      )
    ''');
    print('✅ Table mcq_exam_summary created');

    // 7. VISION MODULES TABLE
    await db.execute('''
      CREATE TABLE vision_modules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        module TEXT NOT NULL UNIQUE
      )
    ''');
    print('✅ Table vision_modules created');

    // 8. VISION QUESTIONS TABLE
    await db.execute('''
      CREATE TABLE vision_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        module TEXT,
        question_text TEXT,
        image_path TEXT,
        video_path TEXT,
        correct_answer TEXT,
        allreasons TEXT,
        reasons TEXT
      )
    ''');
    print('✅ Table vision_questions created');

    // 9. VISION EXAM RESULTS TABLE
    await db.execute('''
      CREATE TABLE vision_exam_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        empId TEXT,
        empName TEXT,
        module TEXT,
        questionId INTEGER,
        questionText TEXT,
        correctAnswer TEXT,
        selectedAnswer TEXT,
        selectedReasons TEXT
      )
    ''');
    print('✅ Table vision_exam_results created');

    // 10. VISION EXAM SUMMARY TABLE
    await db.execute('''
      CREATE TABLE vision_exam_summary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        empId TEXT,
        empName TEXT,
        module TEXT,
        score INTEGER,
        percentage REAL,
        status TEXT,
        date TEXT
      )
    ''');
    print('✅ Table vision_exam_summary created');

    // 11. VIDEOS TABLE
    await db.execute('''
      CREATE TABLE videos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        module TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        video_path TEXT NOT NULL,
        thumbnail_path TEXT,
        duration INTEGER,
        uploaded_date TEXT,
        uploaded_by TEXT
      )
    ''');
    print('✅ Table videos created');

    // 12. VIDEO MODULES TABLE
    await db.execute('''
      CREATE TABLE video_modules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        module TEXT NOT NULL UNIQUE
      )
    ''');
    print('✅ Table video_modules created');

    // 13. QUIZ QUESTIONS TABLE (NEW)
    await db.execute('''
      CREATE TABLE quiz_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        module TEXT NOT NULL,
        question TEXT NOT NULL,
        option_a TEXT NOT NULL,
        option_b TEXT NOT NULL,
        option_c TEXT NOT NULL,
        option_d TEXT NOT NULL,
        correct_answer TEXT NOT NULL
      )
    ''');
    print('✅ Table quiz_questions created');

    print('🎉 All tables created successfully!');
  }

  // ✅ Helper methods to notify streams
  Future<void> _notifyMCQModules() async {
    final modules = await getMCQModules();
    _mcqModulesController.add(modules);
  }

  Future<void> _notifyVisionModules() async {
    final modules = await getVisionModules();
    _visionModulesController.add(modules);
  }

  Future<void> _notifyVideoModules() async {
    final modules = await getVideoModules();
    _videoModulesController.add(modules);
  }

  Future<void> _notifyEmployees() async {
    final employees = await getAllEmployees();
    _employeesController.add(employees);
  }

  Future<void> _notifyVideos() async {
    final videos = await getAllVideos();
    _videosController.add(videos);
  }

  // ==================== EMPLOYEE OPERATIONS ====================
  Future<int> insertEmployee(Map<String, dynamic> data, Directory imagesDir) async {
    try {
      final db = await database;
      final empId = data['employee_id'].toString().trim();

      final existing = await db.query('emp_db', where: 'employee_id = ?', whereArgs: [empId]);
      if (existing.isNotEmpty) {
        print('⚠️ Employee ID $empId already exists');
        return 0;
      }

      String relativeImagePath = '';
      String fullImagePath = data['image_path']?.toString().trim() ?? '';
      if (fullImagePath.isNotEmpty && await File(fullImagePath).exists()) {
        final fileName = basename(fullImagePath);
        final newPath = join(imagesDir.path, fileName);
        await File(fullImagePath).copy(newPath);
        relativeImagePath = 'CBT/Emp_Images/$fileName';
      }

      final cleanedData = {
        'employee_id': empId,
        'employee_name': data['employee_name'].toString().trim(),
        'department': data['department']?.toString().trim() ?? '',
        'module': data['module']?.toString().trim() ?? '',
        'image_path': relativeImagePath,
      };

      final result = await db.insert('emp_db', cleanedData);
      await _notifyEmployees(); // ✅ Notify listeners
      return result;
    } catch (e) {
      print('❌ Insert employee error: $e');
      return -1;
    }
  }

  Future<Map<String, dynamic>?> getEmployeeById(String empId) async {
    final db = await database;
    final result = await db.query('emp_db', where: 'employee_id = ?', whereArgs: [empId.trim()]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllEmployees() async {
    final db = await database;
    final employees = await db.query('emp_db');
    // ✅ Also notify stream when data is fetched
    _employeesController.add(employees);
    return employees;
  }

  Future<int> updateEmployeeByEmployeeId(String empId, Map<String, dynamic> data) async {
    final db = await database;
    final result = await db.update('emp_db', data, where: 'employee_id = ?', whereArgs: [empId.trim()]);
    await _notifyEmployees(); // ✅ Notify listeners
    return result;
  }

  Future<int> deleteEmployee(String empId) async {
    final db = await database;
    final result = await db.delete('emp_db', where: 'employee_id = ?', whereArgs: [empId.trim()]);
    await _notifyEmployees(); // ✅ Notify listeners
    print(result > 0 ? '✅ Employee $empId deleted' : '⚠️ Employee $empId not found');
    return result;
  }

  Future<int> updateModule(String empId, String newModule) async {
    final db = await database;
    final result = await db.update('emp_db', {'module': newModule}, where: 'employee_id = ?', whereArgs: [empId]);
    await _notifyEmployees(); // ✅ Notify listeners
    return result;
  }

  // ==================== GET ALL SUMMARIES ====================
  Future<List<Map<String, dynamic>>> getAllSummaries() async {
    final db = await database;
    
    final mcqResults = await db.query('mcq_exam_summary', orderBy: 'date DESC');
    final visionResults = await db.query('vision_exam_summary', orderBy: 'date DESC');
    
    final allResults = [...mcqResults, ...visionResults];
    
    allResults.sort((a, b) {
      final dateA = a['date']?.toString() ?? '';
      final dateB = b['date']?.toString() ?? '';
      return dateB.compareTo(dateA);
    });
    
    return allResults;
  }

  // ==================== ADMIN OPERATIONS ====================
  Future<void> insertAdmin(Admin admin) async {
    final db = await database;
    await db.insert('admins', admin.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Admin?> getAdminByUsername(String username) async {
    final db = await database;
    final result = await db.query('admins', where: 'username = ?', whereArgs: [username]);
    return result.isNotEmpty ? Admin.fromMap(result.first) : null;
  }

  // ==================== MCQ MODULE OPERATIONS ====================
  Future<void> insertMCQModule(String module) async {
    final db = await database;
    final existing = await db.query('mcq_modules', where: 'module = ?', whereArgs: [module]);
    if (existing.isEmpty) {
      await db.insert('mcq_modules', {'module': module});
      print('✅ MCQ Module "$module" inserted');
      await _notifyMCQModules(); // ✅ Notify listeners
    } else {
      print('⚠️ MCQ Module "$module" already exists');
    }
  }

  Future<List<String>> getMCQModules() async {
    final db = await database;
    final result = await db.query('mcq_modules');
    final modules = result.map((e) => e['module'].toString()).toList();
    // ✅ Also notify stream when data is fetched
    _mcqModulesController.add(modules);
    return modules;
  }

  Future<void> deleteMCQModule(String module) async {
    final db = await database;
    final result = await db.delete('mcq_modules', where: 'module = ?', whereArgs: [module]);
    print(result > 0 ? '✅ MCQ Module "$module" deleted' : '⚠️ MCQ Module "$module" not found');
    await _notifyMCQModules(); // ✅ Notify listeners
  }

  // ==================== MCQ QUESTION OPERATIONS ====================
  Future<int> insertMCQQuestion(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('mcq_questions', data);
  }

  Future<List<MCQQuestion>> getMCQQuestionsBySubject(String subject) async {
    final db = await database;
    final result = await db.query('mcq_questions', where: 'subject = ?', whereArgs: [subject]);
    return result.map((q) => MCQQuestion.fromMap(q)).toList();
  }

  Future<int> updateMCQQuestion(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('mcq_questions', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteMCQQuestion(int id) async {
    final db = await database;
    final result = await db.delete('mcq_questions', where: 'id = ?', whereArgs: [id]);
    print(result > 0 ? '✅ MCQ Question $id deleted' : '⚠️ MCQ Question $id not found');
    return result;
  }

  // ==================== VISION MODULE OPERATIONS ====================
  Future<void> insertVisionModule(String module) async {
    final db = await database;
    final existing = await db.query('vision_modules', where: 'module = ?', whereArgs: [module]);
    if (existing.isEmpty) {
      await db.insert('vision_modules', {'module': module});
      print('✅ Vision Module "$module" inserted');
      await _notifyVisionModules(); // ✅ Notify listeners
    } else {
      print('⚠️ Vision Module "$module" already exists');
    }
  }

  Future<List<String>> getVisionModules() async {
    final db = await database;
    final result = await db.query('vision_modules');
    final modules = result.map((e) => e['module'].toString()).toList();
    // ✅ Also notify stream when data is fetched
    _visionModulesController.add(modules);
    return modules;
  }

  Future<void> deleteVisionModule(String module) async {
    final db = await database;
    final result = await db.delete('vision_modules', where: 'module = ?', whereArgs: [module]);
    print(result > 0 ? '✅ Vision Module "$module" deleted' : '⚠️ Vision Module "$module" not found');
    await _notifyVisionModules(); // ✅ Notify listeners
  }

  // ==================== VISION QUESTION OPERATIONS ====================
  Future<void> insertVisionQuestion(VisionQuestionModel question) async {
    final db = await database;
    await db.insert('vision_questions', question.toMap());
    print('✅ Vision question inserted');
  }

  Future<List<VisionQuestionModel>> getVisionQuestionsByModule(String module) async {
    final db = await database;
    final result = await db.query('vision_questions', where: 'module = ?', whereArgs: [module]);
    return result.map((e) => VisionQuestionModel.fromMap(e)).toList();
  }

  Future<int> updateVisionQuestion(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('vision_questions', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteVisionQuestion(int id) async {
    final db = await database;
    final result = await db.delete('vision_questions', where: 'id = ?', whereArgs: [id]);
    print(result > 0 ? '✅ Vision Question $id deleted' : '⚠️ Vision Question $id not found');
    return result;
  }

  // ==================== VIDEO OPERATIONS ====================
Future<int> insertVideo(Map<String, dynamic> video) async {
  final db = await database;
  
  // Verify the module field is set correctly
  print('Inserting video: ${video['title']} into module: ${video['module']}');
  
  return await db.insert(
    'videos',
    video,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
Future<void> debugAllVideos() async {
  final db = await database;
  final allVideos = await db.query('videos');
  
  print('\n=== ALL VIDEOS IN DATABASE ===');
  for (var video in allVideos) {
    print('ID: ${video['id']}, Title: ${video['title']}, Module: ${video['module']}');
  }
  print('==============================\n');
}

 Future<List<Map<String, dynamic>>> getVideosByModule(String module) async {
  final db = await database;
  
  // 🔍 Debug: Show what we're searching for
  print('🔍 Searching for videos in module: "$module"');
  
  final result = await db.query('videos', where: 'module = ?', whereArgs: [module]);
  
  // 🔍 Debug: Show what we found
  print('📹 Found ${result.length} videos for module "$module"');
  for (var video in result) {
    print('   ✓ ${video['title']} (Module: "${video['module']}")');
  }
  
  return result;
}


  Future<List<Map<String, dynamic>>> getAllVideos() async {
    final db = await database;
    final videos = await db.query('videos', orderBy: 'uploaded_date DESC');
    // ✅ Also notify stream when data is fetched
    _videosController.add(videos);
    return videos;
  }

  Future<int> updateVideo(int id, Map<String, dynamic> data) async {
    final db = await database;
    final result = await db.update('videos', data, where: 'id = ?', whereArgs: [id]);
    await _notifyVideos(); // ✅ Notify listeners
    return result;
  }

  Future<int> deleteVideo(int id) async {
    final db = await database;
    final result = await db.delete('videos', where: 'id = ?', whereArgs: [id]);
    print(result > 0 ? '✅ Video $id deleted' : '⚠️ Video $id not found');
    await _notifyVideos(); // ✅ Notify listeners
    return result;
  }
Future<void> debugAllVideosByModule() async {
  final db = await database;
  final allVideos = await db.query('videos', orderBy: 'module ASC, id ASC');
  
  print('\n════════ ALL VIDEOS IN DATABASE ════════');
  if (allVideos.isEmpty) {
    print('⚠️ No videos found in database!');
  } else {
    Map<String, List<Map<String, dynamic>>> groupedVideos = {};
    for (var video in allVideos) {
      final module = video['module'].toString();
      groupedVideos.putIfAbsent(module, () => []);
      groupedVideos[module]!.add(video);
    }
    
    groupedVideos.forEach((module, videos) {
      print('📁 Module: "$module" (${videos.length} videos)');
      for (var video in videos) {
        print('   📹 ID: ${video['id']}, Title: ${video['title']}');
      }
    });
  }
  print('════════════════════════════════════════\n');
}
  // ==================== VIDEO MODULE OPERATIONS ====================
  Future<void> insertVideoModule(String module) async {
    try {
      final db = await database;
      
      final existing = await db.query('video_modules', where: 'module = ?', whereArgs: [module]);
      if (existing.isNotEmpty) {
        print('⚠️ Video Module "$module" already exists');
        return;
      }
      
      await db.transaction((txn) async {
        await txn.insert('video_modules', {'module': module});
      });
      
      final verify = await db.query('video_modules', where: 'module = ?', whereArgs: [module]);
      if (verify.isNotEmpty) {
        print('✅ Video Module "$module" inserted and verified');
        await _notifyVideoModules(); // ✅ Notify listeners
      } else {
        print('❌ Video Module "$module" insert failed verification');
      }
    } catch (e) {
      print('❌ Error inserting video module: $e');
      rethrow;
    }
  }

  Future<List<String>> getVideoModules() async {
    final db = await database;
    final result = await db.query('video_modules');
    final modules = result.map((e) => e['module'].toString()).toList();
    // ✅ Also notify stream when data is fetched
    _videoModulesController.add(modules);
    return modules;
  }

  Future<void> deleteVideoModule(String module) async {
    final db = await database;
    final result = await db.delete('video_modules', where: 'module = ?', whereArgs: [module]);
    print(result > 0 ? '✅ Video Module "$module" deleted' : '⚠️ Video Module "$module" not found');
    await _notifyVideoModules(); // ✅ Notify listeners
  }

  // ==================== QUIZ OPERATIONS ====================
  Future<int> insertQuizQuestion(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('quiz_questions', data);
  }

  Future<List<Map<String, dynamic>>> getQuizQuestionsByModule(String module) async {
    final db = await database;
    return await db.query('quiz_questions', where: 'module = ?', whereArgs: [module]);
  }

  Future<int> updateQuizQuestion(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('quiz_questions', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteQuizQuestion(int id) async {
    final db = await database;
    final result = await db.delete('quiz_questions', where: 'id = ?', whereArgs: [id]);
    print(result > 0 ? '✅ Quiz Question $id deleted' : '⚠️ Quiz Question $id not found');
    return result;
  }

  // ==================== CLOSE DATABASE ====================
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
    
    // ✅ Close all stream controllers
    await _mcqModulesController.close();
    await _visionModulesController.close();
    await _videoModulesController.close();
    await _employeesController.close();
    await _videosController.close();
    
    print('🛑 Database closed');
  }

  Future<void> insertMCQResult(ExamResult examResult) async {}

  Future<void> insertMCQSummary(ExamResultSummary examResultSummary) async {}

  Future insertVideoCompletion(Map<String, String> completionData) async {}
}