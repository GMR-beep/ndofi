import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/common_widgets.dart';

const kSessionTypes = ['Réunion', 'Culte', 'Répétition', 'Service', 'Formation', 'Assemblée', 'Autre'];

// ─────────────────────────────────────────────
// ÉCRAN PRINCIPAL : liste des sessions
// ─────────────────────────────────────────────
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        context.read<AppState>().loadSessions());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Présences'),
        actions: [
          // Bouton gestion des présets
          IconButton(
            icon: const Icon(Icons.assignment_ind_outlined),
            tooltip: 'Présences pré-remplies',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PresetsScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (_, state, __) {
          if (state.sessions.isEmpty) {
            return EmptyState(
              message: 'Aucune session\nCommencez un nouvel appel',
              icon: Icons.checklist_outlined,
              actionLabel: 'Nouvel appel',
              onAction: _newSession,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: state.sessions.length,
            itemBuilder: (_, i) {
              final s = state.sessions[i];
              final rate = s.presenceRate;
              final color = rate >= 75
                  ? AppColors.present
                  : rate >= 50
                      ? AppColors.late
                      : AppColors.absent;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => _openSession(s.id!, s.date),
                  leading: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${rate.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.bold, color: color)),
                    ]),
                  ),
                  title: Text(s.displayTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Row(children: [
                    const Icon(Icons.calendar_today, size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(_fmt(s.date), style: const TextStyle(fontSize: 11)),
                    if (s.groupName != null) ...[
                      const Text(' · ', style: TextStyle(fontSize: 11)),
                      Text(s.groupName!, style: const TextStyle(fontSize: 11)),
                    ],
                    const Text(' · ', style: TextStyle(fontSize: 11)),
                    Icon(Icons.check_circle, size: 11, color: AppColors.present),
                    const SizedBox(width: 2),
                    Text('${s.presentCount}/${s.totalCount}',
                        style: const TextStyle(fontSize: 11)),
                  ]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.absent, size: 20),
                    onPressed: () => _deleteSession(s),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newSession,
        icon: const Icon(Icons.add_task),
        label: const Text('Nouvel appel'),
      ),
    );
  }

  String _fmt(String date) {
    try { return DateFormat('dd/MM/yyyy').format(DateTime.parse(date)); }
    catch (_) { return date; }
  }

  void _newSession() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _NewSessionSheet(onCreated: (id, date) {
        Navigator.pop(context);
        _openSession(id, date);
      }),
    );
  }

  void _openSession(int id, String date) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionScreen(sessionId: id, sessionDate: date)),
    ).then((_) => context.read<AppState>().loadSessions());
  }

  Future<void> _deleteSession(Session s) async {
    final ok = await showConfirmDialog(context,
        title: 'Supprimer la session',
        message: 'Supprimer cette session et toutes ses présences ?');
    if (ok && mounted) await context.read<AppState>().deleteSession(s.id!);
  }
}

// ─────────────────────────────────────────────
// NewSessionDirectScreen (quick action)
// ─────────────────────────────────────────────
class NewSessionDirectScreen extends StatelessWidget {
  const NewSessionDirectScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvel appel')),
      body: _NewSessionSheet(
        onCreated: (id, date) => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SessionScreen(sessionId: id, sessionDate: date)),
        ),
        standalone: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Feuille de création de session
