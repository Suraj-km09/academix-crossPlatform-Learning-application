class CollegeModel {
  const CollegeModel({
    required this.collegeId,
    required this.name,
    required this.state,
    required this.city,
    required this.emailDomain,
  });

  final String collegeId;
  final String name;
  final String state;
  final String city;
  final String emailDomain;

  factory CollegeModel.fromMap(Map<String, dynamic> map, String collegeId) {
    return CollegeModel(
      collegeId:
          (map['collegeId'] as String? ?? map['id'] as String? ?? collegeId)
              .trim(),
      name:
          (map['name'] as String? ??
                  map['collegeName'] as String? ??
                  map['college'] as String? ??
                  collegeId)
              .trim(),
      state: (map['state'] as String? ?? map['province'] as String? ?? '')
          .trim(),
      city: (map['city'] as String? ?? map['district'] as String? ?? '').trim(),
      emailDomain:
          (map['emailDomain'] as String? ?? map['domain'] as String? ?? '')
              .trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'collegeId': collegeId,
      'name': name,
      'state': state,
      'city': city,
      'emailDomain': emailDomain,
    };
  }
}
