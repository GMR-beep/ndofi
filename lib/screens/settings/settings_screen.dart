import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/app_state.dart';
import '../../services/backup_service.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: Consumer<AppState>(builder: (context, state, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Compte
            _Section('Compte', [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (state.currentUser?.username ?? 'A')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(state.currentUser?.username ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(state.currentUser?.roleLabel ?? ''),
              ),
              _Tile(
                icon: Icons.lock,
                title: 'Changer le mot de passe',
                onTap: () => _changePassword(context, state),
              ),
            ]),
            const SizedBox(height: 12),

            // Mode d'appel
            _Section("Mode d'appel", [
              ListTile(
                leading: const Icon(Icons.view_agenda, color: AppColors.primary),
                title: const Text('Mode classique'),
                subtitle: const Text('Expansion par membre avec tous les détails'),
                trailing: Radio<String>(
                  value: 'classic',
                  groupValue: state.attendanceMode,
                  onChanged: (v) => state.setAttendanceMode(v!),
                ),
                onTap: () => state.setAttendanceMode('classic'),
              ),
              ListTile(
                leading: const Icon(Icons.grid_view, color: AppColors.primary),
                title: const Text('Mode compact'),
                subtitle: const Text('Icônes rapides par membre, vue condensée'),
                trailing: Radio<String>(
                  value: 'compact',
                  groupValue: state.attendanceMode,
                  onChanged: (v) => state.setAttendanceMode(v!),
                ),
                onTap: () => state.setAttendanceMode('compact'),
              ),
            ]),
            const SizedBox(height: 12),

            // Apparence
            _Section('Apparence', [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode, color: AppColors.primary),
                title: const Text('Mode sombre'),
                value: state.isDarkMode,
                onChanged: state.setDarkMode,
              ),
            ]),
            const SizedBox(height: 12),

            // Organisation active
            _Section('Organisation active', [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: state.currentOrg?.colorValue ?? AppColors.primary,
                  radius: 16,
                  child: Text(
                    (state.currentOrg?.name ?? 'O')[0],
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                title: Text(
                  state.currentOrg?.name ?? 'Aucune organisation',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('${state.memberCount} membres · ${state.sessionCount} sessions'),
              ),
            ]),
            const SizedBox(height: 12),

            // ── SAUVEGARDE ET RESTAURATION ──
            _Section('Sauvegarde & Restauration', [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.present.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cloud_upload, color: AppColors.present, size: 20),
                ),
                title: const Text('Exporter les données',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Génère un fichier .json à partager\n(Drive, WhatsApp, email…)'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                onTap: () => _doExport(context),
              ),
              const Divider(height: 1, indent: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cloud_download, color: AppColors.primary, size: 20),
                ),
                title: const Text('Restaurer une sauvegarde',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Importe un fichier .json\n⚠ Remplace toutes les données actuelles'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                onTap: () => _doImport(context, state),
              ),
            ]),
            const SizedBox(height: 12),

            // Sécurité
            _Section('Sécurité', [
              _Tile(
                icon: Icons.logout,
                title: 'Se déconnecter',
                iconColor: AppColors.absent,
                onTap: () {
                  state.logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
              ),
            ]),
            const SizedBox(height: 12),

            // À propos
            _Section('À propos', [
              const ListTile(
                leading: Icon(Icons.people_alt, color: AppColors.primary),
                title: Text("N' Dofi",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Gestion intelligente des présences\nVersion 1.1.0'),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.storage, color: AppColors.primary),
                title: Text('Base de données'),
                subtitle: Text('SQLite local — 100% hors ligne\nSauvegarde manuelle via export JSON'),
              ),
            ]),
          ],
        );
      }),
    );
  }

  // ── Export ──
  Future<void> _doExport(BuildContext context) async {
    // Confirmation
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exporter les données'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text(
          'Un fichier ndofi_backup_[date].json va être généré.\n\n'
          'Partagez-le vers Google Drive, WhatsApp ou par email '
          'pour le conserver en sécurité.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exporter'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    // Afficher un loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final error = await BackupService.exportBackup();

    if (!context.mounted) return;
    Navigator.pop(context); // fermer loader

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.absent),
      );
    }
    // Si succès, le partage système s'ouvre tout seul
  }

  // ── Import / Restauration ──
  Future<void> _doImport(BuildContext context, AppState state) async {
    // Avertissement clair
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text('Restaurer une sauvegarde'),
        ]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text(
          'Cette action va REMPLACER toutes les données actuelles '
          'par celles du fichier de sauvegarde.\n\n'
          'Cette opération est irréversible.\n\n'
          'Continuer ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    // Loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final error = await BackupService.importBackup();

    if (!context.mounted) return;
    Navigator.pop(context); // fermer loader

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.absent),
      );
      return;
    }

    // Succès : recharger l'état et rediriger vers login
    await state.reloadAfterRestore();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Données restaurées avec succès !'),
        backgroundColor: AppColors.present,
        duration: Duration(seconds: 3),
      ),
    );

    // Retour au login pour se reconnecter proprement
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _changePassword(BuildContext context, AppState state) {
    final oldCtrl     = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: oldCtrl, obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe actuel')),
          const SizedBox(height: 12),
          TextField(controller: newCtrl, obscureText: true,
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe')),
          const SizedBox(height: 12),
          TextField(controller: confirmCtrl, obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmer le nouveau')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Les mots de passe ne correspondent pas')));
                return;
              }
              final ok = await state.changePassword(oldCtrl.text, newCtrl.text);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Mot de passe modifié !' : 'Mot de passe actuel incorrect'),
                  backgroundColor: ok ? AppColors.present : AppColors.absent,
                ));
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}

// ── Composants réutilisables ──
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(title.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                color: AppColors.primary, letterSpacing: 1.2)),
      ),
      Card(child: Column(children: children)),
    ],
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color iconColor;
  const _Tile({required this.icon, required this.title,
    this.onTap, this.iconColor = AppColors.primary});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: iconColor),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
    onTap: onTap,
  );
}
