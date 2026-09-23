// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resume_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ResumeDataAdapter extends TypeAdapter<ResumeData> {
  @override
  final int typeId = 10;

  @override
  ResumeData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ResumeData(
      fullName: fields[0] as String,
      jobTitle: fields[1] as String,
      email: fields[2] as String,
      phone: fields[3] as String,
      address: fields[4] as String,
      summary: fields[5] as String,
      experience: (fields[6] as List?)?.cast<Experience>(),
      education: (fields[7] as List?)?.cast<Education>(),
      skills: (fields[8] as List?)?.cast<String>(),
      projects: (fields[9] as List?)?.cast<Project>(),
      profileImagePath: fields[10] as String?,
      languages: (fields[11] as List?)?.cast<String>(),
      github: fields[12] as String?,
      linkedin: fields[13] as String?,
      leetcode: fields[14] as String?,
      portfolio: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ResumeData obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.fullName)
      ..writeByte(1)
      ..write(obj.jobTitle)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.address)
      ..writeByte(5)
      ..write(obj.summary)
      ..writeByte(6)
      ..write(obj.experience)
      ..writeByte(7)
      ..write(obj.education)
      ..writeByte(8)
      ..write(obj.skills)
      ..writeByte(9)
      ..write(obj.projects)
      ..writeByte(10)
      ..write(obj.profileImagePath)
      ..writeByte(11)
      ..write(obj.languages)
      ..writeByte(12)
      ..write(obj.github)
      ..writeByte(13)
      ..write(obj.linkedin)
      ..writeByte(14)
      ..write(obj.leetcode)
      ..writeByte(15)
      ..write(obj.portfolio);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResumeDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExperienceAdapter extends TypeAdapter<Experience> {
  @override
  final int typeId = 11;

  @override
  Experience read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Experience(
      jobTitle: fields[0] as String,
      company: fields[1] as String,
      location: fields[2] as String,
      startDate: fields[3] as String,
      endDate: fields[4] as String,
      description: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Experience obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.jobTitle)
      ..writeByte(1)
      ..write(obj.company)
      ..writeByte(2)
      ..write(obj.location)
      ..writeByte(3)
      ..write(obj.startDate)
      ..writeByte(4)
      ..write(obj.endDate)
      ..writeByte(5)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExperienceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EducationAdapter extends TypeAdapter<Education> {
  @override
  final int typeId = 12;

  @override
  Education read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Education(
      degree: fields[0] as String,
      institution: fields[1] as String,
      year: fields[2] as String,
      score: fields[3] as String,
      location: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Education obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.degree)
      ..writeByte(1)
      ..write(obj.institution)
      ..writeByte(2)
      ..write(obj.year)
      ..writeByte(3)
      ..write(obj.score)
      ..writeByte(4)
      ..write(obj.location);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EducationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProjectAdapter extends TypeAdapter<Project> {
  @override
  final int typeId = 13;

  @override
  Project read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Project(
      title: fields[0] as String,
      description: fields[1] as String,
      link: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Project obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.link);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
