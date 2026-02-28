import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // v4 = nouveau fichier propre, fin des problèmes de corruption
    String path = join(await getDatabasesPath(), 'ndofi_v4.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: (db) async {
        await db.execute('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA foreign_keys=OFF');

        // Garde-fou : si app_users n'existe pas, la DB est corrompue → on recrée
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='app_users'"
        );
        if (tables.isEmpty) {
          await _dropAll(db);
          await _onCreate(db, 1);
          return;
        }

        // S'assurer que l'admin existe toujours
        final admin = await db.query('app_users',
            where: 'username = ?', whereArgs: ['admin']);
        if (admin.isEmpty) {
          await db.insert('app_users', {
            'username': 'admin', 'password': 'admin123',
            'role': 'superadmin', 'is_blocked': 0, 'org_permissions': 'all',
          });
        }
      },
    );
  }

  Future<void> _dropAll(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'"
    );
    for (final t in tables) {
      await db.execute('DROP TABLE IF EXISTS "${t['name']}"');
    }
  }

  // ===== RESET URGENCE =====
  Future<void> resetAdminAccount() async {
    final db = await database;
    final existing = await db.query('app_users',
        where: 'username = ?', whereArgs: ['admin']);
    if (existing.isEmpty) {
      await db.insert('app_users', {
        'username': 'admin', 'password': 'admin123',
        'role': 'superadmin', 'is_blocked': 0, 'org_permissions': 'all',
      });
    } else {
      await db.update('app_users',
        {'password': 'admin123', 'is_blocked': 0},
        where: 'username = ?', whereArgs: ['admin'],
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE organizations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        logo_path TEXT,
        color TEXT DEFAULT '#1565C0',
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE app_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT DEFAULT 'user',
        is_blocked INTEGER DEFAULT 0,
        org_permissions TEXT DEFAULT '',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        last_login TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        org_id INTEGER,
        action TEXT NOT NULL,
        details TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        org_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        color TEXT DEFAULT '#1565C0',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        org_id INTEGER NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        function TEXT,
        group_id INTEGER,
        status INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        org_id INTEGER NOT NULL,
        group_id INTEGER,
        date TEXT NOT NULL,
        session_type TEXT DEFAULT 'Réunion',
        label TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE attendances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        member_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        late_minutes INTEGER DEFAULT 0,
        comment TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE penalty_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        org_id INTEGER UNIQUE NOT NULL,
        absence_amount REAL DEFAULT 200,
        late_amount REAL DEFAULT 100,
        unjustified_amount REAL DEFAULT 300,
        late_threshold INTEGER DEFAULT 30,
        currency TEXT DEFAULT 'F',
        enabled INTEGER DEFAULT 1
      )
    ''');

    // ── NOUVELLE TABLE : présences pré-remplies ──
    // Permet de définir à l'avance le statut d'un membre pour une date ou période
    await db.execute('''
      CREATE TABLE attendance_presets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        org_id INTEGER NOT NULL,
        member_id INTEGER NOT NULL,
        date_start TEXT NOT NULL,
        date_end TEXT,
        status TEXT NOT NULL,
        comment TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL
      )
    ''');

    // ── Données par défaut ──
    await db.insert('app_users', {
      'username': 'admin', 'password': 'admin123',
      'role': 'superadmin', 'is_blocked': 0, 'org_permissions': 'all',
    });

    await db.insert('app_settings', {'key': 'dark_mode', 'value': 'false'});
    await db.insert('app_settings', {'key': 'attendance_mode', 'value': 'classic'});
    await db.insert('app_settings', {'key': 'current_org_id', 'value': '0'});

    int orgId = await db.insert('organizations', {
      'name': 'Mon Organisation',
      'description': 'Organisation principale',
      'color': '#1565C0',
    });

    await db.insert('penalty_config', {
      'org_id': orgId, 'absence_amount': 200, 'late_amount': 100,
      'unjustified_amount': 300, 'late_threshold': 30,
      'currency': 'F', 'enabled': 1,
    });

    int g1 = await db.insert('groups', {'org_id': orgId, 'name': 'Soprano', 'color': '#1565C0'});
    int g2 = await db.insert('groups', {'org_id': orgId, 'name': 'Alto',    'color': '#2E7D32'});
    int g3 = await db.insert('groups', {'org_id': orgId, 'name': 'Tenor',   'color': '#E65100'});

    for (final m in [
      {'first_name': 'Marie',  'last_name': 'Dupont', 'function': 'Chef de section', 'group_id': g1},
      {'first_name': 'Sophie', 'last_name': 'Martin', 'function': 'Membre',          'group_id': g1},
      {'first_name': 'Jean',   'last_name': 'Durand', 'function': 'Chef de section', 'group_id': g2},
      {'first_name': 'Paul',   'last_name': 'Leblanc','function': 'Membre',          'group_id': g2},
      {'first_name': 'Pierre', 'last_name': 'Moreau', 'function': 'Chef de section', 'group_id': g3},
    ]) {
      await db.insert('members', {...m, 'org_id': orgId});
    }

    await db.insert('app_settings',
      {'key': 'current_org_id', 'value': orgId.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ===== BACKUP : EXPORT COMPLET =====
  Future<Map<String, dynamic>> exportAll() async {
    final db = await database;
    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'organizations':       await db.query('organizations'),
      'app_users':           await db.query('app_users'),
      'groups':              await db.query('groups'),
      'members':             await db.query('members'),
      'sessions':            await db.query('sessions'),
      'attendances':         await db.query('attendances'),
      'penalty_config':      await db.query('penalty_config'),
      'attendance_presets':  await db.query('attendance_presets'),
      'app_settings':        await db.query('app_settings'),
      'activity_log':        await db.query('activity_log'),
    };
  }

  // ===== BACKUP : IMPORT / RESTAURATION =====
  Future<void> importAll(Map<String, dynamic> data) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Supprimer toutes les données existantes (ordre FK)
      for (final t in ['activity_log', 'attendance_presets', 'attendances',
                        'sessions', 'members', 'groups', 'penalty_config',
                        'organizations', 'app_users', 'app_settings']) {
        await txn.delete(t);
      }

      // 2. Réinsérer depuis le backup
      Future<void> restore(String table, dynamic rows) async {
        if (rows == null) return;
        for (final row in (rows as List)) {
          await txn.insert(table, Map<String, dynamic>.from(row as Map),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      await restore('organizations',      data['organizations']);
      await restore('app_users',          data['app_users']);
      await restore('groups',             data['groups']);
      await restore('members',            data['members']);
      await restore('sessions',           data['sessions']);
      await restore('attendances',        data['attendances']);
      await restore('penalty_config',     data['penalty_config']);
      await restore('attendance_presets', data['attendance_presets']);
      await restore('app_settings',       data['app_settings']);
      await restore('activity_log',       data['activity_log']);

      // S'assurer que l'admin existe après restauration
      final adminCheck = await txn.query('app_users',
          where: 'username = ?', whereArgs: ['admin']);
      if (adminCheck.isEmpty) {
        await txn.insert('app_users', {
          'username': 'admin', 'password': 'admin123',
          'role': 'superadmin', 'is_blocked': 0, 'org_permissions': 'all',
        });
      }
    });
  }

  // ===== ORGANISATIONS =====
  Future<List<Map<String, dynamic>>> getOrganizations() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT o.*,
        (SELECT COUNT(*) FROM members m WHERE m.org_id = o.id AND m.status = 1) as member_count,
        (SELECT COUNT(*) FROM groups g WHERE g.org_id = o.id) as group_count
      FROM organizations o ORDER BY o.name
    ''');
  }

  Future<int> insertOrganization(Map<String, dynamic> org) async {
    final db = await database;
    int id = await db.insert('organizations', org);
    await db.insert('penalty_config', {
      'org_id': id, 'absence_amount': 200, 'late_amount': 100,
      'unjustified_amount': 300, 'late_threshold': 30, 'currency': 'F', 'enabled': 1,
    });
    return id;
  }

  Future<void> updateOrganization(int id, Map<String, dynamic> org) async {
    final db = await database;
    await db.update('organizations', org, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteOrganization(int id) async {
    final db = await database;
    await db.delete('organizations', where: 'id = ?', whereArgs: [id]);
    await db.delete('groups', where: 'org_id = ?', whereArgs: [id]);
    await db.delete('members', where: 'org_id = ?', whereArgs: [id]);
    await db.delete('penalty_config', where: 'org_id = ?', whereArgs: [id]);
    await db.delete('attendance_presets', where: 'org_id = ?', whereArgs: [id]);
    final sessions = await db.query('sessions', where: 'org_id = ?', whereArgs: [id]);
    for (var s in sessions) {
      await db.delete('attendances', where: 'session_id = ?', whereArgs: [s['id']]);
    }
    await db.delete('sessions', where: 'org_id = ?', whereArgs: [id]);
  }

  // ===== UTILISATEURS =====
  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return await db.query('app_users', orderBy: 'role DESC, username');
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final r = await db.query('app_users', where: 'username = ?', whereArgs: [username]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<bool> authenticateUser(String username, String password) async {
    try {
      final user = await getUserByUsername(username);
      if (user == null) return false;
      if ((user['is_blocked'] as int) == 1) return false;
      if (user['password'] != password) return false;
      final db = await database;
      await db.update('app_users',
        {'last_login': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [user['id']],
      );
      await logActivity(user['id'] as int, null, 'LOGIN', 'Connexion réussie');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('app_users', user);
  }

  Future<void> updateUser(int id, Map<String, dynamic> user) async {
    final db = await database;
    await db.update('app_users', user, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteUser(int id) async {
    final db = await database;
    await db.delete('app_users', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> blockUser(int id, bool blocked) async {
    final db = await database;
    await db.update('app_users', {'is_blocked': blocked ? 1 : 0},
      where: 'id = ?', whereArgs: [id]);
  }

  // ===== JOURNAL =====
  Future<void> logActivity(int? userId, int? orgId, String action, String? details) async {
    final db = await database;
    await db.insert('activity_log', {
      'user_id': userId, 'org_id': orgId,
      'action': action, 'details': details,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getActivityLog({int limit = 100}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT al.*, u.username, o.name as org_name
      FROM activity_log al
      LEFT JOIN app_users u ON al.user_id = u.id
      LEFT JOIN organizations o ON al.org_id = o.id
      ORDER BY al.created_at DESC LIMIT $limit
    ''');
  }

  // ===== GROUPES =====
  Future<List<Map<String, dynamic>>> getGroups(int orgId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT g.*, COUNT(m.id) as member_count
      FROM groups g
      LEFT JOIN members m ON g.id = m.group_id AND m.status = 1
      WHERE g.org_id = ? GROUP BY g.id ORDER BY g.name
    ''', [orgId]);
  }

  Future<int> insertGroup(Map<String, dynamic> group) async {
    final db = await database;
    return await db.insert('groups', group);
  }

  Future<void> updateGroup(int id, Map<String, dynamic> group) async {
    final db = await database;
    await db.update('groups', group, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteGroup(int id) async {
    final db = await database;
    await db.update('members', {'group_id': null}, where: 'group_id = ?', whereArgs: [id]);
    await db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  // ===== MEMBRES =====
  Future<List<Map<String, dynamic>>> getMembers(int orgId,
      {int? groupId, bool activeOnly = false, bool noGroup = false}) async {
    final db = await database;
    String q = '''
      SELECT m.*, g.name as group_name, g.color as group_color
      FROM members m LEFT JOIN groups g ON m.group_id = g.id
      WHERE m.org_id = ?
    ''';
    List<dynamic> args = [orgId];
    if (groupId != null) { q += ' AND m.group_id = ?'; args.add(groupId); }
    if (activeOnly) { q += ' AND m.status = 1'; }
    if (noGroup) { q += ' AND m.group_id IS NULL'; }
    q += ' ORDER BY m.last_name, m.first_name';
    return await db.rawQuery(q, args);
  }

  Future<int> insertMember(Map<String, dynamic> member) async {
    final db = await database;
    return await db.insert('members', member);
  }

  Future<void> updateMember(int id, Map<String, dynamic> member) async {
    final db = await database;
    await db.update('members', member, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMember(int id) async {
    final db = await database;
    await db.delete('members', where: 'id = ?', whereArgs: [id]);
    await db.delete('attendance_presets', where: 'member_id = ?', whereArgs: [id]);
  }

  Future<void> assignMembersToGroup(List<int> memberIds, int? groupId) async {
    final db = await database;
    for (var id in memberIds) {
      await db.update('members', {'group_id': groupId}, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<int> importMembers(int orgId, List<Map<String, dynamic>> members) async {
    final db = await database;
    int count = 0;
    for (var m in members) {
      await db.insert('members', {...m, 'org_id': orgId});
      count++;
    }
    return count;
  }

  Future<List<Map<String, dynamic>>> getMemberHistory(int memberId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT a.*, s.date, s.session_type, s.label, g.name as group_name
      FROM attendances a
      JOIN sessions s ON a.session_id = s.id
      LEFT JOIN groups g ON s.group_id = g.id
      WHERE a.member_id = ? ORDER BY s.date DESC
    ''', [memberId]);
  }

  // ===== SESSIONS =====
  Future<List<Map<String, dynamic>>> getSessions(int orgId, {int? groupId}) async {
    final db = await database;
    String q = '''
      SELECT s.*, g.name as group_name,
        (SELECT COUNT(*) FROM attendances a WHERE a.session_id = s.id AND a.status = 'present') as present_count,
        (SELECT COUNT(*) FROM attendances a WHERE a.session_id = s.id) as total_count
      FROM sessions s LEFT JOIN groups g ON s.group_id = g.id
      WHERE s.org_id = ?
    ''';
    List<dynamic> args = [orgId];
    if (groupId != null) { q += ' AND s.group_id = ?'; args.add(groupId); }
    q += ' ORDER BY s.date DESC, s.id DESC';
    return await db.rawQuery(q, args);
  }

  Future<int> insertSession(Map<String, dynamic> session) async {
    final db = await database;
    return await db.insert('sessions', session);
  }

  Future<void> deleteSession(int id) async {
    final db = await database;
    await db.delete('attendances', where: 'session_id = ?', whereArgs: [id]);
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  // ===== PRESENCES =====
  Future<List<Map<String, dynamic>>> getAttendances(int sessionId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT a.*, m.first_name, m.last_name, m.function
      FROM attendances a JOIN members m ON a.member_id = m.id
      WHERE a.session_id = ? ORDER BY m.last_name, m.first_name
    ''', [sessionId]);
  }

  Future<void> saveAttendances(int sessionId, List<Map<String, dynamic>> list) async {
    final db = await database;
    await db.delete('attendances', where: 'session_id = ?', whereArgs: [sessionId]);
    for (var att in list) {
      await db.insert('attendances', att);
    }
  }

  // ===== PRESETS DE PRÉSENCE =====
  /// Retourne les presets actifs pour une date donnée (date_start <= date <= date_end ou date_end IS NULL et date_start = date)
  Future<List<Map<String, dynamic>>> getPresetsForDate(int orgId, String date) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, m.first_name, m.last_name, m.function
      FROM attendance_presets p
      JOIN members m ON p.member_id = m.id
      WHERE p.org_id = ?
        AND p.date_start <= ?
        AND (p.date_end IS NULL AND p.date_start = ? 
             OR p.date_end IS NOT NULL AND p.date_end >= ?)
      ORDER BY m.last_name, m.first_name
    ''', [orgId, date, date, date]);
  }

  Future<List<Map<String, dynamic>>> getAllPresets(int orgId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, m.first_name, m.last_name, m.function, g.name as group_name
      FROM attendance_presets p
      JOIN members m ON p.member_id = m.id
      LEFT JOIN groups g ON m.group_id = g.id
      WHERE p.org_id = ?
      ORDER BY p.date_start DESC, m.last_name
    ''', [orgId]);
  }

  Future<int> insertPreset(Map<String, dynamic> preset) async {
    final db = await database;
    return await db.insert('attendance_presets', preset);
  }

  Future<void> deletePreset(int id) async {
    final db = await database;
    await db.delete('attendance_presets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExpiredPresets(int orgId) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await db.delete('attendance_presets',
      where: 'org_id = ? AND date_end IS NOT NULL AND date_end < ?',
      whereArgs: [orgId, today],
    );
  }

  // ===== STATS =====
  Future<Map<String, dynamic>> getDashboardStats(int orgId) async {
    final db = await database;
    final mc  = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM members WHERE org_id = ? AND status = 1', [orgId])) ?? 0;
    final tot = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM attendances a JOIN sessions s ON a.session_id = s.id WHERE s.org_id = ?', [orgId])) ?? 0;
    final pre = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM attendances a JOIN sessions s ON a.session_id = s.id WHERE s.org_id = ? AND a.status = 'present'", [orgId])) ?? 0;
    final abs = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM attendances a JOIN sessions s ON a.session_id = s.id WHERE s.org_id = ? AND a.status IN ('absent','permission')", [orgId])) ?? 0;
    final lat = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM attendances a JOIN sessions s ON a.session_id = s.id WHERE s.org_id = ? AND a.status = 'late'", [orgId])) ?? 0;
    final sc  = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sessions WHERE org_id = ?', [orgId])) ?? 0;
    return {
      'member_count': mc, 'session_count': sc, 'total_attendances': tot,
      'present_count': pre, 'absent_count': abs, 'late_count': lat,
      'presence_rate': (tot > 0 ? (pre / tot * 100) : 0.0).toStringAsFixed(1),
    };
  }

  Future<List<Map<String, dynamic>>> getAttendanceByPeriod(
      int orgId, String start, String end, {int? groupId, String? statusFilter}) async {
    final db = await database;
    String q = '''
      SELECT a.*, m.first_name, m.last_name, m.function, m.phone,
             s.date, s.session_type, s.label, g.name as group_name
      FROM attendances a
      JOIN members m ON a.member_id = m.id
      JOIN sessions s ON a.session_id = s.id
      LEFT JOIN groups g ON s.group_id = g.id
      WHERE s.org_id = ? AND s.date BETWEEN ? AND ?
    ''';
    List<dynamic> args = [orgId, start, end];
    if (groupId != null) { q += ' AND s.group_id = ?'; args.add(groupId); }
    if (statusFilter != null && statusFilter != 'all') {
      if (statusFilter == 'absent') {
        q += " AND a.status IN ('absent','permission')";
      } else {
        q += ' AND a.status = ?'; args.add(statusFilter);
      }
    }
    q += ' ORDER BY s.date, m.last_name';
    return await db.rawQuery(q, args);
  }

  // ===== PENALITES =====
  Future<Map<String, dynamic>?> getPenaltyConfig(int orgId) async {
    final db = await database;
    final r = await db.query('penalty_config', where: 'org_id = ?', whereArgs: [orgId]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<void> updatePenaltyConfig(int orgId, Map<String, dynamic> config) async {
    final db = await database;
    await db.update('penalty_config', config, where: 'org_id = ?', whereArgs: [orgId]);
  }

  Future<List<Map<String, dynamic>>> getMemberPenalties(
      int orgId, String start, String end, {int? groupId}) async {
    final db = await database;
    String q = '''
      SELECT m.id, m.first_name, m.last_name, m.function, g.name as group_name,
        COUNT(CASE WHEN a.status IN ('absent','permission') THEN 1 END) as absent_count,
        COUNT(CASE WHEN a.status = 'late' THEN 1 END) as late_count
      FROM members m
      LEFT JOIN groups g ON m.group_id = g.id
      LEFT JOIN attendances a ON m.id = a.member_id
      LEFT JOIN sessions s ON a.session_id = s.id AND s.date BETWEEN ? AND ? AND s.org_id = ?
      WHERE m.org_id = ? AND m.status = 1
    ''';
    List<dynamic> args = [start, end, orgId, orgId];
    if (groupId != null) { q += ' AND m.group_id = ?'; args.add(groupId); }
    q += ' GROUP BY m.id ORDER BY absent_count DESC';
    return await db.rawQuery(q, args);
  }

  // ===== PARAMETRES =====
  Future<String?> getSetting(String key) async {
    final db = await database;
    final r = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    return r.isNotEmpty ? r.first['value'] as String : null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
