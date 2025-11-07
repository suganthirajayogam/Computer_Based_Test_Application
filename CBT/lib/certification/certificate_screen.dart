import 'package:computer_based_test/screens/video_upload_screen.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:computer_based_test/database/database_helper.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class VideoCertificationScreen extends StatefulWidget {
  final Map<String, dynamic> employee;
  final String module;

  const VideoCertificationScreen({
    super.key,
    required this.employee,
    required this.module,
  });

  @override
  State<VideoCertificationScreen> createState() =>
      _VideoCertificationScreenState();
}

class _VideoCertificationScreenState extends State<VideoCertificationScreen> {
  // Video related
  List<Map<String, dynamic>> _videos = [];
  int _currentVideoIndex = 0;
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _videoCompleted = false;
  bool _allVideosWatched = false;
  Set<int> _watchedVideos = {};
  Duration _videoDuration = Duration.zero;
  Duration _videoPosition = Duration.zero;
  
  // ✅ Add these critical flags
  bool _isDisposing = false;
  bool _isTransitioning = false;

  // Quiz related
  bool _showQuiz = false;
  bool _quizCompleted = false;
  List<Map<String, dynamic>> _quizQuestions = [];
  int _currentQuestionIndex = 0;
  Map<int, String> _selectedAnswers = {};
  int _correctAnswers = 0;
  double _percentage = 0.0;

