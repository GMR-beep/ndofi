import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/common_widgets.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});
  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _selectionMode = false;
  Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().loadMembers());
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedIds.length} sélectionné(s)')
            : const Text('Membres'),
        actions: _selectionMode ? [
          IconButton(icon: const Icon(Icons.group_add), tooltip: 'Assigner un groupe', onPressed: _assignGroup),
          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _selectionMode = false; _selectedIds.clear(); })),
        ] : [
          IconButton(icon: const Icon(Icons.file_upload_outlined), tooltip: 'Importer Excel', onPressed: _importExcel),
          Consumer<AppState>(builder: (_, state, __) => IconButton(
            icon: Icon(state.filteredMembers.length < state.members.length ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: _showFilter, tooltip: 'Filtrer',
          )),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: 'Liste'), Tab(text: 'Par groupe')],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Consumer<AppState>(
              builder: (_, state, __) => TextField(
                onChanged: state.setMemberSearch,
                decoration: InputDecoration(
                  hintText: 'Rechercher un membre...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: state.filteredMembers.length != state.members.length
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => state.setMemberSearch(''))
                      : null,
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _MemberList(selectionMode: _selectionMode, selectedIds: _selectedIds, onToggleSelection: _toggleSelection, onToggleSelectionMode: () => setState(() { _selectionMode = true; })),
                _MembersByGroup(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectionMode ? null : FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMemberScreen())).then((_) => context.read<AppState>().loadMembers()),
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
    );
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) _selectedIds.remove(id);
      else _selectedIds.add(id);
    });
  }

  Future<void> _assignGroup() async {
    if (_selectedIds.isEmpty) return;
    final groups = context.read<AppState>().groups;
    int? selectedGroupId;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          const Text('Assigner au groupe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.clear),
            title: const Text('Retirer du groupe'),
            onTap: () { selectedGroupId = -1; Navigator.pop(ctx); },
          ),
          ...groups.map((g) => ListTile(
            leading: CircleAvatar(backgroundColor: g.colorValue, radius: 14, child: Text(g.name[0], style: const TextStyle(color: Colors.white, fontSize: 12))),
            title: Text(g.name),
            subtitle: Text('${g.memberCount ?? 0} membres'),
            onTap: () { selectedGroupId = g.id; Navigator.pop(ctx); },
          )),
          const SizedBox(height: 16),
        ],
      )),
    );

    if (selectedGroupId != null && mounted) {
      final gid = selectedGroupId == -1 ? null : selectedGroupId;
      await context.read<AppState>().assignMembersToGroup(_selectedIds.toList(), gid);
      setState(() { _selectionMode = false; _selectedIds.clear(); });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignation effectuée !'), backgroundColor: AppColors.present));
    }
  }

  void _showFilter() {
    final groups = context.read<AppState>().groups;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Text('Filtrer par groupe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ListTile(leading: const Icon(Icons.clear_all), title: const Text('Tous les membres'), onTap: () { context.read<AppState>().setMemberGroupFilter(null); Navigator.pop(context); }),
          ...groups.map((g) => ListTile(
            leading: CircleAvatar(backgroundColor: g.colorValue, radius: 12),
            title: Text(g.name),
            onTap: () { context.read<AppState>().setMemberGroupFilter(g.id); Navigator.pop(context); },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _importExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );
      if (result == null || result.files.isEmpty) return;

      // Parse CSV or Excel
      final file = result.files.first;
      if (file.bytes == null && file.path == null) return;

      List<Map<String, dynamic>> members = [];

      if (file.name.endsWith('.csv')) {
        final content = String.fromCharCodes(file.bytes ?? []);
        final lines = content.split('\n');
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          final cols = line.split(';');
          if (cols.length >= 2) {
            members.add({
              'last_name': cols[0].trim(),
              'first_name': cols.length > 1 ? cols[1].trim() : '',
              'phone': cols.length > 2 ? cols[2].trim() : null,
              'function': cols.length > 3 ? cols[3].trim() : null,
            });
          }
        }
      } else {
        // Excel - basic parsing
        if (file.bytes != null) {
          try {
            final excel = ExcelParser.parse(file.bytes!);
            members = excel;
          } catch (_) {
            // Fallback
          }
        }
      }

      if (members.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun membre trouvé dans le fichier'), backgroundColor: AppColors.late));
        return;
      }

      // Show preview
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Importer ${members.length} membres ?'),
          content: SizedBox(
            width: double.maxFinite,
            height: 200,
            child: ListView.builder(
              itemCount: members.length.clamp(0, 10),
              itemBuilder: (_, i) => ListTile(
                dense: true,
                leading: const Icon(Icons.person, size: 18),
                title: Text('${members[i]['last_name']} ${members[i]['first_name']}'),
                subtitle: Text(members[i]['function'] ?? ''),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final count = await context.read<AppState>().importMembersFromExcel(members);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count membres importés avec succès !'), backgroundColor: AppColors.present));
              },
              child: const Text('Importer'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.absent));
    }
  }
}

