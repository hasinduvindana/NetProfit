class UserModel {
  final String firstName;
  final String lastName;
  final String email;
  final String userName;
  final String userType;

  UserModel({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.userName,
    this.userType = 'user',
  });

  Map<String, dynamic> toMap() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'user-name': userName,
      'user-type': userType,
    };
  }
}