import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:computer_based_test/database/database_helper.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

class VideoModuleManager extends StatefulWidget {
  const VideoModuleManager({super.key});

  @override
  State<VideoModuleManager> createState() => _VideoModuleManagerState();

  // Static method to get quiz for a module
  static Future<List<Map<String, dynamic>>> getQuizForModule(String module) async {
    return await Database_helper.instance.getQuizQuestionsByModule(module);
  }
}

class _VideoModuleManagerState extends State<VideoModuleManager> {
  String? _selectedModule;
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _quizQuestions = [];

  @override
  void initState() {
    super.initState();
    // Load initial data
    Database_helper.instance.getVideoModules();
  }

  Future<void> _loadVideos(String module) async {
    final videos = await Database_helper.instance.getVideosByModule(module);
    final quiz = await Database_helper.instance.getQuizQuestionsByModule(module);
    
    setState(() {
      _videos = videos;
      _quizQuestions = quiz;
      _selectedModule = module;
    });
  }

  Future<void> _createModule() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Module'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Module Name',
            hintText: 'e.g., Safety Training',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await Database_helper.instance.insertVideoModule(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Module "$result" created')),
        );
      }
    }
  }

  Future<void> _deleteModule(String module) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Module'),
        content: Text('Delete "$module" and all its videos & quiz questions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await Database_helper.instance.database;
      await db.delete('videos', where: 'module = ?', whereArgs: [module]);
      await db.delete('quiz_questions', where: 'module = ?', whereArgs: [module]);
      await Database_helper.instance.deleteVideoModule(module);
      
      setState(() {
        _selectedModule = null;
        _videos = [];
        _quizQuestions = [];
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Module deleted')),
        );
      }
    }
  }

  Future<void> _uploadVideo() async {
    if (_selectedModule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a module first')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null) return;

    final titleController = TextEditingController();
    final descController = TextEditingController();

    final videoInfo = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'title': titleController.text.trim(),
              'description': descController.text.trim(),
            }),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (videoInfo == null) return;

    final videoDir = Directory('C:\\CBT\\Videos');
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(result.files.single.path!);
    final newFileName = '${_selectedModule}_${timestamp}$extension';
    final newVideoPath = path.join(videoDir.path, newFileName);

    await File(result.files.single.path!).copy(newVideoPath);

    await Database_helper.instance.insertVideo({
      'module': _selectedModule,
      'title': videoInfo['title'],
      'description': videoInfo['description'],
      'video_path': newVideoPath,
      'thumbnail_path': '',
      'duration': 0,
      'uploaded_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'uploaded_by': 'Admin',
    });

    _loadVideos(_selectedModule!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video uploaded successfully')),
      );
    }
  }

  Future<void> _editVideo(Map<String, dynamic> video) async {
    final titleController = TextEditingController(text: video['title']);
    final descController = TextEditingController(text: video['description']);

    final updated = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'title': titleController.text.trim(),
              'description': descController.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null) {
      await Database_helper.instance.updateVideo(video['id'], updated);
      _loadVideos(_selectedModule!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video updated')),
        );
      }
    }
  }

  Future<void> _deleteVideo(int videoId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Database_helper.instance.deleteVideo(videoId);
      _loadVideos(_selectedModule!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video deleted')),
        );
      }
    }
  }

  // ========== QUIZ MANAGEMENT ==========
  
  Future<void> _addQuizQuestion() async {
    if (_selectedModule == null) return;

    final questionController = TextEditingController();
    final optionAController = TextEditingController();
    final optionBController = TextEditingController();
    final optionCController = TextEditingController();
    final optionDController = TextEditingController();
    String correctAnswer = 'A';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Quiz Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: optionAController,
                  decoration: const InputDecoration(
                    labelText: 'Option A',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: optionBController,
                  decoration: const InputDecoration(
                    labelText: 'Option B',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: optionCController,
                  decoration: const InputDecoration(
                    labelText: 'Option C',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: optionDController,
                  decoration: const InputDecoration(
                    labelText: 'Option D',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: correctAnswer,
                  decoration: const InputDecoration(
                    labelText: 'Correct Answer',
                    border: OutlineInputBorder(),
                  ),
                  items: ['A', 'B', 'C', 'D']
                      .map((opt) => DropdownMenuItem(
                            value: opt,
                            child: Text('Option $opt'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      correctAnswer = value!;
                    });
                  },
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
                if (questionController.text.trim().isEmpty ||
                    optionAController.text.trim().isEmpty ||
                    optionBController.text.trim().isEmpty ||
                    optionCController.text.trim().isEmpty ||
                    optionDController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All fields required')),
                  );
                  return;
                }

                // Save to database
                await Database_helper.instance.insertQuizQuestion({
                  'module': _selectedModule,
                  'question': questionController.text.trim(),
                  'option_a': optionAController.text.trim(),
                  'option_b': optionBController.text.trim(),
                  'option_c': optionCController.text.trim(),
                  'option_d': optionDController.text.trim(),
                  'correct_answer': correctAnswer,
                });

                Navigator.pop(context);
                _loadVideos(_selectedModule!); // Reload to show new question
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Question added')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteQuizQuestion(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Database_helper.instance.deleteQuizQuestion(id);
      _loadVideos(_selectedModule!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Module Manager'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Module',
            onPressed: _createModule,
          ),
        ],
      ),
      body: StreamBuilder<List<String>>(
        stream: Database_helper.instance.videoModulesStream,
        initialData: const [],
        builder: (context, snapshot) {
          final modules = snapshot.data ?? [];

          return Row(
            children: [
              Container(
                width: 250,
                color: Colors.grey.shade100,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.indigo,
                      width: double.infinity,
                      child: const Text(
                        'Modules',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: modules.isEmpty
                          ? const Center(child: Text('No modules yet'))
                          : ListView.builder(
                              itemCount: modules.length,
                              itemBuilder: (context, index) {
                                final module = modules[index];
                                return ListTile(
                                  selected: _selectedModule == module,
                                  selectedTileColor: Colors.indigo.shade100,
                                  title: Text(module),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteModule(module),
                                  ),
                                  onTap: () => _loadVideos(module),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _selectedModule == null
                    ? const Center(
                        child: Text('Select a module'),
                      )
                    : DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            Container(
                              color: Colors.blue.shade50,
                              child: TabBar(
                                labelColor: Colors.indigo,
                                indicatorColor: Colors.indigo,
                                tabs: [
                                  Tab(
                                    icon: const Icon(Icons.video_library),
                                    text: 'Videos (${_videos.length})',
                                  ),
                                  Tab(
                                    icon: const Icon(Icons.quiz),
                                    text: 'Quiz (${_quizQuestions.length})',
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildVideosTab(),
                                  _buildQuizTab(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideosTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedModule!,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _uploadVideo,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Video'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
        ),
        Expanded(
          child: _videos.isEmpty
              ? const Center(child: Text('No videos'))
              : ListView.builder(
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const Icon(Icons.video_library, size: 40, color: Colors.indigo),
                        title: Text(video['title'] ?? 'Untitled',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(video['description'] ?? '', maxLines: 2),
                            Text('Uploaded: ${video['uploaded_date']}',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editVideo(video),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteVideo(video['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildQuizTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green.shade50,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Quiz for $_selectedModule',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addQuizQuestion,
                icon: const Icon(Icons.add),
                label: const Text('Add Question'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
        ),
        Expanded(
          child: _quizQuestions.isEmpty
              ? const Center(child: Text('No quiz questions'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _quizQuestions.length,
                  itemBuilder: (context, index) {
                    final q = _quizQuestions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Text('${index + 1}',
                              style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(q['question'],
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Correct: ${q['correct_answer']}',
                            style: const TextStyle(color: Colors.green)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteQuizQuestion(q['id']),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildOption('A', q['option_a'], q['correct_answer'] == 'A'),
                                const SizedBox(height: 8),
                                _buildOption('B', q['option_b'], q['correct_answer'] == 'B'),
                                const SizedBox(height: 8),
                                _buildOption('C', q['option_c'], q['correct_answer'] == 'C'),
                                const SizedBox(height: 8),
                                _buildOption('D', q['option_d'], q['correct_answer'] == 'D'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOption(String label, String text, bool isCorrect) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.shade50 : Colors.grey.shade50,
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.grey.shade300,
          width: isCorrect ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCorrect ? Colors.green : Colors.grey.shade300,
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? Colors.white : Colors.black87,
                  )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          if (isCorrect) const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }
}