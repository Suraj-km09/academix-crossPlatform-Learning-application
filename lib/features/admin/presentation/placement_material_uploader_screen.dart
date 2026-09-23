import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../placement/domain/placement_providers.dart';
import '../../../core/constants/firestore_paths.dart';

class PlacementMaterialUploaderScreen extends ConsumerStatefulWidget {
  final String? initialSubjectId;
  const PlacementMaterialUploaderScreen({super.key, this.initialSubjectId});

  @override
  ConsumerState<PlacementMaterialUploaderScreen> createState() =>
      _PlacementMaterialUploaderScreenState();
}

class _PlacementMaterialUploaderScreenState
    extends ConsumerState<PlacementMaterialUploaderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedSubjectId;
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  double _uploadProgress = 0;
  bool _isSyllabus = false;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb, // Only need data in memory for Web
    );

    if (result != null) {
      setState(() => _selectedFile = result.files.first);
      if (_titleController.text.isEmpty && !_isSyllabus) {
        // Auto-fill title from filename if not a syllabus
        final name = _selectedFile!.name.split('.').first;
        _titleController.text = name.replaceAll('_', ' ').replaceAll('-', ' ');
      }
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate() ||
        _selectedFile == null ||
        _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select a PDF'),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      // 1. Upload to Firebase Storage
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${_selectedFile!.name}';
      final storageRef = FirebaseStorage.instance.ref().child(
        'placement_materials/$_selectedSubjectId/$fileName',
      );

      final UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = storageRef.putData(_selectedFile!.bytes!);
      } else {
        uploadTask = storageRef.putFile(File(_selectedFile!.path!));
      }

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // 2. Save to Firestore
      await FirebaseFirestore.instance
          .collection(FirestorePaths.placementCourseMaterial)
          .add({
            'subjectId': _selectedSubjectId,
            'title': _isSyllabus ? 'Syllabus' : _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'type': 'pdf',
            'file_url': downloadUrl,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Material uploaded successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(placementSubjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Placement Material')),
      body: subjectsAsync.when(
        data: (subjects) {
          final isValidSubject = subjects.any(
            (s) => s.id == _selectedSubjectId,
          );
          final dropdownValue = isValidSubject ? _selectedSubjectId : null;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Section Info
                const Text(
                  'Add PDF Notes or Syllabus',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Syllabus Toggle
                SwitchListTile(
                  title: const Text('Is this a Subject Syllabus?'),
                  subtitle: const Text(
                    'Check this if you are uploading the official syllabus.',
                  ),
                  value: _isSyllabus,
                  onChanged: (val) {
                    setState(() {
                      _isSyllabus = val;
                      if (_isSyllabus) {
                        _titleController.text = 'Syllabus';
                      } else {
                        _titleController.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Subject Dropdown
                DropdownButtonFormField<String>(
                  value: dropdownValue,
                  decoration: const InputDecoration(
                    labelText: 'Select Subject',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.subject),
                  ),
                  items: subjects
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedSubjectId = val),
                  validator: (val) =>
                      val == null ? 'Please select a subject' : null,
                ),
                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleController,
                  enabled: !_isSyllabus,
                  decoration: InputDecoration(
                    labelText: 'Document Title',
                    hintText: 'e.g., Unit 1 Notes',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.title),
                    filled: _isSyllabus,
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                // File Picker
                InkWell(
                  onTap: _isUploading ? null : _pickFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _selectedFile == null
                          ? Colors.grey.shade100
                          : Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedFile == null
                            ? Colors.grey.shade300
                            : Colors.green,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _selectedFile == null
                              ? Icons.upload_file_rounded
                              : Icons.check_circle_rounded,
                          size: 48,
                          color: _selectedFile == null
                              ? Colors.grey
                              : Colors.green,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFile == null
                              ? 'Tap to select PDF'
                              : _selectedFile!.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedFile == null
                                ? Colors.black54
                                : Colors.green,
                          ),
                        ),
                        if (_selectedFile != null)
                          Text(
                            '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Progress & Button
                if (_isUploading) ...[
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Center(child: Text('${(_uploadProgress * 100).toInt()}%')),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _upload,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUploading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Confirm & Upload',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
      ),
    );
  }
}