// ─────────────────────────────────────────────
class _NewSessionSheet extends StatefulWidget {
  final Function(int id, String date) onCreated;
  final bool standalone;
  const _NewSessionSheet({required this.onCreated, this.standalone = false});
  @override
  State<_NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends State<_NewSessionSheet> {
  DateTime _date = DateTime.now();
  int? _groupId;
  String _sessionType = 'Réunion';
  final _labelCtrl = TextEditingController();

  @override
  void dispose() { _labelCtrl.dispose(); super.dispose(); }

  Widget _buildContent() {
    final state = context.read<AppState>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.standalone) ...[
          const Text('Nouvel appel',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
        ],
        const Text('Type de session *',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: kSessionTypes.map((t) {
            final isSelected = _sessionType == t;
            return GestureDetector(
              onTap: () => setState(() => _sessionType = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.3)),
                ),
                child: Text(t,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.primary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    )),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _labelCtrl,
          decoration: const InputDecoration(
            labelText: 'Label optionnel',
            hintText: 'ex: Répétition du lundi',
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 7)),
            );
            if (d != null) setState(() => _date = d);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
              const SizedBox(width: 12),
              Text(DateFormat('dd MMMM yyyy', 'fr_FR').format(_date),
                  style: const TextStyle(fontSize: 15)),
              const Spacer(),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          value: _groupId,
          decoration: const InputDecoration(
              labelText: 'Groupe (optionnel)', prefixIcon: Icon(Icons.group)),
          hint: const Text('Tous les membres actifs'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous les membres')),
            ...state.groups.map((g) =>
                DropdownMenuItem(value: g.id, child: Text(g.name))),
          ],
          onChanged: (v) => setState(() => _groupId = v),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Démarrer l\'appel'),
          onPressed: () async {
            final dateStr = DateFormat('yyyy-MM-dd').format(_date);
            final label =
                _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim();
            final id = await context
                .read<AppState>()
                .createSession(dateStr, _groupId, _sessionType, label);
            if (id != null) widget.onCreated(id, dateStr);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.standalone) {
      return ListView(padding: const EdgeInsets.all(24), children: [_buildContent()]);
    }
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: _buildContent(),
    );
  }
}

// ─────────────────────────────────────────────
// SESSION SCREEN — avec auto-fill presets
// ─────────────────────────────────────────────
class SessionScreen extends StatefulWidget {
  final int sessionId;
  final String sessionDate;
  const SessionScreen({super.key, required this.sessionId, required this.sessionDate});
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  bool _loaded = false;
  int _lateThreshold = 30;
  String _searchQuery = '';
  int _presetAppliedCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final state = context.read<AppState>();
    _lateThreshold = state.penaltyConfig.lateThreshold;
    await state.loadSessionAttendances(widget.sessionId);

    if (state.currentAttendances.isEmpty) {
      // Nouvelle session : charger membres + appliquer presets
      await state.loadMembers(activeOnly: true);
      await state.initAttendancesFromMembersWithPresets(
          widget.sessionId, state.members, widget.sessionDate);
      // Compter combien ont été pré-remplis
      _presetAppliedCount =
          state.currentAttendances.where((a) => a.presetApplied).length;
    }

    setState(() => _loaded = true);

