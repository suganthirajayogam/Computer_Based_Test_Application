// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';
// import 'package:computer_based_test/database/database_helper.dart';
// import 'dart:io';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:path_provider/path_provider.dart';
// import 'package:intl/intl.dart';
// import 'package:path/path.dart' as path;

// // NOTE: You must add the 'permission_handler' package to your pubspec.yaml
// // and implement the actual permission request in _loadVideos() for Android/iOS.
// // import 'package:permission_handler/permission_handler.dart'; 

// class VideoCertificationScreen extends StatefulWidget {
//   final Map<String, dynamic> employee;
//   final String module;

//   const VideoCertificationScreen({
//     super.key,
//     required this.employee,
//     required this.module,
//   });

//   @override
//   State<VideoCertificationScreen> createState() => _VideoCertificationScreenState();
// }

// class _VideoCertificationScreenState extends State<VideoCertificationScreen> {
//   List<Map<String, dynamic>> _videos = [];
//   int _currentVideoIndex = 0;
//   VideoPlayerController? _controller;
//   bool _isLoading = true;
//   // Use duration in seconds to check completion more reliably
//   Duration? _videoDuration;
//   Duration? _videoPosition;
//   bool _videoCompleted = false; 
//   bool _allVideosWatched = false;
//   Set<int> _watchedVideos = {};

//   @override
//   void initState() {
//     super.initState();
//     _loadVideos();
//   }

//   Future<void> _loadVideos() async {
//     setState(() {
//       _isLoading = true;
//     });

//     // === FIX 1: Add Runtime Permission Request for file access ===
//     // You should use a package like 'permission_handler' here to request 
//     // storage permissions (or MANAGE_EXTERNAL_STORAGE for Android 11+).
//     // if (await Permission.storage.request().isDenied) {
//     //   // Handle permission denial, maybe show an error and pop.
//     // }
//     // =============================================================

//     try {
//       final videos = await Database_helper.instance.getVideosByModule(widget.module);
      
//       if (!mounted) return;

//       if (videos.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('No videos found for this module')),
//         );
//         Navigator.pop(context);
//         return;
//       }

//       setState(() {
//         _videos = videos;
//         _isLoading = false;
//       });
//       _initializeVideo();
//     } catch (e) {
//       print('Error loading videos: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error loading videos: $e')),
//         );
//         Navigator.pop(context); // Pop on severe error
//       }
//     }
//   }

//   void _initializeVideo() async {
//     if (_videos.isEmpty || _currentVideoIndex >= _videos.length) return;

//     final videoPath = _videos[_currentVideoIndex]['video_path'];
//     final file = File(videoPath);

//     // Dispose previous controller and remove listener before creating a new one
//     _controller?.removeListener(_videoListener);
//     await _controller?.dispose();

//     // === FIX 2: Check if file exists to debug permission/path issue ===
//     if (!await file.exists()) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Video file not found at path: $videoPath. Check permissions and file location.')),
//         );
//       }
//       return;
//     }
//     // =================================================================

//     _controller = VideoPlayerController.file(file);

//     await _controller!.initialize();

//     if (!mounted) return;

//     // Set state after initialization is complete
//     setState(() {
//       _videoCompleted = _watchedVideos.contains(_currentVideoIndex);
//     });

//     _controller!.addListener(_videoListener);
    
//     // === FIX 3: Start playback immediately to trigger the listener ===
//     await _controller!.play();
//     // =================================================================
//   }

//   void _videoListener() {
//     if (_controller == null || !_controller!.value.isInitialized) return;
    
//     final position = _controller!.value.position;
//     final duration = _controller!.value.duration;
    
//     // Update state to reflect position and duration for the UI
//     setState(() {
//       _videoPosition = position;
//       _videoDuration = duration;
//     });

//     // Check if video is 95% complete AND not already marked complete
//     if (duration.inSeconds > 0 && 
//         position.inSeconds >= (duration.inSeconds * 0.95) &&
//         !_watchedVideos.contains(_currentVideoIndex)) {
//       setState(() {
//         _videoCompleted = true;
//         _watchedVideos.add(_currentVideoIndex);
//       });
//       // Optionally pause the video once 95% is reached
//       _controller!.pause();
//     }
//   }

