import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../domain/resume_data.dart';
import '../domain/resume_template.dart';
import '../services/resume_pdf_service.dart';

class ResumePdfPreviewScreen extends StatelessWidget {
  final ResumeData resumeData;
  final ResumeTemplate template;

  const ResumePdfPreviewScreen({
    super.key,
    required this.resumeData,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${template.name} Preview'),
      ),
      body: PdfPreview(
        initialPageFormat: PdfPageFormat.a4,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        build: (format) => ResumePdfService.generateResume(resumeData, template),
        onPrinted: (context) => _showSnackBar(context, "Printed successfully"),
        onShared: (context) => _showSnackBar(context, "Shared successfully"),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