    // Afficher un toast si des presets ont été appliqués
    if (_presetAppliedCount > 0 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.auto_fix_high, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('$_presetAppliedCount présence(s) pré-remplie(s) automatiquement'),
          ]),
          backgroundColor: AppColors.special,
          duration: const Duration(seconds: 3),
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, state, _) {
      final isCompact = state.attendanceMode == 'compact';
      return Scaffold(
        appBar: AppBar(
          title: const Text('Appel des présences'),
          actions: [
            IconButton(
              icon: Icon(isCompact ? Icons.view_agenda : Icons.grid_view, size: 20),
              tooltip: isCompact ? 'Mode classique' : 'Mode compact',
              onPressed: () =>
                  state.setAttendanceMode(isCompact ? 'classic' : 'compact'),
            ),
          ],
        ),
        body: !_loaded
            ? const LoadingWidget()
            : Column(children: [
                // Stats bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration(
                          hintText: 'Rechercher...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatChip(label: '${state.sessionPresentCount}P', color: AppColors.present),
                    const SizedBox(width: 4),
                    _StatChip(label: '${state.sessionAbsentCount}A', color: AppColors.absent),
                    const SizedBox(width: 4),
                    _StatChip(label: '${state.sessionLateCount}R', color: AppColors.late),
                  ]),
                ),
                Container(
                  color: Colors.grey[50],
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Badge presets
                      if (_presetAppliedCount > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.special.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.special.withOpacity(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.auto_fix_high, size: 12, color: AppColors.special),
                            const SizedBox(width: 4),
                            Text('$_presetAppliedCount pré-remplis',
                                style: TextStyle(fontSize: 10, color: AppColors.special)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                      ],
                      TextButton.icon(
                        icon: const Icon(Icons.check_circle, color: AppColors.present, size: 16),
                        label: const Text('Tous Présents', style: TextStyle(fontSize: 11)),
                        onPressed: state.markAllPresent,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.cancel, color: AppColors.absent, size: 16),
                        label: const Text('Tous Absents', style: TextStyle(fontSize: 11)),
                        onPressed: state.markAllAbsent,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Builder(builder: (_) {
                    final list = _searchQuery.isEmpty
                        ? state.currentAttendances
                        : state.currentAttendances
                            .where((a) => a.memberName.toLowerCase()
                                .contains(_searchQuery.toLowerCase()))
                            .toList();
                    if (isCompact) {
                      return _CompactAttendanceList(
                        attendances: list,
                        onStatusChanged: (att, status) {
                          final index = state.currentAttendances.indexOf(att);
                          state.updateAttendanceStatus(index, status);
                        },
                        onLateChanged: (att, min) {
                          final index = state.currentAttendances.indexOf(att);
                          state.updateLateMinutes(index, min, _lateThreshold);
                        },
                      );
                    }
                    return _ClassicAttendanceList(
                      attendances: list,
                      onStatusChanged: (att, status) {
                        final index = state.currentAttendances.indexOf(att);
                        state.updateAttendanceStatus(index, status);
                      },
                      onLateChanged: (att, min) {
                        final index = state.currentAttendances.indexOf(att);
                        state.updateLateMinutes(index, min, _lateThreshold);
                      },
                      onCommentChanged: (att, c) {
                        final index = state.currentAttendances.indexOf(att);
                        state.updateComment(index, c);
                      },
                    );
                  }),
                ),
              ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer l\'appel',
                  style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
              onPressed: () async {
                final ok = await context
                    .read<AppState>()
                    .saveAttendances(widget.sessionId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? 'Appel enregistré !' : 'Erreur'),
                    backgroundColor: ok ? AppColors.present : AppColors.absent,
                  ));
                  if (ok) Navigator.pop(context);
                }
              },
            ),
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────
// ÉCRAN GESTION DES PRÉSETS
// ─────────────────────────────────────────────
class PresetsScreen extends StatefulWidget {
  const PresetsScreen({super.key});
  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<AppState>();
      await state.cleanExpiredPresets();
      await state.loadPresets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Présences pré-remplies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addPreset(context),
          ),
        ],
      ),
      body: Consumer<AppState>(builder: (_, state, __) {
        if (state.presets.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.assignment_ind_outlined,
                  size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('Aucune présence pré-remplie',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Définissez à l\'avance le statut d\'un membre\n'
                  '(permission, autorisation…) pour une date ou période.\n'
                  'Son statut sera appliqué automatiquement lors de l\'appel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un preset'),
                onPressed: () => _addPreset(context),
              ),
            ]),
          );
        }

        return Column(children: [
          // Info banner
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.special.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.special.withOpacity(0.3)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: AppColors.special, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ces statuts seront appliqués automatiquement lors du démarrage d\'un appel.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: state.presets.length,
              itemBuilder: (_, i) {
                final p = state.presets[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: p.status.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(p.status.icon, color: p.status.color, size: 20),
                    ),
                    title: Text(p.memberName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.status.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(p.status.label,
                              style: TextStyle(fontSize: 11, color: p.status.color,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today, size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(p.dateLabel, style: const TextStyle(fontSize: 11)),
                      ]),
                      if (p.comment != null && p.comment!.isNotEmpty)
                        Text(p.comment!,
                            style: const TextStyle(fontSize: 11,
                                color: AppColors.textSecondary)),
                    ]),
                    isThreeLine: p.comment != null && p.comment!.isNotEmpty,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.absent, size: 20),
                      onPressed: () async {
                        await state.deletePreset(p.id!);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ]);
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPreset(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }

  Future<void> _addPreset(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _AddPresetSheet(),
    );
  }
}

// ─────────────────────────────────────────────
// Feuille d'ajout d'un preset
// ─────────────────────────────────────────────
class _AddPresetSheet extends StatefulWidget {
  const _AddPresetSheet();
  @override
  State<_AddPresetSheet> createState() => _AddPresetSheetState();
}

class _AddPresetSheetState extends State<_AddPresetSheet> {
  Member? _selectedMember;
  AttendanceStatus _status = AttendanceStatus.permission;
  DateTime _dateStart = DateTime.now();
  DateTime? _dateEnd;
  bool _isPeriod = false;
  final _commentCtrl = TextEditingController();

  // Statuts pertinents pour les presets (pas 'present' ni 'absent')
  static const _presetStatuses = [
    AttendanceStatus.permission,
    AttendanceStatus.special,
    AttendanceStatus.late,
    AttendanceStatus.particular,
    AttendanceStatus.absent,
  ];

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final members = state.members.where((m) => m.isActive).toList();

    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ajouter un preset de présence',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Le statut sera appliqué automatiquement lors de l\'appel.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 20),