  // For quiz answer review
  bool _showAnswerReview = false;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);

    try {
      print('\n🔍 ========== LOADING VIDEOS ==========');
      print('📁 Module: "${widget.module}"');
      
      final videos = await Database_helper.instance.getVideosByModule(widget.module);
      
      print('📊 Found ${videos.length} videos');

      if (!mounted) return;

      if (videos.isEmpty) {
        print('⚠️ No videos found for module: ${widget.module}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No videos found for "${widget.module}"')),
        );
        Navigator.pop(context);
        return;
      }

      // Verify all video files exist
      for (int i = 0; i < videos.length; i++) {
        final videoPath = videos[i]['video_path'];
        final exists = await File(videoPath).exists();
        print('   Video ${i + 1}: ${videos[i]['title']} - ${exists ? "✅" : "❌"}');
      }

      setState(() {
        _videos = videos;
        _isLoading = false;
      });
      
      print('========================================\n');
      
      await _initializeVideo();
    } catch (e) {
      print('❌ Error loading videos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _disposeController() async {
    if (_controller == null || _isDisposing) return;
    
    _isDisposing = true;
    print('🧹 Starting controller disposal...');
    
    try {
      // Remove listener first
      try {
        _controller!.removeListener(_videoListener);
        print('   ✅ Listener removed');
      } catch (e) {
        print('   ⚠️ Error removing listener: $e');
      }
      
      // Pause if playing
      try {
        if (_controller!.value.isInitialized && _controller!.value.isPlaying) {
          await _controller!.pause().timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              print('   ⏱️ Pause timeout');
            },
          );
          print('   ✅ Playback paused');
        }
      } catch (e) {
        print('   ⚠️ Error pausing: $e');
      }
      
      // Dispose with timeout
      print('   ⏳ Disposing controller...');
      try {
        await _controller!.dispose().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            print('   ⏱️ Dispose TIMEOUT - forcing cleanup');
          },
        );
        print('   ✅ Controller disposed');
      } catch (e) {
        print('   ⚠️ Dispose error (continuing anyway): $e');
      }
      
      // Clear reference ALWAYS
      _controller = null;
      print('   ✅ Reference cleared');
      
      // Wait for system to release resources
      print('   ⏳ Waiting 800ms for system cleanup...');
      await Future.delayed(const Duration(milliseconds: 800));
      print('✅ Disposal complete\n');
      
    } catch (e) {
      print('❌ Disposal error: $e');
      _controller = null;
    } finally {
      _isDisposing = false;
      print('🏁 Disposal finished');
    }
  }

  Future<void> _initializeVideo() async {
    if (_videos.isEmpty || _currentVideoIndex >= _videos.length) {
      print('⚠️ Cannot initialize: Empty videos or invalid index');
      return;
    }

    print('🎬 ========== INITIALIZING VIDEO ==========');
    print('📹 Index: $_currentVideoIndex / ${_videos.length - 1}');
    
    final currentVideo = _videos[_currentVideoIndex];
    final videoPath = currentVideo['video_path'];
    final videoTitle = currentVideo['title'] ?? 'Video ${_currentVideoIndex + 1}';
    
    print('📝 Title: $videoTitle');
    print('📂 Path: $videoPath');

    // ✅ Set transitioning state FIRST
    if (mounted) {
      setState(() {
        _isTransitioning = true;
      });
    }

    // Dispose previous controller
    await _disposeController();

    if (!mounted) {
      print('⚠️ Widget unmounted during disposal');
      return;
    }

    // Additional safety delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Verify file exists
    final file = File(videoPath);
    if (!await file.exists()) {
      print('❌ Video file not found: $videoPath');
      if (mounted) {
        setState(() => _isTransitioning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video file not found')),
        );
      }
      return;
    }
    print('✅ Video file exists');

    try {
      print('🔧 Creating new controller...');
      
      // Create new controller
      final newController = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      print('⏳ Initializing...');
      
      // Initialize with retry logic
      bool initialized = false;
      int attempts = 0;
      const maxAttempts = 3;
      Exception? lastError;
      
      while (!initialized && attempts < maxAttempts) {
        try {
          attempts++;
          
          if (attempts > 1) {
            print('   🔄 Retry $attempts/$maxAttempts');
            await Future.delayed(Duration(milliseconds: 1000 * attempts));
          }
          
          await newController.initialize().timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception('Initialization timeout'),
          );
          
          initialized = true;
          print('✅ Initialized successfully on attempt $attempts');
          
        } catch (e) {
          lastError = e as Exception;
          print('⚠️ Attempt $attempts failed: $e');
          
          if (attempts >= maxAttempts) {
            print('❌ All attempts exhausted');
            try {
              await newController.dispose();
            } catch (_) {}
            throw lastError;
          }
        }
      }

      if (!mounted) {
        print('⚠️ Widget unmounted after init');
        await newController.dispose();
        return;
      }

      // ⚠️ CRITICAL: Assign controller and update state together
      setState(() {
        _controller = newController;
        _videoCompleted = _watchedVideos.contains(_currentVideoIndex);
        _videoDuration = newController.value.duration;
        _videoPosition = Duration.zero;
        _isTransitioning = false; // ✅ Clear transition state
      });
      
      print('✅ Controller assigned and state updated');
      print('📊 Duration: ${_formatDuration(_videoDuration)}');
      print('📐 Aspect Ratio: ${newController.value.aspectRatio}');

      // Add listener
      _controller!.addListener(_videoListener);
      print('✅ Listener added');
      
      // Wait a bit before playing
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Start playing
      if (mounted && _controller != null && _controller!.value.isInitialized) {
        await _controller!.play();
        print('▶️ Playing\n');
      }
      
    } catch (e, stackTrace) {
      print('❌ Fatal error: $e');
      print('Stack: $stackTrace');
      if (mounted) {
        setState(() => _isTransitioning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load video: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      final position = _controller!.value.position;
      final duration = _controller!.value.duration;

      if (mounted) {
        setState(() {
          _videoPosition = position;
          _videoDuration = duration;
        });
      }

      // Check completion
      if (duration.inSeconds > 0 &&
          position.inSeconds >= (duration.inSeconds * 0.95) &&
          !_watchedVideos.contains(_currentVideoIndex)) {
        
        print('✅ Video $_currentVideoIndex completed');
        
        if (mounted) {
          setState(() {
            _videoCompleted = true;
            _watchedVideos.add(_currentVideoIndex);
          });
          
          _controller?.pause();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Video completed!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('⚠️ Listener error: $e');
    }
  }

  void _nextVideo() async {
    if (_isDisposing || _isTransitioning) {
      print('⚠️ Still processing previous video');
      return;
    }
    
    print('\n⏭️ Next Video');
    print('Current: $_currentVideoIndex, Total: ${_videos.length}');
    
    if (_currentVideoIndex < _videos.length - 1) {
      if (!_watchedVideos.contains(_currentVideoIndex)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please watch current video first')),
        );
        return;
      }

      print('➡️ Moving to next');
      
      // Update index FIRST
      setState(() {
        _currentVideoIndex++;
        _allVideosWatched = false;
      });
      
      // Then initialize new video
      await _initializeVideo();
      
    } else {
      if (_watchedVideos.contains(_currentVideoIndex)) {
        print('✅ All videos watched');
        setState(() => _allVideosWatched = true);
        _controller?.pause();
        _loadQuizQuestions();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please watch final video first')),
        );
      }
    }
  }

  void _previousVideo() async {
    if (_isDisposing || _isTransitioning) {
      print('⚠️ Still processing');
      return;
    }
    
    if (_currentVideoIndex > 0) {
      print('⏮️ Previous video');
      
      setState(() {
        _currentVideoIndex--;
        _allVideosWatched = false;
      });
      
      await _initializeVideo();
    }
  }

  @override
  void dispose() {
    print('🛑 Disposing screen');
    _isDisposing = true;
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _openFullscreen() {
    if (_controller != null && _controller!.value.isInitialized) {
      final wasPlaying = _controller!.value.isPlaying;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _FullScreenVideoPlayer(
            controller: _controller!,
            videoTitle: _videos[_currentVideoIndex]['title'] ?? 'Video',
            wasPlaying: wasPlaying,
          ),
        ),
      ).then((_) {
        if (mounted && _controller != null && wasPlaying) {
          _controller!.play();
        }
      });
    }
  }

  Future<void> _loadQuizQuestions() async {
    try {
      final questions =
          await VideoModuleManager.getQuizForModule(widget.module);

      if (questions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No quiz. Generating certificate...'),
              duration: Duration(seconds: 2),
            ),
          );
          await Future.delayed(const Duration(seconds: 1));
          _generateCertificate();
        }
        return;
      }

      setState(() {
        _quizQuestions = questions;
        _showQuiz = true;
      });
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _selectAnswer(String answer) {
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = answer;
    });
  }

  void _nextQuestion() {
    if (_selectedAnswers[_currentQuestionIndex] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an answer')),
      );
      return;
    }

    if (_currentQuestionIndex < _quizQuestions.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else {
      _submitQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
    }
  }

  void _submitQuiz() {
    _correctAnswers = 0;

    for (int i = 0; i < _quizQuestions.length; i++) {
      if (_selectedAnswers[i] == _quizQuestions[i]['correct_answer']) {
        _correctAnswers++;
      }
    }

    _percentage = (_correctAnswers / _quizQuestions.length) * 100;
    setState(() => _quizCompleted = true);
  }

  Future<void> _generateCertificate() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Generating...'),
            ],
          ),
        ),
      );

      final pdf = pw.Document();

      pw.ImageProvider? logoImage;
      try {
        final logoFile = File('assets/images/visteon_logo.png');
        if (await logoFile.exists()) {
          final bytes = await logoFile.readAsBytes();
          logoImage = pw.MemoryImage(bytes);
        }
      } catch (e) {
        print('Logo not found: $e');
      }

 pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 6),
                color: PdfColors.white,
              ),
              padding: const pw.EdgeInsets.all(30),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SizedBox(height: 15),
                  pw.Image(logoImage!, height: 50, alignment: pw.Alignment.center),
                  pw.SizedBox(height: 25),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      'CERTIFICATE OF COMPLETION',
                      style: pw.TextStyle(
                        fontSize: 20, 
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'This is to certify that',
                    style: pw.TextStyle(fontSize: 15, fontStyle: pw.FontStyle.normal, color: PdfColors.grey800),
                  ),
                  pw.SizedBox(height: 18),
                  pw.Text(
                    widget.employee['employeeName']?.toString() ?? 
                    widget.employee['employee_name']?.toString() ?? 'Employee',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                  pw.Container(
                    width: 200,
                    height: 2,
                    color: PdfColors.orange700,
                    margin: const pw.EdgeInsets.only(top: 8),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Emp ID: ${widget.employee['employeeId']?.toString() ?? widget.employee['employee_id']?.toString() ?? 'N/A'}',
                    style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Text(
                    'has successfully completed the training module',
                    style: pw.TextStyle(fontSize: 15, fontStyle: pw.FontStyle.normal, color: PdfColors.grey800),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.orange100,
                      border: pw.Border.all(color: PdfColors.orange700, width: 2),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      widget.module,
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    ),
                  ),
                  pw.Spacer(),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Date of Issued: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 14, color: PdfColors.grey800),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                ],
              ),
            );
          },
        ),
      );


      final dir = Directory('C:\\CBT\\Certificates');
      if (!await dir.exists()) await dir.create(recursive: true);

      final empId = widget.employee['employeeId']?.toString() ??
          widget.employee['employee_id']?.toString() ??
          'unknown';
      final fileName =
          '${empId}_${widget.module}_Cert.pdf'.replaceAll(' ', '_');
      final filePath = path.join(dir.path, fileName);

      await File(filePath).writeAsBytes(await pdf.save());

      await Database_helper.instance.insertVideoCompletion({
        'empId': empId,
        'empName': widget.employee['employeeName']?.toString() ??
            widget.employee['employee_name']?.toString() ??
            '',
        'module': widget.module,
        'completed_date':
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'certificate_path': filePath,
        'quiz_score':
            _quizQuestions.isNotEmpty ? _percentage.toStringAsFixed(1) : 'N/A',
      });

      Navigator.pop(context);

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 20),
              const Text('Training complete!'),
              if (_quizQuestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                // Text('Score: ${_percentage.toStringAsFixed(1)}%'),
              ],
              const SizedBox(height: 10),
              Text('Saved: $filePath', style: const TextStyle(fontSize: 11)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error: $e');
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_videos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Training')),
        body: const Center(child: Text('No videos')),
      );
    }

    if (_quizCompleted) return _buildQuizResults();
    if (_showQuiz && _quizQuestions.isNotEmpty) return _buildQuiz();
    return _buildVideo();
  }

  // ✅ Enhanced video player section with loading state
  Widget _buildVideoPlayerSection() {
    if (_isTransitioning) {
      return Expanded(
        flex: 3,
        child: Container(
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Loading video...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Expanded(
      flex: 3,
      child: GestureDetector(
        onTap: () {
          if (_controller != null && _controller!.value.isInitialized) {
            final wasPlaying = _controller!.value.isPlaying;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _FullScreenVideoPlayer(
                  controller: _controller!,
                  videoTitle: _videos[_currentVideoIndex]['title'] ?? 'Video',
                  wasPlaying: wasPlaying,
                ),
              ),
            );
          }
        },
        child: Container(
          color: Colors.black,
          child: _controller != null && _controller!.value.isInitialized
              ? Stack(
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(
                          _controller!,
                          key: ValueKey('video_${_currentVideoIndex}_${_videos[_currentVideoIndex]['id']}'),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    Center(
                      child: IconButton(
                        icon: Icon(
                          _controller!.value.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          size: 80.0,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        onPressed: () {
                          setState(() {
                            _controller!.value.isPlaying
                                ? _controller!.pause()
                                : _controller!.play();
                          });
                        },
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    final video = _videos[_currentVideoIndex];
    final isLast = _currentVideoIndex == _videos.length - 1;
    final progress = _videoDuration.inSeconds > 0
        ? _videoPosition.inSeconds / _videoDuration.inSeconds
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.module} - Training'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                CircleAvatar(
                  child: Text(
                      '${(widget.employee['employeeName'] ?? widget.employee['employee_name'] ?? 'U').toString()[0]}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.employee['employeeName']?.toString() ??
                            widget.employee['employee_name']?.toString() ??
                            '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                          'ID: ${widget.employee['employeeId'] ?? widget.employee['employee_id']}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Text('Video ${_currentVideoIndex + 1}/${_videos.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // ✅ Use the new video player section
          _buildVideoPlayerSection(),

          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation(Colors.blue),
          ),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentVideoIndex > 0 ? _previousVideo : null,
                  icon: const Icon(Icons.skip_previous, size: 32),
                  color: _currentVideoIndex > 0 ? Colors.indigo : Colors.grey,
                ),
                IconButton(
                  onPressed: () {
                    if (_controller != null) {
                      setState(() {
                        _controller!.value.isPlaying
                            ? _controller!.pause()
                            : _controller!.play();
                      });
                    }
                  },
                  icon: Icon(
                    _controller?.value.isPlaying ?? false
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    size: 56,
                  ),
                  color: Colors.indigo,
                ),
                IconButton(
                  onPressed:
                      _videoCompleted && !_allVideosWatched ? _nextVideo : null,
                  icon: const Icon(Icons.skip_next, size: 32),
                  color: _videoCompleted ? Colors.indigo : Colors.grey,
                ),
              ],
            ),
          ),

          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video['title'] ?? 'Untitled',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(video['description'] ?? ''),
                  const SizedBox(height: 16),
                  if (!_videoCompleted && !_allVideosWatched)
                    _StatusMsg(
                      icon: Icons.info,
                      color: Colors.orange,
                      msg: 'Watch 95% to proceed',
                      bg: Colors.orange.shade100,
                    ),
                  if (_videoCompleted && !_allVideosWatched && !isLast)
                    _StatusMsg(
                      icon: Icons.check_circle,
                      color: Colors.green,
                      msg: 'Completed! Click next.',
                      bg: Colors.green.shade100,
                    ),
                  if (_videoCompleted && isLast && !_allVideosWatched)
                    _StatusMsg(
                      icon: Icons.check_circle,
                      color: Colors.green,
                      msg: 'Final video done. Click Next for quiz.',
                      bg: Colors.green.shade100,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuiz() {
    final q = _quizQuestions[_currentQuestionIndex];
    final sel = _selectedAnswers[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz: ${widget.module}'),
        backgroundColor: Colors.indigo,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                CircleAvatar(
                  child: Text(
                      '${(widget.employee['employeeName'] ?? widget.employee['employee_name'] ?? 'U').toString()[0]}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          widget.employee['employeeName']?.toString() ??
                              widget.employee['employee_name']?.toString() ??
                              '',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                          'Question ${_currentQuestionIndex + 1}/${_quizQuestions.length}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _quizQuestions.length,
            minHeight: 6,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(q['question'] ?? '',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildOption('A', q['option_a'], sel),
                  const SizedBox(height: 12),
                  _buildOption('B', q['option_b'], sel),
                  const SizedBox(height: 12),
                  _buildOption('C', q['option_c'], sel),
                  const SizedBox(height: 12),
                  _buildOption('D', q['option_d'], sel),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      _currentQuestionIndex > 0 ? _previousQuestion : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                ),
                ElevatedButton.icon(
                  onPressed: _nextQuestion,
                  icon: Icon(_currentQuestionIndex < _quizQuestions.length - 1
                      ? Icons.arrow_forward
                      : Icons.check),
                  label: Text(_currentQuestionIndex < _quizQuestions.length - 1
                      ? 'Next'
                      : 'Submit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
// Replace the _buildQuizResults() method with this enhanced version:

// Replace your _buildQuizResults() method with this version:
// Add this new state variable at the top of _VideoCertificationScreenState class:
// bool _showAnswerReview = false;

// Replace your _buildQuizResults() method with this version:

// Add this new state variable at the top of _VideoCertificationScreenState class:
// bool _showAnswerReview = false;

// Replace your _buildQuizResults() method with this version:

Widget _buildQuizResults() {
  final passed = _percentage >= 80.0;

  // If review not shown yet, show score summary only
  if (!_showAnswerReview) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        backgroundColor: Colors.indigo,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Score Icon
              Icon(
                passed ? Icons.check_circle : Icons.cancel,
                size: 120,
                color: passed ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 24),
              
              // Result Message
              Text(
                passed ? 'Good! 👏' : 'Better luck next time! 😊',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: passed ? Colors.green : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Score Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: passed
                          ? [Colors.green.shade50, Colors.green.shade100]
                          : [Colors.red.shade50, Colors.red.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Text(
                      //   'Your Score',
                      //   style: TextStyle(
                      //     fontSize: 18,
                      //     color: Colors.grey.shade700,
                      //     fontWeight: FontWeight.w500,
                      //   ),
                      // ),
                      // const SizedBox(height: 12),
                      // Text(
                      //   '${_percentage.toStringAsFixed(1)}%',
                      //   style: TextStyle(
                      //     fontSize: 56,
                      //     fontWeight: FontWeight.bold,
                      //     color: passed ? Colors.green.shade700 : Colors.red.shade700,
                      //   ),
                      // ),
                      // const SizedBox(height: 8),
                      Text(
                        '$_correctAnswers out of ${_quizQuestions.length} correct',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Review Answers Button
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAnswerReview = true;
                    });
                  },
                  icon: const Icon(Icons.assignment, size: 18),
                  label: const Text('Review Answers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Generate Certificate Button
              Center(
                child: ElevatedButton.icon(
                  onPressed: _generateCertificate,
                  icon: const Icon(Icons.workspace_premium, size: 18),
                  label: const Text('Generate Certificate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // If review is shown, show detailed answer review
  return Scaffold(
    appBar: AppBar(
      title: const Text('Answer Review'),
      backgroundColor: Colors.indigo,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          setState(() {
            _showAnswerReview = false;
          });
        },
      ),
    ),
    body: Column(
      children: [
        // Score Summary Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: passed ? Colors.green.shade50 : Colors.red.shade50,
            border: Border(
              bottom: BorderSide(
                color: passed ? Colors.green : Colors.red,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'Score',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.grey.shade300,
              ),
              Column(
                children: [
                  Text(
                    'Correct',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_correctAnswers/${_quizQuestions.length}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.grey.shade300,
              ),
              Column(
                children: [
                  Text(
                    'Incorrect',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_quizQuestions.length - _correctAnswers}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Questions and Answers List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _quizQuestions.length,
            itemBuilder: (context, index) {
              final question = _quizQuestions[index];
              final userAnswer = _selectedAnswers[index];
              final correctAnswer = question['correct_answer'];
              final isCorrect = userAnswer == correctAnswer;

              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isCorrect ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question Header with Status
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isCorrect ? Icons.check : Icons.close,
                                  size: 16,
                                  color: isCorrect ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isCorrect ? 'Correct' : 'Incorrect',
                                  style: TextStyle(
                                    color: isCorrect ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Question ${index + 1}/${_quizQuestions.length}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Question Text
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.help_outline,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                question['question'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Options
                      _buildAnswerOption('A', question['option_a'], userAnswer, correctAnswer),
                      const SizedBox(height: 8),
                      _buildAnswerOption('B', question['option_b'], userAnswer, correctAnswer),
                      const SizedBox(height: 8),
                      _buildAnswerOption('C', question['option_c'], userAnswer, correctAnswer),
                      const SizedBox(height: 8),
                      _buildAnswerOption('D', question['option_d'], userAnswer, correctAnswer),

                      // Summary Box
                      const SizedBox(height: 16),
                      // Container(
                      //   padding: const EdgeInsets.all(14),
                      //   decoration: BoxDecoration(
                      //     color: isCorrect ? Colors.green.shade50 : Colors.orange.shade50,
                      //     borderRadius: BorderRadius.circular(8),
                      //     border: Border.all(
                      //       color: isCorrect ? Colors.green.shade300 : Colors.orange.shade300,
                      //       width: 2,
                      //     ),
                      //   ),
                      //   child: Column(
                      //     crossAxisAlignment: CrossAxisAlignment.start,
                      //     children: [
                      //       // Your Answer
                      //       Row(
                      //         crossAxisAlignment: CrossAxisAlignment.start,
                      //         children: [
                      //           Icon(
                      //             isCorrect ? Icons.check_circle : Icons.cancel,
                      //             size: 20,
                      //             color: isCorrect ? Colors.green : Colors.red,
                      //           ),
                      //           const SizedBox(width: 8),
                      //           Expanded(
                      //             child: Column(
                      //               crossAxisAlignment: CrossAxisAlignment.start,
                      //               children: [
                      //                 Text(
                      //                   'Your Answer:',
                      //                   style: TextStyle(
                      //                     fontSize: 13,
                      //                     fontWeight: FontWeight.bold,
                      //                     color: Colors.grey.shade700,
                      //                   ),
                      //                 ),
                      //                 const SizedBox(height: 4),
                      //                 Text(
                      //                   '$userAnswer. ${_getOptionText(question, userAnswer ?? '')}',
                      //                   style: TextStyle(
                      //                     fontSize: 14,
                      //                     fontWeight: FontWeight.w600,
                      //                     color: isCorrect ? Colors.green.shade900 : Colors.red.shade900,
                      //                   ),
                      //                 ),
                      //               ],
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                            
                      //       // Correct Answer (if wrong)
                      //       if (!isCorrect) ...[
                      //         const SizedBox(height: 12),
                      //         const Divider(),
                      //         const SizedBox(height: 12),
                      //         Row(
                      //           crossAxisAlignment: CrossAxisAlignment.start,
                      //           children: [
                      //             Icon(
                      //               Icons.lightbulb,
                      //               size: 20,
                      //               color: Colors.green.shade700,
                      //             ),
                      //             const SizedBox(width: 8),
                      //             Expanded(
                      //               child: Column(
                      //                 crossAxisAlignment: CrossAxisAlignment.start,
                      //                 children: [
                      //                   Text(
                      //                     'Correct Answer:',
                      //                     style: TextStyle(
                      //                       fontSize: 13,
                      //                       fontWeight: FontWeight.bold,
                      //                       color: Colors.green.shade700,
                      //                     ),
                      //                   ),
                      //                   const SizedBox(height: 4),
                      //                   Text(
                      //                     '$correctAnswer. ${_getOptionText(question, correctAnswer)}',
                      //                     style: TextStyle(
                      //                       fontSize: 14,
                      //                       fontWeight: FontWeight.bold,
                      //                       color: Colors.green.shade900,
                      //                     ),
                      //                   ),
                      //                 ],
                      //               ),
                      //             ),
                      //           ],
                      //         ),
                      //       ],
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom Action Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _generateCertificate,
            icon: const Icon(Icons.workspace_premium),
            label: const Text('Generate Certificate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// Enhanced _buildAnswerOption
Widget _buildAnswerOption(
  String option,
  String? text,
  String? userAnswer,
  String correctAnswer,
) {
  final isUserAnswer = userAnswer == option;
  final isCorrectAnswer = correctAnswer == option;
  
  Color backgroundColor;
  Color borderColor;
  IconData? icon;
  Color? iconColor;
  String? label;

  if (isCorrectAnswer && isUserAnswer) {
    backgroundColor = Colors.green.shade50;
    borderColor = Colors.green;
    icon = Icons.check_circle;
    iconColor = Colors.green;
    label = '✓ Correct Answer';
  } else if (isCorrectAnswer) {
    backgroundColor = Colors.green.shade50;
    borderColor = Colors.green;
    icon = Icons.check_circle;
    iconColor = Colors.green;
    label = '✓ Correct Answer';
  } else if (isUserAnswer) {
    backgroundColor = Colors.red.shade50;
    borderColor = Colors.red;
    icon = Icons.cancel;
    iconColor = Colors.red;
    label = '✗ Your Answer';
  } else {
    backgroundColor = Colors.grey.shade50;
    borderColor = Colors.grey.shade300;
  }

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: borderColor,
        width: isCorrectAnswer || isUserAnswer ? 2 : 1,
      ),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCorrectAnswer
                    ? Colors.green
                    : isUserAnswer
                        ? Colors.red
                        : Colors.grey.shade300,
              ),
              child: Center(
                child: Text(
                  option,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isCorrectAnswer || isUserAnswer
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text ?? '',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCorrectAnswer || isUserAnswer
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon, color: iconColor, size: 24),
            ],
          ],
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isCorrectAnswer ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

// Keep the same helper method
String _getOptionText(Map<String, dynamic> question, String option) {
  switch (option) {
    case 'A':
      return question['option_a'] ?? '';
    case 'B':
      return question['option_b'] ?? '';
    case 'C':
      return question['option_c'] ?? '';
    case 'D':
      return question['option_d'] ?? '';
    default:
      return '';
  }
}
  Widget _buildOption(String opt, String? text, String? sel) {
    final isSel = sel == opt;

    return InkWell(
      onTap: () => _selectAnswer(opt),
      child: Card(
        elevation: isSel ? 4 : 1,
        color: isSel ? Colors.indigo.shade50 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSel ? Colors.indigo : Colors.grey.shade300,
            width: isSel ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSel ? Colors.indigo : Colors.grey.shade200,
                ),
                child: Center(
                  child: Text(opt,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isSel ? Colors.white : Colors.black87,
                      )),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(text ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    )),
              ),
              if (isSel) const Icon(Icons.check_circle, color: Colors.indigo),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusMsg extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String msg;
  final Color bg;

  const _StatusMsg({
    required this.icon,
    required this.color,
    required this.msg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

class _FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final String videoTitle;
  final bool wasPlaying;

  const _FullScreenVideoPlayer({
    required this.controller,
    required this.videoTitle,
    required this.wasPlaying,
  });

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  @override
  void initState() {
    super.initState();
    if (widget.wasPlaying && !widget.controller.value.isPlaying) {
      widget.controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.videoTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: widget.controller.value.aspectRatio,
          child: VideoPlayer(widget.controller),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white.withOpacity(0.7),
        onPressed: () {
          setState(() {
            widget.controller.value.isPlaying
                ? widget.controller.pause()
                : widget.controller.play();
          });
        },
        child: Icon(
          widget.controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.black,
        ),
      ),
    );
  }
}