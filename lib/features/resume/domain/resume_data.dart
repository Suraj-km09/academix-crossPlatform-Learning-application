import 'package:hive/hive.dart';

part 'resume_data.g.dart';

@HiveType(typeId: 10)
class ResumeData extends HiveObject {
  @HiveField(0)
  String fullName;
  @HiveField(1)
  String jobTitle;
  @HiveField(2)
  String email;
  @HiveField(3)
  String phone;
  @HiveField(4)
  String address;
  @HiveField(5)
  String summary;
  @HiveField(6)
  List<Experience> experience;
  @HiveField(7)
  List<Education> education;
  @HiveField(8)
  List<String> skills;
  @HiveField(9)
  List<Project> projects;
  @HiveField(10)
  String? profileImagePath;
  @HiveField(11)
  List<String> languages;
  @HiveField(12)
  String? github;
  @HiveField(13)
  String? linkedin;
  @HiveField(14)
  String? leetcode;
  @HiveField(15)
  String? portfolio;
  @HiveField(16)
  List<String> achievements;

  ResumeData({
    this.fullName = '',
    this.jobTitle = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.summary = '',
    List<Experience>? experience,
    List<Education>? education,
    List<String>? skills,
    List<Project>? projects,
    this.profileImagePath,
    List<String>? languages,
    this.github,
    this.linkedin,
    this.leetcode,
    this.portfolio,
    List<String>? achievements,
  })  : experience = experience ?? [],
        education = education ?? [],
        skills = skills ?? [],
        projects = projects ?? [],
        languages = languages ?? [],
        achievements = achievements ?? [];
}

@HiveType(typeId: 11)
class Experience {
  @HiveField(0)
  String jobTitle;
  @HiveField(1)
  String company;
  @HiveField(2)
  String location;
  @HiveField(3)
  String startDate;
  @HiveField(4)
  String endDate;
  @HiveField(5)
  String description;

  Experience({
    this.jobTitle = '',
    this.company = '',
    this.location = '',
    this.startDate = '',
    this.endDate = '',
    this.description = '',
  });
}

@HiveType(typeId: 12)
class Education {
  @HiveField(0)
  String degree;
  @HiveField(1)
  String institution;
  @HiveField(2)
  String year;
  @HiveField(3)
  String score;
  @HiveField(4)
  String location;

  Education({
    this.degree = '',
    this.institution = '',
    this.year = '',
    this.score = '',
    this.location = '',
  });
}

@HiveType(typeId: 13)
class Project {
  @HiveField(0)
  String title;
  @HiveField(1)
  String description;
  @HiveField(2)
  String link;

  Project({
    this.title = '',
    this.description = '',
    this.link = '',
  });
}
