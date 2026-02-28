import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/common_widgets.dart';

class OrganizationsScreen extends StatefulWidget {
  const OrganizationsScreen({super.key});
  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().loadOrganizations());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organisations')),
      body: Consumer<AppState>(
        builder: (_, state, __) {
          if (state.organizations.isEmpty) {
            return EmptyState(
              message: 'Aucune organisation créée',
              icon: Icons.business_outlined,
              actionLabel: 'Créer une organisation',
              onAction: () => _showOrgDialog(context),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.organizations.length,
            itemBuilder: (_, i) {
              final org = state.organizations[i];
              final isCurrent = state.currentOrg?.id == org.id;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: isCurrent ? Border.all(color: org.colorValue, width: 2) : null,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: org.colorValue,
                      child: Text(org.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Row(
                      children: [
                        Text(org.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.present.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Text('Actif', style: TextStyle(fontSize: 10, color: AppColors.present, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (org.description != null) Text(org.description!, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.people, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('${org.memberCount ?? 0} membres', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(width: 12),
                          const Icon(Icons.group, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('${org.groupCount ?? 0} groupes', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ]),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'select', child: Row(children: [const Icon(Icons.check_circle_outline, size: 18), const SizedBox(width: 8), Text(isCurrent ? 'Organisation active' : 'Sélectionner')])),
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Modifier')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppColors.absent), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.absent))])),
                      ],
                      onSelected: (v) async {
                        if (v == 'select') { await context.read<AppState>().switchOrganization(org); }
                        if (v == 'edit') { _showOrgDialog(context, org: org); }
                        if (v == 'delete') { await _delete(context, org); }
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showOrgDialog(context),
        icon: const Icon(Icons.add_business),
        label: const Text('Nouvelle organisation'),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Organization org) async {
    final confirm = await showConfirmDialog(context,
      title: 'Supprimer l\'organisation',
      message: 'Supprimer "${org.name}" ? TOUS ses membres, groupes et présences seront perdus.',
    );
    if (confirm && mounted) await context.read<AppState>().deleteOrganization(org.id!);
  }

  void _showOrgDialog(BuildContext context, {Organization? org}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _OrgFormSheet(org: org),
    );
  }
}

class _OrgFormSheet extends StatefulWidget {
  final Organization? org;
  const _OrgFormSheet({this.org});
  @override
  State<_OrgFormSheet> createState() => _OrgFormSheetState();
}

class _OrgFormSheetState extends State<_OrgFormSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _color = '#1565C0';
  final _formKey = GlobalKey<FormState>();
  final _colors = ['#1565C0','#2E7D32','#E65100','#6A1B9A','#00838F','#C62828','#37474F','#F9A825','#AD1457','#00695C'];

  @override
  void initState() {
    super.initState();
    if (widget.org != null) {
      _nameCtrl.text = widget.org!.name;
      _descCtrl.text = widget.org!.description ?? '';
      _color = widget.org!.color;
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.org != null ? 'Modifier l\'organisation' : 'Nouvelle organisation',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom *', prefixIcon: Icon(Icons.business)), validator: (v) => v!.trim().isEmpty ? 'Requis' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description))),
            const SizedBox(height: 16),
            const Text('Couleur', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _colors.map((c) {
                final color = Color(int.parse(c.replaceFirst('#', '0xFF')));
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: _color == c ? Border.all(color: Colors.black, width: 3) : null),
                    child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final org = Organization(id: widget.org?.id, name: _nameCtrl.text.trim(), description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(), color: _color);
                final state = context.read<AppState>();
                bool ok;
                if (widget.org != null) { ok = await state.updateOrganization(org); }
                else { ok = await state.addOrganization(org); }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Organisation enregistrée !' : 'Erreur'), backgroundColor: ok ? AppColors.present : AppColors.absent));
                  if (ok) Navigator.pop(context);
                }
              },
              child: Text(widget.org != null ? 'Mettre à jour' : 'Créer'),
            ),
          ],
        ),
      ),
    );
  }
}
