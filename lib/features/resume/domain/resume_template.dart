class ResumeTemplate {
  final String id;
  final String name;
  final String type;
  final String previewImage;
  final String tag;
  final bool isRecommended;

  const ResumeTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.previewImage,
    required this.tag,
    this.isRecommended = false,
  });
}

final List<ResumeTemplate> resumeTemplates = [
  const ResumeTemplate(
    id: 'modern',
    name: 'Modern',
    type: 'modern',
    previewImage: 'assets/templates/modern.png',
    tag: 'Recommended',
    isRecommended: true,
  ),
  const ResumeTemplate(
    id: 'classic',
    name: 'Classic',
    type: 'classic',
    previewImage: 'assets/templates/classic.png',
    tag: 'Professional',
  ),
  const ResumeTemplate(
    id: 'minimal',
    name: 'Minimal',
    type: 'minimal',
    previewImage: 'assets/templates/minimal.png',
    tag: 'Clean',
  ),
  const ResumeTemplate(
    id: 'fresher',
    name: 'Fresher',
    type: 'fresher',
    previewImage: 'assets/templates/fresher.png',
    tag: 'For Students',
  ),
];
