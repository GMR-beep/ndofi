import 'package:flutter/foundation.dart';
import '../core/database/database_helper.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // Auth
  AppUser? _currentUser;
  Organization? _currentOrg;
  bool _isDarkMode = false;
  String _attendanceMode = 'classic';

  // Data
  List<Organization> _organizations = [];
  List<Group> _groups = [];
  List<Member> _members = [];
  List<Session> _sessions = [];
  List<AppUser> _users = [];
  List<Attendance> _currentAttendances = [];
  Map<String, dynamic> _dashboardStats = {};
  List<Map<String, dynamic>> _penalties = [];
  PenaltyConfig _penaltyConfig = PenaltyConfig();
  List<Map<String, dynamic>> _activityLog = [];
  List<AttendancePreset> _presets = [];

  bool _isLoading = false;

  // Getters
  AppUser? get currentUser => _currentUser;
  Organization? get currentOrg => _currentOrg;
  bool get isDarkMode => _isDarkMode;
  String get attendanceMode => _attendanceMode;
  List<Organization> get organizations => _organizations;
  List<Group> get groups => _groups;
  List<Member> get members => _members;
  List<Session> get sessions => _sessions;
  List<AppUser> get users => _users;
  List<Attendance> get currentAttendances => _currentAttendances;
  Map<String, dynamic> get dashboardStats => _dashboardStats;
  List<Map<String, dynamic>> get penalties => _penalties;
  PenaltyConfig get penaltyConfig => _penaltyConfig;
  List<Map<String, dynamic>> get activityLog => _activityLog;
  List<AttendancePreset> get presets => _presets;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isSuperAdmin => _currentUser?.isSuperAdmin ?? false;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  // Stats helpers
  int get memberCount => _dashboardStats['member_count'] ?? 0;
  int get sessionCount => _dashboardStats['session_count'] ?? 0;
  int get presentCount => _dashboardStats['present_count'] ?? 0;
  int get absentCount => _dashboardStats['absent_count'] ?? 0;
  int get lateCount => _dashboardStats['late_count'] ?? 0;
  String get presenceRate => '${_dashboardStats['presence_rate'] ?? '0.0'}%';

  int get sessionPresentCount => _currentAttendances.where((a) => a.status == AttendanceStatus.present).length;
  int get sessionAbsentCount  => _currentAttendances.where((a) => a.isCountedAbsent).length;
  int get sessionLateCount    => _currentAttendances.where((a) => a.status == AttendanceStatus.late).length;

  double get totalPenalties => _penalties.fold(0, (s, p) => s + (p['total_penalty'] as double? ?? 0));

  // ===== INIT =====
  Future<void> init() async {
    _isDarkMode = (await _db.getSetting('dark_mode')) == 'true';
    _attendanceMode = (await _db.getSetting('attendance_mode')) ?? 'classic';
    notifyListeners();
  }

  // ===== AUTH =====
  Future<bool> login(String username, String password) async {
    // ÉTAPE 1 : Auth uniquement — isolée
    try {
      final ok = await _db.authenticateUser(username, password);
      if (!ok) return false;
    } catch (e) {
      debugPrint('Auth error: $e');
      return false;
    }

    // ÉTAPE 2 : Charger l'utilisateur — non bloquant pour le login
    try {
      final userMap = await _db.getUserByUsername(username);
      _currentUser = userMap != null
          ? AppUser.fromMap(userMap)
          : AppUser(username: username, password: password, role: 'user');
    } catch (e) {
      debugPrint('Load user error: $e');
      _currentUser = AppUser(
          username: username, password: password, role: 'user');
    }

    // ÉTAPE 3 : Charger les organisations — non bloquant pour le login
    try {
      final orgMaps = await _db.getOrganizations();
      _organizations = orgMaps.map((m) => Organization.fromMap(m)).toList();
      if (_organizations.isNotEmpty) _currentOrg = _organizations.first;
    } catch (e) {
      debugPrint('Load orgs error: $e');
      _organizations = [];
    }

    notifyListeners();

    // ÉTAPE 4 : Chargement données en arrière-plan
    if (_currentOrg != null) {
      loadOrgData().catchError((e) => debugPrint('loadOrgData: $e'));
    }

    return true; // Auth réussie quoi qu'il arrive après
  }

  void logout() {
    _currentUser = null;
    _currentOrg = null;
    _groups = [];
    _members = [];
    _sessions = [];
    _presets = [];
    _dashboardStats = {};
    notifyListeners();
  }

  // ===== ORGANISATIONS =====
  Future<void> loadOrganizations() async {
    final maps = await _db.getOrganizations();
    _organizations = maps.map((m) => Organization.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> switchOrganization(Organization org) async {
    _currentOrg = org;
    await _db.setSetting('current_org_id', org.id.toString());
    await loadOrgData();
    notifyListeners();
  }

  Future<bool> addOrganization(Organization org) async {
    try {
      await _db.insertOrganization(org.toMap());
      await loadOrganizations();
      return true;
    } catch (e) { return false; }
  }

  Future<bool> updateOrganization(Organization org) async {
    try {
      await _db.updateOrganization(org.id!, org.toMap());
      await loadOrganizations();
      if (_currentOrg?.id == org.id) _currentOrg = org;
      notifyListeners();
      return true;
    } catch (e) { return false; }
  }

  Future<bool> deleteOrganization(int id) async {
    try {
      await _db.deleteOrganization(id);
      await loadOrganizations();
      if (_currentOrg?.id == id) {
        _currentOrg = _organizations.isNotEmpty ? _organizations.first : null;
        if (_currentOrg != null) await loadOrgData();
      }
      return true;
    } catch (e) { return false; }
  }

  // ===== ORG DATA =====
  Future<void> loadOrgData() async {
    if (_currentOrg == null) return;
    await Future.wait([
      loadGroups(), loadMembers(), loadSessions(),
      loadDashboardStats(), loadPenaltyConfig(), loadPresets(),
    ]);
  }

  // ===== GROUPES =====
  Future<void> loadGroups() async {
    if (_currentOrg == null) return;
    final maps = await _db.getGroups(_currentOrg!.id!);
    _groups = maps.map((m) => Group.fromMap(m)).toList();
    notifyListeners();
  }

  Future<bool> addGroup(Group g) async {
    try {
      await _db.insertGroup(g.toMap());
      await _db.logActivity(_currentUser?.id, _currentOrg?.id, 'ADD_GROUP', 'Groupe ajouté: ${g.name}');
      await loadGroups();
      return true;
    } catch (e) { return false; }
  }

  Future<bool> updateGroup(Group g) async {
    try {
      await _db.updateGroup(g.id!, g.toMap());
      await loadGroups();
      return true;
    } catch (e) { return false; }
  }

  Future<bool> deleteGroup(int id) async {
    try {
      await _db.deleteGroup(id);
      await loadGroups();
      await loadMembers();
      return true;
    } catch (e) { return false; }
  }

  // ===== MEMBRES =====
  String _memberSearch = '';
  int? _memberGroupFilter;

  List<Member> get filteredMembers {
    return _members.where((m) {
      final matchSearch = _memberSearch.isEmpty ||
          m.fullName.toLowerCase().contains(_memberSearch.toLowerCase()) ||
          (m.function?.toLowerCase().contains(_memberSearch.toLowerCase()) ?? false);
      final matchGroup = _memberGroupFilter == null || m.groupId == _memberGroupFilter;
      return matchSearch && matchGroup;
    }).toList();
  }

  void setMemberSearch(String q) { _memberSearch = q; notifyListeners(); }
  void setMemberGroupFilter(int? id) { _memberGroupFilter = id; notifyListeners(); }

  Future<void> loadMembers({int? groupId, bool activeOnly = false}) async {
    if (_currentOrg == null) return;
    final maps = await _db.getMembers(_currentOrg!.id!,
        groupId: groupId, activeOnly: activeOnly);
    _members = maps.map((m) => Member.fromMap(m)).toList();
    notifyListeners();
  }

  Future<bool> addMember(Member m) async {
    try {
      await _db.insertMember(m.toMap());
      await _db.logActivity(_currentUser?.id, _currentOrg?.id, 'ADD_MEMBER', 'Membre ajouté: ${m.fullName}');
      await loadMembers();
      return true;
    } catch (e) { return false; }
  }

  Future<bool> updateMember(Member m) async {
    try {
      await _db.updateMember(m.id!, m.toMap());
      await loadMembers();
      return true;
    } catch (e) { return false; }
  }

  Future<bool> deleteMember(int id) async {
    try {
      await _db.deleteMember(id);
      await loadMembers();
      return true;
    } catch (e) { return false; }
  }

  Future<bool> toggleMemberStatus(Member m) async {
    return await updateMember(Member(
      id: m.id, orgId: m.orgId, firstName: m.firstName, lastName: m.lastName,
      phone: m.phone, email: m.email, function: m.function,
      groupId: m.groupId, isActive: !m.isActive,
    ));
  }

  Future<bool> assignMembersToGroup(List<int> memberIds, int? groupId) async {
    try {
      await _db.assignMembersToGroup(memberIds, groupId);
      await loadMembers();
      await loadGroups();
      return true;
    } catch (e) { return false; }
  }

  Future<int> importMembersFromExcel(List<Map<String, dynamic>> members) async {
    if (_currentOrg == null) return 0;
    int count = await _db.importMembers(_currentOrg!.id!, members);
    await _db.logActivity(_currentUser?.id, _currentOrg?.id, 'IMPORT_MEMBERS', '$count membres importés');
    await loadMembers();
    return count;
  }

  Future<List<Map<String, dynamic>>> getMemberHistory(int memberId) async {
    return await _db.getMemberHistory(memberId);
  }

  // ===== SESSIONS =====
  Future<void> loadSessions({int? groupId}) async {
    if (_currentOrg == null) return;
    final maps = await _db.getSessions(_currentOrg!.id!, groupId: groupId);
    _sessions = maps.map((m) => Session.fromMap(m)).toList();
    notifyListeners();
  }

  Future<int?> createSession(String date, int? groupId, String sessionType, String? label) async {
    if (_currentOrg == null) return null;
    try {
      final id = await _db.insertSession({
        'org_id': _currentOrg!.id, 'date': date,
        'group_id': groupId, 'session_type': sessionType, 'label': label,
      });
      await _db.logActivity(_currentUser?.id, _currentOrg?.id,
          'CREATE_SESSION', 'Session créée: $sessionType - $date');
      await loadSessions();
      return id;
    } catch (e) { return null; }
  }

  Future<void> loadSessionAttendances(int sessionId) async {
    final maps = await _db.getAttendances(sessionId);
    _currentAttendances = maps.map((m) => Attendance.fromMap(m)).toList();
    notifyListeners();
  }

  /// Initialise les présences à partir des membres ET applique les presets automatiquement
  Future<void> initAttendancesFromMembersWithPresets(
      int sessionId, List<Member> members, String sessionDate) async {
    // Charger les presets actifs pour cette date
    final presetMaps = _currentOrg != null
        ? await _db.getPresetsForDate(_currentOrg!.id!, sessionDate)
        : <Map<String, dynamic>>[];

    // Construire un map memberId → preset
    final presetByMember = <int, Map<String, dynamic>>{
      for (final p in presetMaps) (p['member_id'] as int): p
    };

    _currentAttendances = members.map((m) {
      final preset = presetByMember[m.id];
      if (preset != null) {
        // Appliquer le preset
        return Attendance(
          sessionId: sessionId,
          memberId: m.id!,
          status: AttendanceStatusExt.fromString(preset['status'] ?? 'permission'),
          comment: preset['comment'] as String?,
          firstName: m.firstName,
          lastName: m.lastName,
          function: m.function,
          presetApplied: true,
        );
      }
      return Attendance(
        sessionId: sessionId,
        memberId: m.id!,
        status: AttendanceStatus.present,
        firstName: m.firstName,
        lastName: m.lastName,
        function: m.function,
      );
    }).toList();

    notifyListeners();
  }

  // Méthode legacy compatible avec l'ancienne signature
  void initAttendancesFromMembers(int sessionId, List<Member> members) {
    _currentAttendances = members.map((m) => Attendance(
      sessionId: sessionId, memberId: m.id!,
      status: AttendanceStatus.present,
      firstName: m.firstName, lastName: m.lastName, function: m.function,
    )).toList();
    notifyListeners();
  }

  void updateAttendanceStatus(int index, AttendanceStatus status) {
    if (index < _currentAttendances.length) {
      _currentAttendances[index].status = status;
      _currentAttendances[index].presetApplied = false; // modifié manuellement
      notifyListeners();
    }
  }

  void updateLateMinutes(int index, int minutes, int threshold) {
    if (index < _currentAttendances.length) {
      _currentAttendances[index].lateMinutes = minutes;
      if (minutes >= threshold) _currentAttendances[index].status = AttendanceStatus.absent;
      notifyListeners();
    }
  }

  void updateComment(int index, String? comment) {
    if (index < _currentAttendances.length) {
      _currentAttendances[index].comment = comment;
      notifyListeners();
    }
  }

  void markAllPresent() {
    for (var a in _currentAttendances) {
      a.status = AttendanceStatus.present;
      a.presetApplied = false;
    }
    notifyListeners();
  }

  void markAllAbsent() {
    for (var a in _currentAttendances) {
      a.status = AttendanceStatus.absent;
      a.presetApplied = false;
    }
    notifyListeners();
  }

  Future<bool> saveAttendances(int sessionId) async {
    try {
      await _db.saveAttendances(
          sessionId, _currentAttendances.map((a) => a.toMap()).toList());
      await _db.logActivity(_currentUser?.id, _currentOrg?.id,
          'SAVE_ATTENDANCE',
          'Appel enregistré: session $sessionId, ${_currentAttendances.length} membres');
      await loadSessions();
      await loadDashboardStats();
      return true;
    } catch (e) { return false; }
  }

  Future<bool> deleteSession(int id) async {
    try {
      await _db.deleteSession(id);
      await loadSessions();
      return true;
    } catch (e) { return false; }
  }

  // ===== PRESETS DE PRÉSENCE =====
  Future<void> loadPresets() async {
    if (_currentOrg == null) return;
    final maps = await _db.getAllPresets(_currentOrg!.id!);
    _presets = maps.map((m) => AttendancePreset.fromMap(m)).toList();
    notifyListeners();
  }

  Future<bool> addPreset(AttendancePreset preset) async {
    try {
      await _db.insertPreset(preset.toMap());
      await loadPresets();
      return true;
    } catch (e) { return false; }
  }

  Future<bool> deletePreset(int id) async {
    try {
      await _db.deletePreset(id);
      await loadPresets();
      return true;
    } catch (e) { return false; }
  }

  /// Supprime les presets expirés (date_end dépassée)
  Future<void> cleanExpiredPresets() async {
    if (_currentOrg == null) return;
    await _db.deleteExpiredPresets(_currentOrg!.id!);
    await loadPresets();
  }

  // ===== STATS =====
  Future<void> loadDashboardStats() async {
    if (_currentOrg == null) return;
    _dashboardStats = await _db.getDashboardStats(_currentOrg!.id!);
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getAttendanceByPeriod(
      String start, String end, {int? groupId, String? statusFilter}) async {
    if (_currentOrg == null) return [];
    return await _db.getAttendanceByPeriod(_currentOrg!.id!, start, end,
        groupId: groupId, statusFilter: statusFilter);
  }

  // ===== PÉNALITÉS =====
  Future<void> loadPenaltyConfig() async {
    if (_currentOrg == null) return;
    final map = await _db.getPenaltyConfig(_currentOrg!.id!);
    if (map != null) _penaltyConfig = PenaltyConfig.fromMap(map);
    notifyListeners();
  }

  Future<bool> updatePenaltyConfig(PenaltyConfig config) async {
    if (_currentOrg == null) return false;
    try {
      await _db.updatePenaltyConfig(_currentOrg!.id!, config.toMap());
      _penaltyConfig = config;
      notifyListeners();
      return true;
    } catch (e) { return false; }
  }

  Future<void> calculatePenalties(String start, String end, {int? groupId}) async {
    if (_currentOrg == null) return;
    _isLoading = true; notifyListeners();
    try {
      final data = await _db.getMemberPenalties(_currentOrg!.id!, start, end, groupId: groupId);
      _penalties = data.map((r) {
        final total = _penaltyConfig.calculate(
            r['absent_count'] as int? ?? 0, r['late_count'] as int? ?? 0);
        return {...r, 'total_penalty': total, 'currency': _penaltyConfig.currency};
      }).toList();
      _penalties.sort((a, b) =>
          (b['total_penalty'] as double).compareTo(a['total_penalty'] as double));
    } catch (e) { debugPrint('Error: $e'); }
    _isLoading = false; notifyListeners();
  }

  // ===== UTILISATEURS (Super Admin) =====
  Future<void> loadUsers() async {
    final maps = await _db.getUsers();
    _users = maps.map((m) => AppUser.fromMap(m)).toList();
    notifyListeners();
  }

  Future<bool> addUser(AppUser user) async {
    try {
      await _db.insertUser(user.toMap());
      await _db.logActivity(_currentUser?.id, null, 'ADD_USER', 'Utilisateur créé: ${user.username}');
      await loadUsers();
      return true;
    } catch (e) { return false; }
  }

  Future<bool> updateUser(AppUser user) async {
    try {
      await _db.updateUser(user.id!, user.toMap());
      await loadUsers();
      return true;
    } catch (e) { return false; }
  }

  Future<bool> deleteUser(int id) async {
    try {
      await _db.deleteUser(id);
      await _db.logActivity(_currentUser?.id, null, 'DELETE_USER', 'Utilisateur supprimé');
      await loadUsers();
      return true;
    } catch (e) { return false; }
  }

  Future<void> blockUser(int id, bool blocked) async {
    await _db.blockUser(id, blocked);
    await _db.logActivity(_currentUser?.id, null, 'BLOCK_USER',
        'Utilisateur ${blocked ? 'bloqué' : 'débloqué'}');
    await loadUsers();
  }

  Future<void> loadActivityLog() async {
    _activityLog = await _db.getActivityLog();
    notifyListeners();
  }

  // ===== PARAMÈTRES =====
  Future<void> setDarkMode(bool v) async {
    _isDarkMode = v;
    await _db.setSetting('dark_mode', v.toString());
    notifyListeners();
  }

  Future<void> setAttendanceMode(String mode) async {
    _attendanceMode = mode;
    await _db.setSetting('attendance_mode', mode);
    notifyListeners();
  }

  Future<bool> changePassword(String oldPass, String newPass) async {
    if (_currentUser == null) return false;
    if (_currentUser!.password != oldPass) return false;
    _currentUser!.password = newPass;
    await _db.updateUser(_currentUser!.id!, {'password': newPass});
    return true;
  }

  // ===== BACKUP =====
  /// Appelé après une restauration réussie pour recharger tout l'état
  Future<void> reloadAfterRestore() async {
    _currentUser = null;
    _currentOrg = null;
    _organizations = [];
    _groups = [];
    _members = [];
    _sessions = [];
    _presets = [];
    _dashboardStats = {};
    _penalties = [];
    _users = [];
    _activityLog = [];
    notifyListeners();
    // Recharger les orgs et sélectionner la première
    await loadOrganizations();
    if (_organizations.isNotEmpty) {
      _currentOrg = _organizations.first;
      await loadOrgData();
    }
    // Recharger l'utilisateur admin
    final adminMap = await _db.getUserByUsername('admin');
    if (adminMap != null) _currentUser = AppUser.fromMap(adminMap);
    notifyListeners();
  }
}
