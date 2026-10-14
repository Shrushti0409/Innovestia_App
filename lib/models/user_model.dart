enum UserRole { startup, investor, admin }

extension UserRoleX on UserRole {
  String get apiValue => name.toUpperCase();
  String get label => switch (this) {
    UserRole.startup => 'Startup',
    UserRole.investor => 'Investor',
    UserRole.admin => 'Admin',
  };
  static UserRole fromJson(String? value) => UserRole.values.firstWhere(
    (role) => role.apiValue == value,
    orElse: () => UserRole.startup,
  );
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.isVerified = false,
  });
  final String id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final bool isVerified;
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String?,
    role: UserRoleX.fromJson(json['role'] as String?),
    isVerified: json['isVerified'] as bool? ?? false,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role.apiValue,
    'isVerified': isVerified,
  };
}
