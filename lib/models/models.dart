import 'package:flutter/material.dart';

// ===== ORGANIZATION =====
class Organization {
  final int? id;
  final String name;
  final String? description;
  final String color;
  final bool isActive;
  final int? memberCount;
  final int? groupCount;

  Organization({this.id, required this.name, this.description,
    this.color = '#1565C0', this.isActive = true,
    this.memberCount, this.groupCount});

  Color get colorValue {
    try { return Color(int.parse(color.replaceFirst('#', '0xFF'))); }
    catch (_) { return const Color(0xFF1565C0); }
  }

  factory Organization.fromMap(Map<String, dynamic> map) => Organization(
    id: map['id'], name: map['name'] ?? '',
    description: map['description'], color: map['color'] ?? '#1565C0',
    isActive: (map['is_active'] ?? 1) == 1,
    memberCount: map['member_count'], groupCount: map['group_count'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'name': name,
    'description': description, 'color': color, 'is_active': isActive ? 1 : 0,
  };
}

// ===== APP USER =====
class AppUser {
  final int? id;
  final String username;
  String password;
  final String role;
  bool isBlocked;
  String orgPermissions;
  final String? lastLogin;

  AppUser({this.id, required this.username, required this.password,
    this.role = 'user', this.isBlocked = false,
    this.orgPermissions = '', this.lastLogin});

  bool get isSuperAdmin => role == 'superadmin';
  bool get isAdmin => role == 'admin' || role == 'superadmin';

  String get roleLabel {
    switch (role) {
      case 'superadmin': return 'Super Admin';
      case 'admin': return 'Administrateur';
      default: return 'Utilisateur';
    }
  }

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'], username: map['username'] ?? '',
    password: map['password'] ?? '',
    role: map['role'] ?? 'user',
    isBlocked: (map['is_blocked'] ?? 0) == 1,
    orgPermissions: map['org_permissions'] ?? '',
    lastLogin: map['last_login'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'username': username,
    'password': password, 'role': role,
    'is_blocked': isBlocked ? 1 : 0,
    'org_permissions': orgPermissions,
  };
}

// ===== GROUP =====
class Group {
  final int? id;
  final int orgId;
  final String name;
  final String? description;
  final String color;
  final int? memberCount;

  Group({this.id, required this.orgId, required this.name,
    this.description, this.color = '#1565C0', this.memberCount});

  Color get colorValue {
    try { return Color(int.parse(color.replaceFirst('#', '0xFF'))); }
    catch (_) { return const Color(0xFF1565C0); }
  }

  factory Group.fromMap(Map<String, dynamic> map) => Group(
    id: map['id'], orgId: map['org_id'] ?? 0,
    name: map['name'] ?? '', description: map['description'],
    color: map['color'] ?? '#1565C0', memberCount: map['member_count'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'org_id': orgId,
    'name': name, 'description': description, 'color': color,
  };
}

// ===== MEMBER =====
class Member {
  final int? id;
  final int orgId;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;
  final String? function;
  int? groupId;
  final bool isActive;
  final String? groupName;
  final String? groupColor;

  Member({this.id, required this.orgId, required this.firstName,
    required this.lastName, this.phone, this.email, this.function,
    this.groupId, this.isActive = true, this.groupName, this.groupColor});

  String get fullName => '$lastName $firstName';
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

  factory Member.fromMap(Map<String, dynamic> map) => Member(
    id: map['id'], orgId: map['org_id'] ?? 0,
    firstName: map['first_name'] ?? '', lastName: map['last_name'] ?? '',
    phone: map['phone'], email: map['email'], function: map['function'],
    groupId: map['group_id'], isActive: (map['status'] ?? 1) == 1,
    groupName: map['group_name'], groupColor: map['group_color'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'org_id': orgId,
    'first_name': firstName, 'last_name': lastName,
    'phone': phone, 'email': email, 'function': function,
    'group_id': groupId, 'status': isActive ? 1 : 0,
  };
}

// ===== ATTENDANCE STATUS =====
enum AttendanceStatus { present, absent, late, permission, special, particular }

extension AttendanceStatusExt on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present: return 'Présent';
      case AttendanceStatus.absent: return 'Absent';
      case AttendanceStatus.late: return 'Retard';
      case AttendanceStatus.permission: return 'Permission';
      case AttendanceStatus.special: return 'Autorisation';
      case AttendanceStatus.particular: return 'Cas particulier';
    }
  }

