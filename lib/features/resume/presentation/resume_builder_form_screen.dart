import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/resume_data.dart';
import '../domain/resume_template.dart';
import 'resume_pdf_preview_screen.dart';

final resumeDataProvider = StateProvider<ResumeData>((ref) => ResumeData());

class ResumeBuilderFormScreen extends ConsumerStatefulWidget {
  final String templateId;

  const ResumeBuilderFormScreen({super.key, required this.templateId});

  @override
  ConsumerState<ResumeBuilderFormScreen> createState() => _ResumeBuilderFormScreenState();
}

class _ResumeBuilderFormScreenState extends ConsumerState<ResumeBuilderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _jobTitleController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _summaryController;
  late TextEditingController _linkedinController;
  late TextEditingController _githubController;
  late TextEditingController _leetcodeController;
  late TextEditingController _portfolioController;
  
  final TextEditingController _skillController = TextEditingController();
  final TextEditingController _langController = TextEditingController();
  final TextEditingController _achievementController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final data = ref.read(resumeDataProvider);
    _nameController = TextEditingController(text: data.fullName);
    _jobTitleController = TextEditingController(text: data.jobTitle);
    _emailController = TextEditingController(text: data.email);
    _phoneController = TextEditingController(text: data.phone);
    _addressController = TextEditingController(text: data.address);
    _summaryController = TextEditingController(text: data.summary);
    _linkedinController = TextEditingController(text: data.linkedin);
    _githubController = TextEditingController(text: data.github);
    _leetcodeController = TextEditingController(text: data.leetcode);
    _portfolioController = TextEditingController(text: data.portfolio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jobTitleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _summaryController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    _leetcodeController.dispose();
    _portfolioController.dispose();
    _skillController.dispose();
    _langController.dispose();
    _achievementController.dispose();
    super.dispose();
  }

  void _updateData() {
    final currentData = ref.read(resumeDataProvider);
    
    // Create a new instance to ensure Riverpod state changes are detected
    final newData = ResumeData(
      fullName: _nameController.text,
      jobTitle: _jobTitleController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      address: _addressController.text,
      summary: _summaryController.text,
      experience: List.from(currentData.experience),
      education: List.from(currentData.education),
      skills: List.from(currentData.skills),
      languages: List.from(currentData.languages),
      projects: List.from(currentData.projects),
      achievements: List.from(currentData.achievements),
      profileImagePath: currentData.profileImagePath,
      linkedin: _linkedinController.text,
      github: _githubController.text,
      leetcode: _leetcodeController.text,
      portfolio: _portfolioController.text,
    );
    
    ref.read(resumeDataProvider.notifier).state = newData;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      ref.read(resumeDataProvider).profileImagePath = image.path;
      _updateData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = resumeTemplates.firstWhere((t) => t.id == widget.templateId);
    final data = ref.watch(resumeDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Build ${template.name} Resume'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              _updateData();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ResumePdfPreviewScreen(
                    resumeData: ref.read(resumeDataProvider),
                    template: template,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Profile Photo'),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: data.profileImagePath != null 
                          ? FileImage(File(data.profileImagePath!)) 
                          : null,
                      child: data.profileImagePath == null 
                          ? const Icon(Icons.person, size: 50, color: Colors.white) 
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        radius: 18,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Personal Information'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                onChanged: (_) => _updateData(),
              ),
              TextFormField(
                controller: _jobTitleController,
                decoration: const InputDecoration(labelText: 'Job Title (e.g. Software Engineer)'),
                onChanged: (_) => _updateData(),
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => _updateData(),
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                onChanged: (_) => _updateData(),
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                onChanged: (_) => _updateData(),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Social & Professional Links'),
              TextFormField(
                controller: _linkedinController,
                decoration: const InputDecoration(labelText: 'LinkedIn URL', prefixIcon: Icon(Icons.link)),
                onChanged: (_) => _updateData(),
              ),
              TextFormField(
                controller: _githubController,
                decoration: const InputDecoration(labelText: 'GitHub URL', prefixIcon: Icon(Icons.code)),
                onChanged: (_) => _updateData(),
              ),
              TextFormField(
                controller: _leetcodeController,
                decoration: const InputDecoration(labelText: 'LeetCode URL', prefixIcon: Icon(Icons.terminal)),
                onChanged: (_) => _updateData(),
              ),
              TextFormField(
                controller: _portfolioController,
                decoration: const InputDecoration(labelText: 'Portfolio URL', prefixIcon: Icon(Icons.language)),
                onChanged: (_) => _updateData(),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Professional Summary'),
              TextFormField(
                controller: _summaryController,
                decoration: const InputDecoration(
                  hintText: 'Briefly describe your professional background...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                onChanged: (_) => _updateData(),
              ),
              const SizedBox(height: 20),
              _buildDynamicListSection(
                title: 'Experience',
                items: data.experience,
                onAdd: () {
                  data.experience.add(Experience());
                  _updateData();
                },
                itemBuilder: (exp, index) => _buildExperienceItem(exp, index),
              ),
              const SizedBox(height: 20),
              _buildDynamicListSection(
                title: 'Education',
                items: data.education,
                onAdd: () {
                  data.education.add(Education());
                  _updateData();
                },
                itemBuilder: (edu, index) => _buildEducationItem(edu, index),
              ),
              const SizedBox(height: 20),
              _buildDynamicListSection(
                title: 'Projects',
                items: data.projects,
                onAdd: () {
                  data.projects.add(Project());
                  _updateData();
                },
                itemBuilder: (proj, index) => _buildProjectItem(proj, index),
              ),
              const SizedBox(height: 20),
              _buildSkillsSection(),
              const SizedBox(height: 20),
              _buildAchievementsSection(),
              const SizedBox(height: 20),
              _buildLanguagesSection(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _updateData();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ResumePdfPreviewScreen(
                resumeData: ref.read(resumeDataProvider),
                template: template,
              ),
            ),
          );
        },
        label: const Text('Preview PDF'),
        icon: const Icon(Icons.remove_red_eye),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }

  Widget _buildDynamicListSection({
    required String title,
    required List items,
    required VoidCallback onAdd,
    required Widget Function(dynamic, int) itemBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(title),
            IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle, color: Colors.green)),
          ],
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) => itemBuilder(items[index], index),
        ),
      ],
    );
  }

  Widget _buildExperienceItem(Experience exp, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: exp.jobTitle,
                    decoration: const InputDecoration(labelText: 'Job Title'),
                    onChanged: (val) {
                      exp.jobTitle = val;
                      _updateData();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    ref.read(resumeDataProvider).experience.removeAt(index);
                    _updateData();
                  },
                ),
              ],
            ),
            TextFormField(
              initialValue: exp.company,
              decoration: const InputDecoration(labelText: 'Company'),
              onChanged: (val) {
                exp.company = val;
                _updateData();
              },
            ),
            TextFormField(
              initialValue: exp.location,
              decoration: const InputDecoration(labelText: 'Location (City, Country)'),
              onChanged: (val) {
                exp.location = val;
                _updateData();
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: exp.startDate,
                    decoration: const InputDecoration(labelText: 'Start Date'),
                    onChanged: (val) {
                      exp.startDate = val;
                      _updateData();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: exp.endDate,
                    decoration: const InputDecoration(labelText: 'End Date'),
                    onChanged: (val) {
                      exp.endDate = val;
                      _updateData();
                    },
                  ),
                ),
              ],
            ),
            TextFormField(
              initialValue: exp.description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
              onChanged: (val) {
                exp.description = val;
                _updateData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationItem(Education edu, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: edu.degree,
                    decoration: const InputDecoration(labelText: 'Degree'),
                    onChanged: (val) {
                      edu.degree = val;
                      _updateData();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    ref.read(resumeDataProvider).education.removeAt(index);
                    _updateData();
                  },
                ),
              ],
            ),
            TextFormField(
              initialValue: edu.institution,
              decoration: const InputDecoration(labelText: 'Institution'),
              onChanged: (val) {
                edu.institution = val;
                _updateData();
              },
            ),
            TextFormField(
              initialValue: edu.location,
              decoration: const InputDecoration(labelText: 'Location'),
              onChanged: (val) {
                edu.location = val;
                _updateData();
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: edu.year,
                    decoration: const InputDecoration(labelText: 'Year'),
                    onChanged: (val) {
                      edu.year = val;
                      _updateData();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: edu.score,
                    decoration: const InputDecoration(labelText: 'Score/GPA'),
                    onChanged: (val) {
                      edu.score = val;
                      _updateData();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectItem(Project proj, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: proj.title,
                    decoration: const InputDecoration(labelText: 'Project Title'),
                    onChanged: (val) {
                      proj.title = val;
                      _updateData();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    ref.read(resumeDataProvider).projects.removeAt(index);
                    _updateData();
                  },
                ),
              ],
            ),
            TextFormField(
              initialValue: proj.link,
              decoration: const InputDecoration(labelText: 'Project Link (optional)'),
              onChanged: (val) {
                proj.link = val;
                _updateData();
              },
            ),
            TextFormField(
              initialValue: proj.description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
              onChanged: (val) {
                proj.description = val;
                _updateData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsSection() {
    final data = ref.watch(resumeDataProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Skills'),
        Wrap(
          spacing: 8,
          children: data.skills.asMap().entries.map((entry) {
            return Chip(
              label: Text(entry.value),
              onDeleted: () {
                ref.read(resumeDataProvider).skills.removeAt(entry.key);
                _updateData();
              },
            );
          }).toList(),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _skillController,
                decoration: const InputDecoration(
                  labelText: 'Add Skill',
                ),
                onFieldSubmitted: (val) {
                  if (val.isNotEmpty) {
                    ref.read(resumeDataProvider).skills.add(val);
                    _skillController.clear();
                    _updateData();
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: () {
                if (_skillController.text.isNotEmpty) {
                  ref.read(resumeDataProvider).skills.add(_skillController.text);
                  _skillController.clear();
                  _updateData();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAchievementsSection() {
    final data = ref.watch(resumeDataProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Achievements'),
        Wrap(
          spacing: 8,
          children: data.achievements.asMap().entries.map((entry) {
            return Chip(
              label: Text(entry.value),
              onDeleted: () {
                ref.read(resumeDataProvider).achievements.removeAt(entry.key);
                _updateData();
              },
            );
          }).toList(),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _achievementController,
                decoration: const InputDecoration(
                  labelText: 'Add Achievement',
                ),
                onFieldSubmitted: (val) {
                  if (val.isNotEmpty) {
                    ref.read(resumeDataProvider).achievements.add(val);
                    _achievementController.clear();
                    _updateData();
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: () {
                if (_achievementController.text.isNotEmpty) {
                  ref.read(resumeDataProvider).achievements.add(_achievementController.text);
                  _achievementController.clear();
                  _updateData();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguagesSection() {
    final data = ref.watch(resumeDataProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Languages'),
        Wrap(
          spacing: 8,
          children: data.languages.asMap().entries.map((entry) {
            return Chip(
              label: Text(entry.value),
              onDeleted: () {
                ref.read(resumeDataProvider).languages.removeAt(entry.key);
                _updateData();
              },
            );
          }).toList(),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _langController,
                decoration: const InputDecoration(
                  labelText: 'Add Language',
                ),
                onFieldSubmitted: (val) {
                  if (val.isNotEmpty) {
                    ref.read(resumeDataProvider).languages.add(val);
                    _langController.clear();
                    _updateData();
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: () {
                if (_langController.text.isNotEmpty) {
                  ref.read(resumeDataProvider).languages.add(_langController.text);
                  _langController.clear();
                  _updateData();
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
