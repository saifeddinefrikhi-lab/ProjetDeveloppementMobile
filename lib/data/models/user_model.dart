class UserModel {
  final int? id;
  final String name;
  final String email;
  final String passwordHash;
  final String? avatarInitials;
  final String createdAt;

  const UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    this.avatarInitials,
    required this.createdAt,
  });

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? passwordHash,
    String? avatarInitials,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'email': email,
        'password_hash': passwordHash,
        'avatar_initials': avatarInitials ?? computeInitials(name),
        'created_at': createdAt,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        email: map['email'] as String,
        passwordHash: map['password_hash'] as String,
        avatarInitials: map['avatar_initials'] as String?,
        createdAt: map['created_at'] as String,
      );

  String get initials => avatarInitials ?? computeInitials(name);

  static String computeInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}