//   void _nextVideo() {
//     if (_currentVideoIndex < _videos.length - 1) {
//       // Check if the current video has been watched before moving to the next
//       if (!_watchedVideos.contains(_currentVideoIndex)) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Please watch the current video to proceed.')),
//         );
//         return;
//       }
      
//       setState(() {
//         _currentVideoIndex++;
//         // Check if the next video is already watched
//         _videoCompleted = _watchedVideos.contains(_currentVideoIndex); 
//       });
//       _initializeVideo();
//     } else {
//       // Last video, and it must be watched
//       if (_watchedVideos.contains(_currentVideoIndex)) {
//         setState(() {
//           _allVideosWatched = true;
//           // Ensure the final video is paused to show the certificate button clearly
//           _controller?.pause(); 
//         });
//       } else {
//          ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Please watch the final video to complete the module.')),
//         );
//       }
//     }
//   }

//   void _previousVideo() {
//     if (_currentVideoIndex > 0) {
//       setState(() {
//         _currentVideoIndex--;
//         _allVideosWatched = false; // Going back means not all videos are watched yet
//         _videoCompleted = _watchedVideos.contains(_currentVideoIndex);
//       });
//       _initializeVideo();
//     }
//   }

//   Future<void> _generateCertificate() async {
//     // ... (Your existing _generateCertificate function is mostly fine, 
//     // so I'm omitting the verbose PDF part here for brevity, assuming it works.)
//     // ... (Keep the existing _generateCertificate function here)

//     try {
//       final pdf = pw.Document();
      
//       pdf.addPage(
//         pw.Page(
//           pageFormat: PdfPageFormat.a4.landscape,
//           build: (context) {
//             return pw.Container(
//               decoration: pw.BoxDecoration(
//                 border: pw.Border.all(color: PdfColors.blue900, width: 10),
//               ),
//               padding: const pw.EdgeInsets.all(40),
//               child: pw.Column(
//                 mainAxisAlignment: pw.MainAxisAlignment.center,
//                 children: [
//                   pw.Container(
//                     padding: const pw.EdgeInsets.all(10),
//                     decoration: pw.BoxDecoration(
//                       border: pw.Border.all(color: PdfColors.blue700, width: 3),
//                     ),
//                     child: pw.Text(
//                       'CERTIFICATE OF COMPLETION',
//                       style: pw.TextStyle(
//                         fontSize: 40,
//                         fontWeight: pw.FontWeight.bold,
//                         color: PdfColors.blue900,
//                       ),
//                     ),
//                   ),
//                   pw.SizedBox(height: 30),
//                   pw.Text(
//                     'This is to certify that',
//                     style: const pw.TextStyle(fontSize: 18),
//                   ),
//                   pw.SizedBox(height: 20),
//                   pw.Text(
//                     widget.employee['employeeName']?.toString() ?? '',
//                     style: pw.TextStyle(
//                       fontSize: 35,
//                       fontWeight: pw.FontWeight.bold,
//                       color: PdfColors.blue800,
//                     ),
//                   ),
//                   pw.SizedBox(height: 10),
//                   pw.Text(
//                     'Employee ID: ${widget.employee['employeeId']?.toString() ?? ''}',
//                     style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
//                   ),
//                   pw.SizedBox(height: 30),
//                   pw.Text(
//                     'has successfully completed the training module',
//                     style: const pw.TextStyle(fontSize: 18),
//                   ),
//                   pw.SizedBox(height: 20),
//                   pw.Container(
//                     padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                     decoration: pw.BoxDecoration(
//                       color: PdfColors.blue50,
//                       border: pw.Border.all(color: PdfColors.blue300),
//                       borderRadius: pw.BorderRadius.circular(10),
//                     ),
//                     child: pw.Text(
//                       widget.module,
//                       style: pw.TextStyle(
//                         fontSize: 28,
//                         fontWeight: pw.FontWeight.bold,
//                         color: PdfColors.blue900,
//                       ),
//                     ),
//                   ),
//                   pw.SizedBox(height: 30),
//                   pw.Text(
//                     'Date: ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
//                     style: const pw.TextStyle(fontSize: 16),
//                   ),
//                   pw.SizedBox(height: 40),
//                   pw.Row(
//                     mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
//                     children: [
//                       pw.Column(
//                         children: [
//                           pw.Container(
//                             width: 200,
//                             height: 2,
//                             color: PdfColors.black,
//                           ),
//                           pw.SizedBox(height: 5),
//                           pw.Text('Authorized Signature'),
//                         ],
//                       ),
//                       pw.Column(
//                         children: [
//                           pw.Container(
//                             width: 200,
//                             height: 2,
//                             color: PdfColors.black,
//                           ),
//                           pw.SizedBox(height: 5),
//                           pw.Text('Training Coordinator'),
//                         ],
//                       ),
//                     ],
//                   ),
//                   pw.Spacer(),
//                   pw.Text(
//                     'Visteon India Pvt. Ltd.',
//                     style: pw.TextStyle(
//                       fontSize: 16,
//                       color: PdfColors.orange,
//                       fontWeight: pw.FontWeight.bold,
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//       );