  String get shortLabel {
    switch (this) {
      case AttendanceStatus.present: return 'P';
      case AttendanceStatus.absent: return 'A';
      case AttendanceStatus.late: return 'R';
      case AttendanceStatus.permission: return 'Perm';
      case AttendanceStatus.special: return 'Auth';
      case AttendanceStatus.particular: return 'CP';
    }
  }

  String get value {
    switch (this) {
      case AttendanceStatus.present: return 'present';
      case AttendanceStatus.absent: return 'absent';
      case AttendanceStatus.late: return 'late';
      case AttendanceStatus.permission: return 'permission';
      case AttendanceStatus.special: return 'special';
      case AttendanceStatus.particular: return 'particular';
    }
  }

  IconData get icon {
    switch (this) {
      case AttendanceStatus.present: return Icons.check_circle;
      case AttendanceStatus.absent: return Icons.cancel;
      case AttendanceStatus.late: return Icons.access_time;
      case AttendanceStatus.permission: return Icons.assignment;
      case AttendanceStatus.special: return Icons.star;
      case AttendanceStatus.particular: return Icons.info;
    }
  }

  Color get color {
    switch (this) {
      case AttendanceStatus.present: return const Color(0xFF4CAF50);
      case AttendanceStatus.absent: return const Color(0xFFF44336);
      case AttendanceStatus.late: return const Color(0xFFFF9800);
      case AttendanceStatus.permission: return const Color(0xFF9E9E9E);
      case AttendanceStatus.special: return const Color(0xFF9C27B0);
      case AttendanceStatus.particular: return const Color(0xFF2196F3);
    }
  }

  static AttendanceStatus fromString(String v) {
    switch (v) {
      case 'present': return AttendanceStatus.present;
      case 'late': return AttendanceStatus.late;
      case 'permission': return AttendanceStatus.permission;
      case 'special': return AttendanceStatus.special;
      case 'particular': return AttendanceStatus.particular;
      default: return AttendanceStatus.absent;
    }
  }
}

// ===== ATTENDANCE =====
class Attendance {
  final int? id;
  final int sessionId;
  final int memberId;
  AttendanceStatus status;
  int lateMinutes;
  String? comment;
  String? firstName;
  String? lastName;
  String? function;
  bool presetApplied; // true si ce statut vient d'un preset

  Attendance({this.id, required this.sessionId, required this.memberId,
    this.status = AttendanceStatus.present, this.lateMinutes = 0,
    this.comment, this.firstName, this.lastName, this.function,
    this.presetApplied = false});

  String get memberName => '${lastName ?? ''} ${firstName ?? ''}'.trim();
  bool get isCountedAbsent => status == AttendanceStatus.absent || status == AttendanceStatus.permission;

  factory Attendance.fromMap(Map<String, dynamic> map) => Attendance(
    id: map['id'], sessionId: map['session_id'], memberId: map['member_id'],
    status: AttendanceStatusExt.fromString(map['status'] ?? 'absent'),
    lateMinutes: map['late_minutes'] ?? 0, comment: map['comment'],
    firstName: map['first_name'], lastName: map['last_name'],
    function: map['function'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'session_id': sessionId, 'member_id': memberId,
    'status': status.value, 'late_minutes': lateMinutes, 'comment': comment,
  };
}

// ===== SESSION =====
class Session {
  final int? id;
  final int orgId;
  final String date;
  final int? groupId;
  final String sessionType;
  final String? label;
  final String? groupName;
  final int presentCount;
  final int totalCount;

  Session({this.id, required this.orgId, required this.date, this.groupId,
    this.sessionType = 'Réunion', this.label, this.groupName,
    this.presentCount = 0, this.totalCount = 0});

