import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../placement/domain/placement_providers.dart';

class InterviewPdfUploaderScreen extends ConsumerStatefulWidget {
  const InterviewPdfUploaderScreen({super.key});

  @override
  ConsumerState<InterviewPdfUploaderScreen> createState() => _InterviewPdfUploaderScreenState();
}

class _InterviewPdfUploaderScreenState extends ConsumerState<InterviewPdfUploaderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  
  String? _selectedSubjectId;
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  double _uploadProgress = 0;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() => _selectedFile = result.files.first);
      if (_titleController.text.isEmpty) {
        final name = _selectedFile!.name.split('.').first;
        _titleController.text = name.replaceAll('_', ' ').replaceAll('-', ' ');
      }
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate() || _selectedFile == null || _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete the form')));
      return;
    }

    setState(() { _isUploading = true; _uploadProgress = 0; });

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedFile!.name}';
      final storageRef = FirebaseStorage.instance.ref().child('interview_pdfs/$_selectedSubjectId/$fileName');
      
      final uploadTask = storageRef.putData(_selectedFile!.bytes!);
      uploadTask.snapshotEvents.listen((s) => setState(() => _uploadProgress = s.bytesTransferred / s.totalBytes));

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('interview_pdfs').add({
        'subjectId': _selectedSubjectId,
        'title': _titleController.text.trim(),
        'pdfUrl': downloadUrl,
        'size': _selectedFile!.size,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'order': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploaded successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(placementSubjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Interview PDF')),
      body: subjectsAsync.when(
        data: (subjects) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DropdownButtonFormField<String>(
                value: _selectedSubjectId,
                decoration: const InputDecoration(labelText: 'Select Subject', border: OutlineInputBorder()),
                items: subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                onChanged: (val) => setState(() => _selectedSubjectId = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'PDF Title', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: _isUploading ? null : _pickFile,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Icon(_selectedFile == null ? Icons.upload_file : Icons.check_circle, size: 48, color: _selectedFile == null ? Colors.grey : Colors.green),
                      const SizedBox(height: 12),
                      Text(_selectedFile == null ? 'Select Interview PDF' : _selectedFile!.name, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_isUploading) LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _isUploading ? null : _upload, child: const Text('Upload PDF')),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
