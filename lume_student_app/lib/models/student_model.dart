class Student {
  final String fullName;
  final String institute;
  final String regNo;
  final String dept;
  final String dob;
  final String blood;
  final String email;

  Student({
    required this.fullName,
    required this.institute,
    required this.regNo,
    required this.dept,
    required this.dob,
    required this.blood,
    required this.email,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      fullName: json['full_name'],
      institute: json['institute_name'],
      regNo: json['reg_no'],
      dept: json['department'],
      dob: json['dob'],
      blood: json['blood_group'],
      email: json['email'],
    );
  }
}