  double get presenceRate => totalCount > 0 ? presentCount / totalCount * 100 : 0;
  String get displayTitle => label != null && label!.isNotEmpty ? label! : sessionType;

  factory Session.fromMap(Map<String, dynamic> map) => Session(
    id: map['id'], orgId: map['org_id'] ?? 0, date: map['date'] ?? '',
    groupId: map['group_id'], sessionType: map['session_type'] ?? 'Réunion',
    label: map['label'], groupName: map['group_name'],
    presentCount: map['present_count'] ?? 0, totalCount: map['total_count'] ?? 0,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'org_id': orgId, 'date': date,
    'group_id': groupId, 'session_type': sessionType, 'label': label,
  };
}

// ===== PENALTY CONFIG =====
class PenaltyConfig {
  double absenceAmount;
  double lateAmount;
  double unjustifiedAmount;
  int lateThreshold;
  String currency;
  bool enabled;

  PenaltyConfig({this.absenceAmount = 200, this.lateAmount = 100,
    this.unjustifiedAmount = 300, this.lateThreshold = 30,
    this.currency = 'F', this.enabled = true});

  factory PenaltyConfig.fromMap(Map<String, dynamic> map) => PenaltyConfig(
    absenceAmount: (map['absence_amount'] ?? 200).toDouble(),
    lateAmount: (map['late_amount'] ?? 100).toDouble(),
    unjustifiedAmount: (map['unjustified_amount'] ?? 300).toDouble(),
    lateThreshold: map['late_threshold'] ?? 30,
    currency: map['currency'] ?? 'F',
    enabled: (map['enabled'] ?? 1) == 1,
  );

  Map<String, dynamic> toMap() => {
    'absence_amount': absenceAmount, 'late_amount': lateAmount,
    'unjustified_amount': unjustifiedAmount, 'late_threshold': lateThreshold,
    'currency': currency, 'enabled': enabled ? 1 : 0,
  };

  double calculate(int absents, int lates) =>
      (absents * absenceAmount) + (lates * lateAmount);
}

// ===== ATTENDANCE PRESET =====
// Permet de pré-définir le statut d'un membre pour une date ou période
// Exemple : Marie en permission du 01/03 au 05/03 → auto-rempli à chaque appel
class AttendancePreset {
  final int? id;
  final int orgId;
  final int memberId;
  final String dateStart;
  final String? dateEnd;     // null = jour unique
  final AttendanceStatus status;
  final String? comment;
  // Infos jointes (lecture seulement)
  final String? firstName;
  final String? lastName;
  final String? function;
  final String? groupName;

  AttendancePreset({this.id, required this.orgId, required this.memberId,
    required this.dateStart, this.dateEnd, required this.status,
    this.comment, this.firstName, this.lastName,
    this.function, this.groupName});

  String get memberName => '${lastName ?? ''} ${firstName ?? ''}'.trim();

  bool get isPeriod => dateEnd != null;

  String get dateLabel {
    if (dateEnd == null) return _fmt(dateStart);
    return '${_fmt(dateStart)} → ${_fmt(dateEnd!)}';
  }

  String _fmt(String d) {
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return d; }
  }

  /// Vérifie si ce preset s'applique à une date donnée (format yyyy-MM-dd)
  bool appliesTo(String date) {
    if (dateEnd == null) return dateStart == date;
    return dateStart.compareTo(date) <= 0 && dateEnd!.compareTo(date) >= 0;
  }

  factory AttendancePreset.fromMap(Map<String, dynamic> map) => AttendancePreset(
    id: map['id'], orgId: map['org_id'] ?? 0, memberId: map['member_id'] ?? 0,
    dateStart: map['date_start'] ?? '',
    dateEnd: map['date_end'],
    status: AttendanceStatusExt.fromString(map['status'] ?? 'permission'),
    comment: map['comment'],
    firstName: map['first_name'], lastName: map['last_name'],
    function: map['function'], groupName: map['group_name'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'org_id': orgId, 'member_id': memberId,
    'date_start': dateStart, 'date_end': dateEnd,
    'status': status.value, 'comment': comment,
  };
}
