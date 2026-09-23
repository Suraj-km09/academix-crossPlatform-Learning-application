import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/resume_data.dart';
import '../domain/resume_template.dart';

class ResumePdfService {
  static Future<Uint8List> generateResume(
    ResumeData data,
    ResumeTemplate template,
  ) async {
    final pdf = pw.Document();

    pw.ImageProvider? profileImage;
    if (data.profileImagePath != null && data.profileImagePath!.isNotEmpty) {
      try {
        final file = File(data.profileImagePath!);
        if (file.existsSync()) {
          profileImage = pw.MemoryImage(file.readAsBytesSync());
        }
      } catch (e) {
        developer.log(
          'Error loading profile image: $e',
          name: 'ResumePdfService',
        );
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          switch (template.type) {
            case 'modern':
              return _buildExecutiveModernLayout(data, profileImage);
            case 'minimal':
              return _buildMinimalistLayout(data);
            case 'fresher':
              return _buildStudentModernLayout(data, profileImage);
            case 'classic':
            default:
              return _buildProfessionalClassicLayout(data);
          }
        },
      ),
    );

    return pdf.save();
  }

  // Helper to build section titles with a line
  static pw.Widget _buildSectionTitle(
    String title,
    PdfColor color, {
    double fontSize = 14,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: pw.FontWeight.bold,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Container(height: 1.5, width: 40, color: color),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // 1. Professional Classic
  static List<pw.Widget> _buildProfessionalClassicLayout(ResumeData data) {
    return [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      data.fullName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.Text(
                      data.jobTitle.toUpperCase(),
                      style: const pw.TextStyle(
                        fontSize: 16,
                        letterSpacing: 3,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (data.phone.isNotEmpty)
                      pw.Text(
                        data.phone,
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    if (data.email.isNotEmpty)
                      pw.Text(
                        data.email,
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    if (data.address.isNotEmpty)
                      pw.Text(
                        data.address,
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.black, height: 40),

            if (data.summary.isNotEmpty) ...[
              _buildSectionTitle('PROFESSIONAL SUMMARY', PdfColors.black),
              pw.Text(
                data.summary,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
              ),
              pw.SizedBox(height: 30),
            ],

            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left Column
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (data.skills.isNotEmpty) ...[
                        _buildSectionTitle('SKILLS', PdfColors.black),
                        ...data.skills.map(
                          (s) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text(
                              '• $s',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 30),
                      ],
                      if (data.languages.isNotEmpty) ...[
                        _buildSectionTitle('LANGUAGES', PdfColors.black),
                        ...data.languages.map(
                          (l) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Text(
                              '• $l',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 30),
                      ],
                      if (data.education.isNotEmpty) ...[
                        _buildSectionTitle('EDUCATION', PdfColors.black),
                        ...data.education.map(
                          (e) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 15),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  e.degree,
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                pw.Text(
                                  e.institution,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                                pw.Text(
                                  '${e.year} | Score: ${e.score}',
                                  style: const pw.TextStyle(
                                    fontSize: 10,
                                    color: PdfColors.grey800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(width: 30),
                // Vertical Line
                pw.Container(width: 1, height: 450, color: PdfColors.grey300),
                pw.SizedBox(width: 30),
                // Right Column
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (data.experience.isNotEmpty) ...[
                        _buildSectionTitle('WORK EXPERIENCE', PdfColors.black),
                        ...data.experience.map(
                          (e) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 20),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  e.jobTitle.toUpperCase(),
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                pw.Text(
                                  '${e.company} | ${e.location}',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.blueGrey800,
                                  ),
                                ),
                                pw.Text(
                                  '${e.startDate} - ${e.endDate}',
                                  style: const pw.TextStyle(
                                    fontSize: 10,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                                pw.Text(
                                  e.description,
                                  style: const pw.TextStyle(
                                    fontSize: 11,
                                    lineSpacing: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (data.projects.isNotEmpty) ...[
                        _buildSectionTitle('PROJECTS', PdfColors.black),
                        ...data.projects.map(
                          (p) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 15),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  p.title,
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                if (p.link.isNotEmpty)
                                  pw.Text(
                                    p.link,
                                    style: const pw.TextStyle(
                                      fontSize: 9,
                                      color: PdfColors.blue,
                                    ),
                                  ),
                                pw.Text(
                                  p.description,
                                  style: const pw.TextStyle(
                                    fontSize: 10,
                                    lineSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 15),
                      ],
                      if (data.achievements.isNotEmpty) ...[
                        _buildSectionTitle('ACHIEVEMENTS', PdfColors.black),
                        ...data.achievements.map(
                          (a) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 5),
                            child: pw.Bullet(
                              text: a,
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 15),
                      ],
                      if (data.linkedin != null ||
                          data.github != null ||
                          data.leetcode != null ||
                          data.portfolio != null) ...[
                        _buildSectionTitle('PROFILES', PdfColors.black),
                        if (data.linkedin != null && data.linkedin!.isNotEmpty)
                          _buildLinkItem('LinkedIn', data.linkedin!),
                        if (data.github != null && data.github!.isNotEmpty)
                          _buildLinkItem('GitHub', data.github!),
                        if (data.leetcode != null && data.leetcode!.isNotEmpty)
                          _buildLinkItem('LeetCode', data.leetcode!),
                        if (data.portfolio != null &&
                            data.portfolio!.isNotEmpty)
                          _buildLinkItem('Portfolio', data.portfolio!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  static pw.Widget _buildLinkItem(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.TextSpan(
              text: value,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Executive Modern
  static List<pw.Widget> _buildExecutiveModernLayout(
    ResumeData data,
    pw.ImageProvider? profileImage,
  ) {
    final primaryColor = PdfColor.fromHex('#1A2A3A');
    final accentColor = PdfColor.fromHex('#C5A059'); // Muted Gold

    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Sidebar
          pw.Container(
            width: 200,
            color: primaryColor,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 40,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (profileImage != null)
                  pw.Center(
                    child: pw.Container(
                      height: 120,
                      width: 120,
                      margin: const pw.EdgeInsets.only(bottom: 30),
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: accentColor, width: 3),
                        image: pw.DecorationImage(
                          image: profileImage,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                _buildModernSidebarHeader('CONTACT', accentColor),
                _buildModernContactTextItem('PHONE:', data.phone, accentColor),
                _buildModernContactTextItem('EMAIL:', data.email, accentColor),
                _buildModernContactTextItem('ADDR:', data.address, accentColor),
                if (data.linkedin != null && data.linkedin!.isNotEmpty)
                  _buildModernContactTextItem('LINK:', 'LinkedIn', accentColor),

                pw.SizedBox(height: 30),
                _buildModernSidebarHeader('SKILLS', accentColor),
                ...data.skills.map(
                  (s) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Text(
                      s,
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),

                pw.SizedBox(height: 30),
                _buildModernSidebarHeader('EDUCATION', accentColor),
                ...data.education.map(
                  (e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 15),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          e.year,
                          style: pw.TextStyle(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          e.degree,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        pw.Text(
                          e.institution,
                          style: const pw.TextStyle(
                            color: PdfColors.grey300,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (data.achievements.isNotEmpty) ...[
                  pw.SizedBox(height: 30),
                  _buildModernSidebarHeader('ACHIEVEMENTS', accentColor),
                  ...data.achievements.map(
                    (a) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Text(
                        '• $a',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Main Content
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 35,
                vertical: 50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.fullName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 38,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.Text(
                    data.jobTitle.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 18,
                      color: accentColor,
                      letterSpacing: 3,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 40),

                  _buildModernSectionHeader(
                    'PROFILE',
                    primaryColor,
                    accentColor,
                  ),
                  pw.Text(
                    data.summary,
                    style: const pw.TextStyle(fontSize: 11, lineSpacing: 5),
                  ),
                  pw.SizedBox(height: 35),

                  _buildModernSectionHeader(
                    'EXPERIENCE',
                    primaryColor,
                    accentColor,
                  ),
                  ...data.experience.map(
                    (e) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 25),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 80,
                            child: pw.Text(
                              e.startDate.split(' ').last,
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  e.jobTitle,
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 13,
                                    color: primaryColor,
                                  ),
                                ),
                                pw.Text(
                                  '${e.company} | ${e.location}',
                                  style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                                pw.Text(
                                  e.description,
                                  style: const pw.TextStyle(
                                    fontSize: 11,
                                    lineSpacing: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (data.projects.isNotEmpty) ...[
                    _buildModernSectionHeader(
                      'PROJECTS',
                      primaryColor,
                      accentColor,
                    ),
                    ...data.projects.map(
                      (p) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 20),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              p.title.toUpperCase(),
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 12,
                                color: primaryColor,
                              ),
                            ),
                            if (p.link.isNotEmpty)
                              pw.Text(
                                p.link,
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.blue,
                                ),
                              ),
                            pw.Text(
                              p.description,
                              style: const pw.TextStyle(
                                fontSize: 11,
                                lineSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (data.languages.isNotEmpty) ...[
                    _buildModernSectionHeader(
                      'LANGUAGES',
                      primaryColor,
                      accentColor,
                    ),
                    pw.Wrap(
                      spacing: 20,
                      children: data.languages
                          .map(
                            (l) => pw.Text(
                              l,
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  static pw.Widget _buildModernSidebarHeader(String title, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
        ),
        pw.Container(
          height: 2,
          width: 30,
          color: color,
          margin: const pw.EdgeInsets.only(top: 5, bottom: 12),
        ),
      ],
    );
  }

  static pw.Widget _buildModernContactTextItem(
    String label,
    String text,
    PdfColor accentColor,
  ) {
    if (text.isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: accentColor,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
          ),
          pw.Text(
            text,
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildModernSectionHeader(
    String title,
    PdfColor primary,
    PdfColor accent,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: primary,
            letterSpacing: 1.5,
          ),
        ),
        pw.Divider(color: accent, thickness: 2, height: 15),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // 3. Minimalist
  static List<pw.Widget> _buildMinimalistLayout(ResumeData data) {
    return [
      pw.Padding(
        padding: const pw.EdgeInsets.all(50),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              data.fullName.toUpperCase(),
              style: pw.TextStyle(fontSize: 34, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              data.jobTitle,
              style: const pw.TextStyle(fontSize: 18, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              children: [
                if (data.email.isNotEmpty)
                  _buildMinimalContactTextItem('Email:', data.email),
                if (data.phone.isNotEmpty)
                  _buildMinimalContactTextItem('Phone:', data.phone),
                if (data.address.isNotEmpty)
                  _buildMinimalContactTextItem('Address:', data.address),
              ],
            ),
            pw.Divider(height: 40, thickness: 1),

            _buildMinimalHeader('EXPERIENCE'),
            ...data.experience.map(
              (e) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          e.jobTitle,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        pw.Text(
                          '${e.startDate} - ${e.endDate}',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    pw.Text(
                      '${e.company}, ${e.location}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Bullet(
                      text: e.description,
                      style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
                    ),
                  ],
                ),
              ),
            ),

            _buildMinimalHeader('EDUCATION'),
            ...data.education.map(
              (e) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          e.degree,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.Text(
                          e.institution,
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    pw.Text(e.year, style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),

            if (data.projects.isNotEmpty) ...[
              _buildMinimalHeader('PROJECTS'),
              ...data.projects.map(
                (p) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        p.title,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (p.link.isNotEmpty)
                        pw.Text(
                          p.link,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.blue,
                          ),
                        ),
                      pw.Text(
                        p.description,
                        style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            pw.SizedBox(height: 20),
            _buildMinimalHeader('SKILLS'),
            pw.Wrap(
              spacing: 15,
              runSpacing: 10,
              children: data.skills
                  .map(
                    (s) => pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(5),
                        ),
                      ),
                      child: pw.Text(
                        s,
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ),
                  )
                  .toList(),
            ),

            if (data.achievements.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _buildMinimalHeader('ACHIEVEMENTS'),
              ...data.achievements.map(
                (a) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                    '• $a',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  static pw.Widget _buildMinimalContactTextItem(String label, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(right: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildMinimalHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Container(height: 2, width: 25, color: PdfColors.black),
        pw.SizedBox(height: 15),
      ],
    );
  }

  // 4. Student Modern
  static List<pw.Widget> _buildStudentModernLayout(
    ResumeData data,
    pw.ImageProvider? profileImage,
  ) {
    final themeColor = PdfColor.fromHex('#2196F3');

    return [
      pw.Padding(
        padding: const pw.EdgeInsets.all(35),
        child: pw.Column(
          children: [
            pw.Row(
              children: [
                if (profileImage != null)
                  pw.Container(
                    height: 110,
                    width: 110,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: themeColor, width: 2),
                      image: pw.DecorationImage(
                        image: profileImage,
                        fit: pw.BoxFit.cover,
                      ),
                    ),
                  ),
                pw.SizedBox(width: 30),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        data.fullName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 40,
                          color: themeColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        data.jobTitle,
                        style: const pw.TextStyle(
                          fontSize: 22,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        children: [
                          if (data.email.isNotEmpty)
                            pw.Text(
                              data.email,
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          if (data.email.isNotEmpty && data.phone.isNotEmpty)
                            pw.Text(
                              ' | ',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          if (data.phone.isNotEmpty)
                            pw.Text(
                              data.phone,
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 3, color: themeColor),
            pw.SizedBox(height: 25),

            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildStudentSidebarSection('SKILLS', themeColor),
                      ...data.skills.map(
                        (s) => _buildStudentSkillBar(s, themeColor),
                      ),

                      pw.SizedBox(height: 30),
                      _buildStudentSidebarSection('ACHIEVEMENTS', themeColor),
                      ...data.achievements.map(
                        (a) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 5),
                          child: pw.Text(
                            '• $a',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                      ),

                      pw.SizedBox(height: 30),
                      _buildStudentSidebarSection('LANGUAGES', themeColor),
                      ...data.languages.map(
                        (l) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 6),
                          child: pw.Text(
                            '• $l',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                      ),

                      pw.SizedBox(height: 30),
                      _buildStudentSidebarSection('LINKS', themeColor),
                      if (data.github != null && data.github!.isNotEmpty)
                        pw.Text(
                          'GitHub: ${data.github}',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.blue,
                          ),
                        ),
                      if (data.linkedin != null && data.linkedin!.isNotEmpty)
                        pw.Text(
                          'LinkedIn: ${data.linkedin}',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.blue,
                          ),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 40),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildStudentMainHeader('CAREER OBJECTIVE', themeColor),
                      pw.Text(
                        data.summary,
                        style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
                      ),

                      pw.SizedBox(height: 30),
                      _buildStudentMainHeader('EDUCATION', themeColor),
                      ...data.education.map(
                        (e) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 15),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Container(
                                width: 60,
                                child: pw.Text(
                                  e.year,
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 11,
                                    color: themeColor,
                                  ),
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      e.degree.toUpperCase(),
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    pw.Text(
                                      e.institution,
                                      style: const pw.TextStyle(
                                        fontSize: 11,
                                        color: PdfColors.grey900,
                                      ),
                                    ),
                                    pw.Text(
                                      'Score: ${e.score}',
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        fontStyle: pw.FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      pw.SizedBox(height: 20),
                      _buildStudentMainHeader(
                        'PROJECTS / EXPERIENCE',
                        themeColor,
                      ),
                      ...data.experience.map(
                        (e) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 20),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                e.jobTitle,
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              pw.Text(
                                e.company,
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                e.description,
                                style: const pw.TextStyle(
                                  fontSize: 11,
                                  lineSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      ...data.projects.map(
                        (p) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 20),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                p.title,
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              if (p.link.isNotEmpty)
                                pw.Text(
                                  p.link,
                                  style: const pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColors.blue,
                                  ),
                                ),
                              pw.Text(
                                p.description,
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                  lineSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  static pw.Widget _buildStudentSidebarSection(String title, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        pw.Container(
          height: 2,
          width: 30,
          color: color,
          margin: const pw.EdgeInsets.only(top: 4, bottom: 10),
        ),
      ],
    );
  }

  static pw.Widget _buildStudentSkillBar(String skill, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(skill, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 4),
          pw.Container(
            height: 6,
            width: double.infinity,
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Container(height: 6, width: 80, color: color),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStudentMainHeader(String title, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        pw.Divider(thickness: 1.5, color: color, height: 15),
        pw.SizedBox(height: 10),
      ],
    );
  }
}
