import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/common_widgets.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().loadGroups());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groupes')),
      body: Consumer<AppState>(
        builder: (_, state, __) {
          if (state.groups.isEmpty) {
            return EmptyState(message: 'Aucun groupe créé', icon: Icons.group_outlined,
                actionLabel: 'Créer un groupe', onAction: () => _showForm(context));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.groups.length,
            itemBuilder: (_, i) {
              final g = state.groups[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border(left: BorderSide(color: g.colorValue, width: 4)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(backgroundColor: g.colorValue.withOpacity(0.2), child: Text(g.name[0].toUpperCase(), style: TextStyle(color: g.colorValue, fontWeight: FontWeight.bold))),
                    title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (g.description != null) Text(g.description!, style: const TextStyle(fontSize: 12)),
                      Row(children: [
                        const Icon(Icons.people, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('${g.memberCount ?? 0} membres actifs', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ]),
                    ]),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showForm(context, group: g)),
                      IconButton(icon: const Icon(Icons.delete, size: 20, color: AppColors.absent), onPressed: () => _delete(context, g)),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context),
        icon: const Icon(Icons.group_add),
        label: const Text('Nouveau groupe'),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Group g) async {
    final ok = await showConfirmDialog(context, title: 'Supprimer le groupe', message: 'Les membres seront conservés mais sans groupe.');
    if (ok && mounted) await context.read<AppState>().deleteGroup(g.id!);
  }

  void _showForm(BuildContext context, {Group? group}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _GroupFormSheet(group: group),
    );
  }
}

// ===== ADD GROUP SCREEN (standalone for quick action) =====
class AddGroupScreen extends StatelessWidget {
  const AddGroupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau groupe')),
      body: const _GroupFormSheet(standalone: true),
    );
  }
}

class _GroupFormSheet extends StatefulWidget {
  final Group? group;
  final bool standalone;
  const _GroupFormSheet({this.group, this.standalone = false});
  @override
  State<_GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends State<_GroupFormSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _color = '#1565C0';
  final _formKey = GlobalKey<FormState>();
  final _colors = ['#1565C0','#2E7D32','#E65100','#6A1B9A','#00838F','#C62828','#37474F','#F9A825','#AD1457','#00695C'];

  @override
  void initState() {
    super.initState();
    if (widget.group != null) { _nameCtrl.text = widget.group!.name; _descCtrl.text = widget.group!.description ?? ''; _color = widget.group!.color; }
  }
  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Widget _buildContent(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.standalone) ...[
            Text(widget.group != null ? 'Modifier le groupe' : 'Nouveau groupe', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
          ],
          TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom du groupe *'), validator: (v) => v!.trim().isEmpty ? 'Requis' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 16),
          const Text('Couleur', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _colors.map((c) {
            final color = Color(int.parse(c.replaceFirst('#', '0xFF')));
            return GestureDetector(
              onTap: () => setState(() => _color = c),
              child: Container(width: 36, height: 36, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: _color == c ? Border.all(color: Colors.black, width: 3) : null), child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 18) : null),
            );
          }).toList()),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              final state = context.read<AppState>();
              if (state.currentOrg == null) return;
              final group = Group(id: widget.group?.id, orgId: state.currentOrg!.id!, name: _nameCtrl.text.trim(), description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(), color: _color);
              bool ok = widget.group != null ? await state.updateGroup(group) : await state.addGroup(group);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Groupe enregistré !' : 'Erreur'), backgroundColor: ok ? AppColors.present : AppColors.absent));
                if (ok) Navigator.pop(context);
              }
            },
            child: Text(widget.group != null ? 'Mettre à jour' : 'Créer le groupe'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.standalone) {
      return ListView(padding: const EdgeInsets.all(24), children: [_buildContent(context)]);
    }
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: _buildContent(context),
    );
  }
}