//       final documentsDir = await getApplicationDocumentsDirectory();
//       final folderPath = path.join(documentsDir.path, 'Certificates');
//       final directory = Directory(folderPath);
//       if (!await directory.exists()) {
//         await directory.create(recursive: true);
//       }

//       final fileName = '${widget.employee['employeeId']}_${widget.module}_Certificate.pdf'
//           .replaceAll(' ', '_');
//       final filePath = path.join(folderPath, fileName);

//       final file = File(filePath);
//       await file.writeAsBytes(await pdf.save());

//       if (!mounted) return;
      
//       showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: const Text('Certificate Generated!'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Icon(Icons.check_circle, color: Colors.green, size: 60),
//               const SizedBox(height: 20),
//               Text('Certificate saved to:\n$filePath'),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 Navigator.of(context).popUntil((route) => route.isFirst);
//               },
//               child: const Text('OK'),
//             ),
//           ],
//         ),
//       );
//     } catch (e) {
//       print('Error generating certificate: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error generating certificate: $e')),
//         );
//       }
//     }
//   }

//   @override
//   void dispose() {
//     // === FIX 4: Ensure controller is disposed safely ===
//     _controller?.removeListener(_videoListener);
//     _controller?.dispose();
//     // ===================================================
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     if (_videos.isEmpty) {
//       return Scaffold(
//         appBar: AppBar(title: const Text('Video Training')),
//         body: const Center(child: Text('No videos available')),
//       );
//     }

//     final currentVideo = _videos[_currentVideoIndex];
//     final bool isLastVideo = _currentVideoIndex == _videos.length - 1;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('${widget.module} - Training'),
//         backgroundColor: Colors.indigo,
//       ),
//       body: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(16),
//             color: Colors.blue.shade50,
//             child: Row(
//               children: [
//                 CircleAvatar(
//                   child: Text('${widget.employee['employeeName']?[0] ?? 'U'}'),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         widget.employee['employeeName'] ?? '',
//                         style: const TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       Text('ID: ${widget.employee['employeeId'] ?? ''}'),
//                     ],
//                   ),
//                 ),
//                 Text(
//                   'Video ${_currentVideoIndex + 1} of ${_videos.length}',
//                   style: const TextStyle(fontWeight: FontWeight.bold),
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   // Video Player Section
//                   if (_controller != null && _controller!.value.isInitialized)
//                     GestureDetector(
//                       onTap: () {
//                         setState(() {
//                           _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
//                         });
//                       },
//                       child: AspectRatio(
//                         aspectRatio: _controller!.value.aspectRatio,
//                         child: VideoPlayer(_controller!),
//                       ),
//                     )
//                   else
//                     Container(
//                       height: 400,
//                       color: Colors.black,
//                       child: Center(
//                         child: _controller == null ? 
//                           const Text('Initializing Video...', style: TextStyle(color: Colors.white)) :
//                           const CircularProgressIndicator(color: Colors.white)
//                       ),
//                     ),
                    
//                   // Progress Bar
//                   if (_controller != null && _controller!.value.isInitialized)
//                     VideoProgressIndicator(
//                       _controller!,
//                       allowScrubbing: false,
//                       colors: const VideoProgressColors(
//                         playedColor: Colors.blue,
//                         bufferedColor: Colors.grey,
//                       ),
//                     ),
                    
//                   // Controls
//                   Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         // Previous Button
//                         IconButton(
//                           onPressed: _currentVideoIndex > 0 ? _previousVideo : null,
//                           icon: const Icon(Icons.skip_previous),
//                           color: _currentVideoIndex > 0 ? Colors.indigo : Colors.grey,
//                         ),
//                         // Play/Pause Button
//                         IconButton(
//                           onPressed: () {
//                             setState(() {
//                               _controller!.value.isPlaying
//                                   ? _controller!.pause()
//                                   : _controller!.play();
//                             });
//                           },
//                           icon: Icon(
//                             _controller?.value.isPlaying ?? false
//                                 ? Icons.pause_circle_filled
//                                 : Icons.play_circle_fill,
//                             size: 48,
//                           ),
//                           color: Colors.indigo,
//                         ),
//                         // Next Button
//                         IconButton(
//                           onPressed: _videoCompleted && !_allVideosWatched ? _nextVideo : null,
//                           icon: isLastVideo ? const Icon(Icons.check_circle_outline) : const Icon(Icons.skip_next),
//                           color: _videoCompleted ? Colors.indigo : Colors.grey,
//                         ),
//                       ],
//                     ),
//                   ),
                  
//                   // Video Info and Status
//                   Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           currentVideo['title'] ?? 'Untitled',
//                           style: const TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(currentVideo['description'] ?? ''),
//                         const SizedBox(height: 20),
                        
//                         // Status Messages
//                         if (!_videoCompleted && !_allVideosWatched)
//                           _StatusMessage(
//                             icon: Icons.info,
//                             color: Colors.orange,
//                             message: 'Watch at least 95% of the video to proceed.',
//                             backgroundColor: Colors.orange.shade100,
//                           ),
                          
//                         if (_videoCompleted && !_allVideosWatched && !isLastVideo)
//                           _StatusMessage(
//                             icon: Icons.check_circle,
//                             color: Colors.green,
//                             message: 'Video completed! Click next to continue.',
//                             backgroundColor: Colors.green.shade100,
//                           ),
                          
//                         if (_videoCompleted && isLastVideo && !_allVideosWatched)
//                           _StatusMessage(
//                             icon: Icons.check_circle,
//                             color: Colors.green,
//                             message: 'Final video completed. Click Next to finish the module.',
//                             backgroundColor: Colors.green.shade100,
//                           ),

//                         if (_allVideosWatched)
//                           Column(
//                             children: [
//                               _StatusMessage(
//                                 icon: Icons.celebration,
//                                 color: Colors.blue,
//                                 message: 'Congratulations! All videos completed.',
//                                 backgroundColor: Colors.blue.shade100,
//                               ),
//                               const SizedBox(height: 20),
//                               ElevatedButton.icon(
//                                 onPressed: _generateCertificate,
//                                 icon: const Icon(Icons.workspace_premium),
//                                 label: const Text('Generate Certificate'),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.green,
//                                   foregroundColor: Colors.white,
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 40,
//                                     vertical: 16,
//                                   ),
//                                   textStyle: const TextStyle(fontSize: 18),
//                                 ),
//                               ),
//                             ],
//                           ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // Helper Widget for Status Messages
// class _StatusMessage extends StatelessWidget {
//   final IconData icon;
//   final Color color;
//   final String message;
//   final Color backgroundColor;

//   const _StatusMessage({
//     required this.icon,
//     required this.color,
//     required this.message,
//     required this.backgroundColor,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: backgroundColor,
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         children: [
//           Icon(icon, color: color),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               message,
//               style: const TextStyle(fontWeight: FontWeight.bold),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }