import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/common_widgets.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      state.loadUsers();
      state.loadActivityLog();
    });
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: 'Utilisateurs'), Tab(text: 'Journal d\'activité')],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_UsersTab(), _ActivityLogTab()],
      ),
      floatingActionButton: _tabCtrl.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showUserForm(context),
              icon: const Icon(Icons.person_add),
              label: const Text('Nouvel utilisateur'),
            )
          : null,
    );
  }

  void _showUserForm(BuildContext context, {AppUser? user}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _UserFormSheet(user: user),
    );
  }
}

class _UsersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, state, _) {
      if (state.users.isEmpty) return const LoadingWidget();
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.users.length,
        itemBuilder: (_, i) {
          final u = state.users[i];
          final isSelf = u.id == state.currentUser?.id;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: u.isSuperAdmin ? AppColors.adminGold : u.isAdmin ? AppColors.primary : AppColors.textSecondary,
                    child: Text(u.username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  if (u.isBlocked)
                    Positioned(right: 0, bottom: 0, child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: AppColors.absent, shape: BoxShape.circle), child: const Icon(Icons.block, size: 10, color: Colors.white))),
                ],
              ),
              title: Row(children: [
                Text(u.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                _RoleChip(role: u.role),
                if (isSelf) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Text('Vous', style: TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.bold)))],
              ]),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (u.isBlocked) const Text('⛔ Compte bloqué', style: TextStyle(color: AppColors.absent, fontSize: 11, fontWeight: FontWeight.w600)),
                if (u.lastLogin != null) Text('Dernière connexion: ${_fmt(u.lastLogin!)}', style: const TextStyle(fontSize: 11)),
              ]),
              trailing: isSelf ? null : PopupMenuButton(
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'block', child: Row(children: [
                    Icon(u.isBlocked ? Icons.lock_open : Icons.block, size: 18, color: u.isBlocked ? AppColors.present : AppColors.absent),
                    const SizedBox(width: 8),
                    Text(u.isBlocked ? 'Débloquer' : 'Bloquer', style: TextStyle(color: u.isBlocked ? AppColors.present : AppColors.absent)),
                  ])),
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Modifier')])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppColors.absent), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.absent))])),
                ],
                onSelected: (v) async {
                  final state = context.read<AppState>();
                  if (v == 'block') await state.blockUser(u.id!, !u.isBlocked);
                  if (v == 'edit') {
                    // Show edit form
                    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => _UserFormSheet(user: u));
                  }
                  if (v == 'delete') {
                    final ok = await showConfirmDialog(context, title: 'Supprimer l\'utilisateur', message: 'Supprimer ${u.username} ?');
                    if (ok) await state.deleteUser(u.id!);
                  }
                },
              ),
            ),
          );
        },
      );
    });
  }

  String _fmt(String dt) {
    try { return dt.substring(0, 16).replaceAll('T', ' '); } catch (_) { return dt; }
  }
}

class _ActivityLogTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (_, state, __) {
      if (state.activityLog.isEmpty) return const EmptyState(message: 'Aucune activité enregistrée', icon: Icons.history);
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: state.activityLog.length,
        itemBuilder: (_, i) {
          final log = state.activityLog[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: _ActionIcon(action: log['action'] ?? ''),
              title: Text('${log['username'] ?? 'Système'} · ${log['action'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (log['details'] != null) Text(log['details'], style: const TextStyle(fontSize: 11)),
                Row(children: [
                  if (log['org_name'] != null) ...[const Icon(Icons.business, size: 10, color: AppColors.textSecondary), const SizedBox(width: 4), Text(log['org_name'], style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)), const SizedBox(width: 8)],
                  const Icon(Icons.access_time, size: 10, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(_fmt(log['created_at'] ?? ''), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ]),
              ]),
            ),
          );
        },
      );
    });
  }

  String _fmt(String dt) {
    try { return dt.substring(0, 16).replaceAll('T', ' '); } catch (_) { return dt; }
  }
}

class _ActionIcon extends StatelessWidget {
  final String action;
  const _ActionIcon({required this.action});
  @override
  Widget build(BuildContext context) {
    IconData icon; Color color;
    if (action.contains('LOGIN')) { icon = Icons.login; color = AppColors.present; }
    else if (action.contains('ADD')) { icon = Icons.add_circle; color = AppColors.primary; }
    else if (action.contains('DELETE')) { icon = Icons.delete; color = AppColors.absent; }
    else if (action.contains('BLOCK')) { icon = Icons.block; color = AppColors.absent; }
    else if (action.contains('SAVE')) { icon = Icons.save; color = AppColors.statGreen; }
    else if (action.contains('IMPORT')) { icon = Icons.upload_file; color = AppColors.accent; }
    else { icon = Icons.info; color = AppColors.textSecondary; }
    return Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 16, color: color));
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});
  @override
  Widget build(BuildContext context) {
    Color color; String label;
    if (role == 'superadmin') { color = AppColors.adminGold; label = 'Super Admin'; }
    else if (role == 'admin') { color = AppColors.primary; label = 'Admin'; }
    else { color = AppColors.textSecondary; label = 'Utilisateur'; }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.4))), child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)));
  }
}

class _UserFormSheet extends StatefulWidget {
  final AppUser? user;
  const _UserFormSheet({this.user});
  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = 'user';
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.user != null) { _userCtrl.text = widget.user!.username; _role = widget.user!.role; }
  }
  @override
  void dispose() { _userCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.user != null ? 'Modifier l\'utilisateur' : 'Nouvel utilisateur', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'Identifiant *', prefixIcon: Icon(Icons.person)), validator: (v) => v!.trim().isEmpty ? 'Requis' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _passCtrl, obscureText: true, decoration: InputDecoration(labelText: widget.user != null ? 'Nouveau mot de passe (laisser vide)' : 'Mot de passe *', prefixIcon: const Icon(Icons.lock)), validator: (v) => widget.user == null && v!.trim().isEmpty ? 'Requis' : null),
          const SizedBox(height: 12),
          const Text('Rôle', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(children: [
            _RoleBtn(label: 'Utilisateur', value: 'user', selected: _role, onTap: () => setState(() => _role = 'user')),
            const SizedBox(width: 8),
            _RoleBtn(label: 'Admin', value: 'admin', selected: _role, onTap: () => setState(() => _role = 'admin')),
          ]),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              final state = context.read<AppState>();
              bool ok;
              if (widget.user != null) {
                final updated = AppUser(id: widget.user!.id, username: _userCtrl.text.trim(), password: _passCtrl.text.isNotEmpty ? _passCtrl.text : widget.user!.password, role: _role, isBlocked: widget.user!.isBlocked, orgPermissions: widget.user!.orgPermissions);
                ok = await state.updateUser(updated);
              } else {
                final user = AppUser(username: _userCtrl.text.trim(), password: _passCtrl.text, role: _role);
                ok = await state.addUser(user);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Utilisateur enregistré !' : 'Erreur (identifiant déjà pris ?)'), backgroundColor: ok ? AppColors.present : AppColors.absent));
                if (ok) Navigator.pop(context);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ]),
      ),
    );
  }
}

class _RoleBtn extends StatelessWidget {
  final String label, value, selected;
  final VoidCallback onTap;
  const _RoleBtn({required this.label, required this.value, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary, width: isSelected ? 2 : 1)),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.primary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}