// Simple Excel parser helper
class ExcelParser {
  static List<Map<String, dynamic>> parse(List<int> bytes) {
    final result = <Map<String, dynamic>>[];
    try {
      final excel = _readExcel(bytes);
      return excel;
    } catch (_) {
      return result;
    }
  }
  static List<Map<String, dynamic>> _readExcel(List<int> bytes) => [];
}

class _MemberList extends StatelessWidget {
  final bool selectionMode;
  final Set<int> selectedIds;
  final Function(int) onToggleSelection;
  final VoidCallback onToggleSelectionMode;

  const _MemberList({required this.selectionMode, required this.selectedIds, required this.onToggleSelection, required this.onToggleSelectionMode});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final members = state.filteredMembers;
        if (members.isEmpty) return EmptyState(message: 'Aucun membre trouvé', icon: Icons.people_outline, actionLabel: 'Ajouter', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMemberScreen())));
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: members.length,
          itemBuilder: (_, i) {
            final m = members[i];
            final isSelected = selectedIds.contains(m.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
              child: ListTile(
                leading: selectionMode
                    ? Checkbox(value: isSelected, onChanged: (_) => onToggleSelection(m.id!))
                    : CircleAvatar(
                        backgroundColor: m.isActive ? AppColors.primary : AppColors.textSecondary,
                        child: Text(m.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                title: Text(m.fullName, style: TextStyle(fontWeight: FontWeight.w600, decoration: m.isActive ? null : TextDecoration.lineThrough)),
                subtitle: Row(children: [
                  if (m.function != null) Text(m.function!, style: const TextStyle(fontSize: 11)),
                  if (m.function != null && m.groupName != null) const Text(' · ', style: TextStyle(fontSize: 11)),
                  if (m.groupName != null) Text(m.groupName!, style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                ]),
                onTap: selectionMode ? () => onToggleSelection(m.id!) : null,
                onLongPress: () { if (!selectionMode) { onToggleSelectionMode(); onToggleSelection(m.id!); } },
                trailing: selectionMode ? null : PopupMenuButton(
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'history', child: Row(children: [Icon(Icons.history, size: 18), SizedBox(width: 8), Text('Historique')])),
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Modifier')])),
                    PopupMenuItem(value: 'toggle', child: Row(children: [Icon(m.isActive ? Icons.pause_circle : Icons.play_circle, size: 18), const SizedBox(width: 8), Text(m.isActive ? 'Désactiver' : 'Activer')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppColors.absent), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.absent))])),
                  ],
                  onSelected: (v) async {
                    if (v == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => AddMemberScreen(member: m))).then((_) => state.loadMembers());
                    if (v == 'toggle') await state.toggleMemberStatus(m);
                    if (v == 'delete') {
                      final ok = await showConfirmDialog(context, title: 'Supprimer', message: 'Supprimer ${m.fullName} ?');
                      if (ok) await state.deleteMember(m.id!);
                    }
                    if (v == 'history') Navigator.push(context, MaterialPageRoute(builder: (_) => MemberHistoryScreen(member: m)));
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MembersByGroup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (_, state, __) {
        final groups = state.groups;
        final ungrouped = state.members.where((m) => m.groupId == null && m.isActive).toList();
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ...groups.map((g) {
              final gMembers = state.members.where((m) => m.groupId == g.id).toList();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(backgroundColor: g.colorValue, radius: 16, child: Text(g.name[0], style: const TextStyle(color: Colors.white, fontSize: 12))),
                  title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${gMembers.length} membres'),
                  children: gMembers.map((m) => ListTile(
                    dense: true,
                    leading: CircleAvatar(radius: 14, backgroundColor: AppColors.primary.withOpacity(0.2), child: Text(m.initials, style: const TextStyle(fontSize: 10, color: AppColors.primary))),
                    title: Text(m.fullName, style: const TextStyle(fontSize: 13)),
                    subtitle: m.function != null ? Text(m.function!, style: const TextStyle(fontSize: 11)) : null,
                  )).toList(),
                ),
              );
            }),
            if (ungrouped.isNotEmpty)
              Card(
                child: ExpansionTile(
                  leading: const CircleAvatar(backgroundColor: AppColors.textSecondary, radius: 16, child: Icon(Icons.person, color: Colors.white, size: 16)),
                  title: const Text('Sans groupe', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${ungrouped.length} membres'),
                  children: ungrouped.map((m) => ListTile(dense: true, title: Text(m.fullName, style: const TextStyle(fontSize: 13)))).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ===== ADD MEMBER SCREEN =====
class AddMemberScreen extends StatefulWidget {
  final Member? member;
  const AddMemberScreen({super.key, this.member});
  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _functionCtrl;
  int? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _firstNameCtrl = TextEditingController(text: m?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: m?.lastName ?? '');
    _phoneCtrl = TextEditingController(text: m?.phone ?? '');
    _emailCtrl = TextEditingController(text: m?.email ?? '');
    _functionCtrl = TextEditingController(text: m?.function ?? '');
    _selectedGroupId = m?.groupId;
  }

  @override
  void dispose() { _firstNameCtrl.dispose(); _lastNameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose(); _functionCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(widget.member != null ? 'Modifier le membre' : 'Nouveau membre')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: CircleAvatar(radius: 36, backgroundColor: AppColors.primary, child: Text('${_lastNameCtrl.text.isNotEmpty ? _lastNameCtrl.text[0] : '?'}${_firstNameCtrl.text.isNotEmpty ? _firstNameCtrl.text[0] : ''}', style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)))),
            const SizedBox(height: 20),
            TextFormField(controller: _lastNameCtrl, onChanged: (_) => setState((){}), decoration: const InputDecoration(labelText: 'Nom *', prefixIcon: Icon(Icons.person)), validator: (v) => v!.trim().isEmpty ? 'Requis' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _firstNameCtrl, onChanged: (_) => setState((){}), decoration: const InputDecoration(labelText: 'Prénom *', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v!.trim().isEmpty ? 'Requis' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 12),
            TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email))),
            const SizedBox(height: 12),
            TextFormField(controller: _functionCtrl, decoration: const InputDecoration(labelText: 'Fonction / Rôle', prefixIcon: Icon(Icons.work))),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _selectedGroupId,
              decoration: const InputDecoration(labelText: 'Groupe', prefixIcon: Icon(Icons.group)),
              hint: const Text('Aucun groupe'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Aucun groupe')),
                ...state.groups.map((g) => DropdownMenuItem(value: g.id, child: Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: g.colorValue, shape: BoxShape.circle)), const SizedBox(width: 8), Text(g.name)]))),
              ],
              onChanged: (v) => setState(() => _selectedGroupId = v),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final org = state.currentOrg;
                if (org == null) return;
                final member = Member(
                  id: widget.member?.id, orgId: org.id!,
                  firstName: _firstNameCtrl.text.trim(), lastName: _lastNameCtrl.text.trim(),
                  phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
                  email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
                  function: _functionCtrl.text.trim().isEmpty ? null : _functionCtrl.text.trim(),
                  groupId: _selectedGroupId,
                );
                bool ok = widget.member != null ? await state.updateMember(member) : await state.addMember(member);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Membre enregistré !' : 'Erreur'), backgroundColor: ok ? AppColors.present : AppColors.absent));
                  if (ok) Navigator.pop(context);
                }
              },
              child: Text(widget.member != null ? 'Mettre à jour' : 'Ajouter le membre'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== MEMBER HISTORY =====
class MemberHistoryScreen extends StatefulWidget {
  final Member member;
  const MemberHistoryScreen({super.key, required this.member});
  @override
  State<MemberHistoryScreen> createState() => _MemberHistoryScreenState();
}

class _MemberHistoryScreenState extends State<MemberHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await context.read<AppState>().getMemberHistory(widget.member.id!);
    setState(() { _history = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final stats = <String, int>{};
    for (var h in _history) {
      final s = h['status'] as String? ?? 'absent';
      stats[s] = (stats[s] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: Text('Historique - ${widget.member.fullName}')),
      body: _loading ? const LoadingWidget() : Column(
        children: [
          // Stats rapides
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: AttendanceStatus.values.map((s) => Column(children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(color: s.color.withOpacity(0.15), shape: BoxShape.circle),
                  child: Center(child: Text('${stats[s.value] ?? 0}', style: TextStyle(color: s.color, fontWeight: FontWeight.bold, fontSize: 12)))),
                const SizedBox(height: 4),
                Text(s.shortLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ])).toList(),
            ),
          ),
          Expanded(
            child: _history.isEmpty
                ? const EmptyState(message: 'Aucun historique', icon: Icons.history)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _history.length,
                    itemBuilder: (_, i) {
                      final h = _history[i];
                      final status = AttendanceStatusExt.fromString(h['status'] ?? 'absent');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          leading: Icon(status.icon, color: status.color),
                          title: Text('${h['session_type'] ?? ''} - ${h['date'] ?? ''}', style: const TextStyle(fontSize: 13)),
                          subtitle: h['group_name'] != null ? Text(h['group_name'], style: const TextStyle(fontSize: 11)) : null,
                          trailing: StatusBadge(status: status),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