            // Sélection membre
            DropdownButtonFormField<Member>(
              value: _selectedMember,
              decoration: const InputDecoration(
                labelText: 'Membre *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              hint: const Text('Choisir un membre'),
              items: members.map((m) => DropdownMenuItem(
                value: m,
                child: Text(m.fullName),
              )).toList(),
              onChanged: (m) => setState(() => _selectedMember = m),
            ),
            const SizedBox(height: 16),

            // Statut
            const Text('Statut *',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _presetStatuses.map((s) {
                final isSelected = _status == s;
                return GestureDetector(
                  onTap: () => setState(() => _status = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? s.color : s.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: s.color, width: isSelected ? 2 : 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(s.icon, size: 14,
                          color: isSelected ? Colors.white : s.color),
                      const SizedBox(width: 4),
                      Text(s.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : s.color,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          )),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Jour unique ou période
            Row(children: [
              const Text('Type :', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('Jour unique'),
                selected: !_isPeriod,
                onSelected: (_) => setState(() { _isPeriod = false; _dateEnd = null; }),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Période'),
                selected: _isPeriod,
                onSelected: (_) => setState(() {
                  _isPeriod = true;
                  _dateEnd = _dateStart.add(const Duration(days: 6));
                }),
              ),
            ]),
            const SizedBox(height: 12),

            // Date(s)
            _DatePicker(
              label: _isPeriod ? 'Date de début *' : 'Date *',
              date: _dateStart,
              onChanged: (d) => setState(() => _dateStart = d),
            ),
            if (_isPeriod) ...[
              const SizedBox(height: 8),
              _DatePicker(
                label: 'Date de fin *',
                date: _dateEnd ?? _dateStart.add(const Duration(days: 6)),
                onChanged: (d) => setState(() => _dateEnd = d),
              ),
            ],
            const SizedBox(height: 12),

            // Commentaire
            TextField(
              controller: _commentCtrl,
              decoration: const InputDecoration(
                labelText: 'Commentaire / Motif (optionnel)',
                prefixIcon: Icon(Icons.comment_outlined),
                hintText: 'ex: Voyage, maladie, service...',
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Enregistrer le preset'),
              onPressed: _selectedMember == null ? null : () async {
                final dateStr = DateFormat('yyyy-MM-dd').format(_dateStart);
                final dateEndStr = _isPeriod && _dateEnd != null
                    ? DateFormat('yyyy-MM-dd').format(_dateEnd!)
                    : null;

                final preset = AttendancePreset(
                  orgId: state.currentOrg!.id!,
                  memberId: _selectedMember!.id!,
                  dateStart: dateStr,
                  dateEnd: dateEndStr,
                  status: _status,
                  comment: _commentCtrl.text.trim().isEmpty
                      ? null
                      : _commentCtrl.text.trim(),
                );

                final ok = await state.addPreset(preset);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok
                        ? '✅ Preset enregistré pour ${_selectedMember!.fullName}'
                        : 'Erreur lors de l\'enregistrement'),
                    backgroundColor: ok ? AppColors.present : AppColors.absent,
                  ));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Widget date picker réutilisable
class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime date;
  final Function(DateTime) onChanged;
  const _DatePicker({required this.label, required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) onChanged(d);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11,
                color: AppColors.textSecondary)),
            Text(DateFormat('dd MMMM yyyy', 'fr_FR').format(date),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
          const Spacer(),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WIDGETS PARTAGÉS
// ─────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
  );
}

// ─────────────────────────────────────────────
// MODE CLASSIQUE
// ─────────────────────────────────────────────
class _ClassicAttendanceList extends StatelessWidget {
  final List<Attendance> attendances;
  final Function(Attendance, AttendanceStatus) onStatusChanged;
  final Function(Attendance, int) onLateChanged;
  final Function(Attendance, String?) onCommentChanged;
  const _ClassicAttendanceList({
    required this.attendances,
    required this.onStatusChanged,
    required this.onLateChanged,
    required this.onCommentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: attendances.length,
      itemBuilder: (_, i) {
        final att = attendances[i];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: att.status.color.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: att.status.color.withOpacity(0.2)),
          ),
          child: ExpansionTile(
            leading: Stack(clipBehavior: Clip.none, children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: att.status.color.withOpacity(0.15),
                child: Text(
                  '${att.lastName?.isNotEmpty == true ? att.lastName![0] : ''}'
                  '${att.firstName?.isNotEmpty == true ? att.firstName![0] : ''}',
                  style: TextStyle(color: att.status.color,
                      fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              // Indicateur preset
              if (att.presetApplied)
                Positioned(
                  right: -2, bottom: -2,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.special,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Icon(Icons.auto_fix_high,
                        size: 7, color: Colors.white),
                  ),
                ),
            ]),
            title: Text(att.memberName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: att.function != null
                ? Text(att.function!, style: const TextStyle(fontSize: 11))
                : null,
            trailing: StatusBadge(status: att.status),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  if (att.presetApplied) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.special.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(Icons.auto_fix_high, size: 12, color: AppColors.special),
                        const SizedBox(width: 6),
                        Text('Statut pré-rempli automatiquement',
                            style: TextStyle(fontSize: 11, color: AppColors.special)),
                      ]),
                    ),
                  ],
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: AttendanceStatus.values.map((s) {
                      final isSelected = att.status == s;
                      return GestureDetector(
                        onTap: () => onStatusChanged(att, s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? s.color : s.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: s.color,
                                width: isSelected ? 2 : 1),
                          ),
                          child: Text(s.label,
                              style: TextStyle(fontSize: 12,
                                color: isSelected ? Colors.white : s.color,
                                fontWeight: isSelected
                                    ? FontWeight.bold : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                  if (att.status == AttendanceStatus.late) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.access_time, size: 16, color: AppColors.late),
                      const SizedBox(width: 8),
                      const Text('Durée du retard :'),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: att.lateMinutes.toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => onLateChanged(att, int.tryParse(v) ?? 0),
                          decoration: const InputDecoration(
                              suffixText: 'min', isDense: true),
                        ),
                      ),
                    ]),
                  ],
                  if (att.status == AttendanceStatus.particular || att.comment != null) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: att.comment,
                      onChanged: (v) => onCommentChanged(att, v),
                      decoration: InputDecoration(
                        labelText: att.status == AttendanceStatus.particular
                            ? 'Commentaire obligatoire'
                            : 'Commentaire',
                        prefixIcon: const Icon(Icons.comment, size: 16),
                        isDense: true,
                      ),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// MODE COMPACT
// ─────────────────────────────────────────────
class _CompactAttendanceList extends StatelessWidget {
  final List<Attendance> attendances;
  final Function(Attendance, AttendanceStatus) onStatusChanged;
  final Function(Attendance, int) onLateChanged;
  const _CompactAttendanceList({
    required this.attendances,
    required this.onStatusChanged,
    required this.onLateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: attendances.length,
      itemBuilder: (_, i) {
        final att = attendances[i];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: att.status.color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: att.status.color.withOpacity(0.25)),
          ),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: att.status.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${att.lastName?.isNotEmpty == true ? att.lastName![0] : ''}'
                    '${att.firstName?.isNotEmpty == true ? att.firstName![0] : ''}',
                    style: TextStyle(color: att.status.color,
                        fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
              if (att.presetApplied)
                Positioned(
                  right: -2, bottom: -2,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.special,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(att.memberName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (att.function != null)
                  Text(att.function!,
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ]),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: AttendanceStatus.values.map((s) {
                final isSelected = att.status == s;
                return GestureDetector(
                  onTap: () {
                    onStatusChanged(att, s);
                    if (s == AttendanceStatus.late) {
                      _showLateDialog(context, att, onLateChanged);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 3),
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: isSelected ? s.color : s.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: s.color.withOpacity(isSelected ? 1 : 0.3),
                          width: isSelected ? 2 : 1),
                    ),
                    child: Tooltip(
                      message: s.label,
                      child: Icon(s.icon, size: 14,
                          color: isSelected ? Colors.white : s.color),
                    ),
                  ),
                );
              }).toList(),
            ),
          ]),
        );
      },
    );
  }

  void _showLateDialog(BuildContext context, Attendance att,
      Function(Attendance, int) onLateChanged) {
    final ctrl = TextEditingController(
        text: att.lateMinutes > 0 ? att.lateMinutes.toString() : '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Retard - ${att.memberName}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Durée du retard (minutes)', suffixText: 'min'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              onLateChanged(att, int.tryParse(ctrl.text) ?? 0);
              Navigator.pop(context);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}
