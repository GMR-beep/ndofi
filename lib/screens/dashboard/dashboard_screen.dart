import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../members/members_screen.dart';
import '../groups/groups_screen.dart';
import '../attendance/attendance_screen.dart';
import '../penalties/penalties_screen.dart';
import '../export/export_screen.dart';
import '../settings/settings_screen.dart';
import '../organizations/organizations_screen.dart';
import '../admin/admin_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _HomeTab(),
      const MembersScreen(),
      const GroupsScreen(),
      const AttendanceScreen(),
      const PenaltiesScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Tableau'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Membres'),
          BottomNavigationBarItem(icon: Icon(Icons.group_outlined), activeIcon: Icon(Icons.group), label: 'Groupes'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist_outlined), activeIcon: Icon(Icons.checklist), label: 'Présences'),
          BottomNavigationBarItem(icon: Icon(Icons.calculate_outlined), activeIcon: Icon(Icons.calculate), label: 'Pénalités'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<AppState>(
          builder: (_, state, __) => OrgSwitcherChip(
            orgName: state.currentOrg?.name ?? 'N\'Dofi',
            orgColor: state.currentOrg?.colorValue ?? Colors.white,
            onTap: () => _showOrgSwitcher(context, state),
          ),
        ),
        actions: [
          Consumer<AppState>(
            builder: (_, state, __) => state.isSuperAdmin
                ? IconButton(
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
                    tooltip: 'Administration',
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportScreen())),
            tooltip: 'Exporter',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            tooltip: 'Paramètres',
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.isLoading) return const LoadingWidget();
          return RefreshIndicator(
            onRefresh: () => state.loadOrgData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte taux présence
                  _PresenceRateCard(state: state),
                  const SizedBox(height: 16),

                  // Stats grid
                  GridView.count(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      StatCard(title: 'Membres actifs', value: '${state.memberCount}', icon: Icons.people, color: AppColors.statBlue),
                      StatCard(title: 'Sessions', value: '${state.sessionCount}', icon: Icons.calendar_today, color: AppColors.statGreen),
                      StatCard(title: 'Absences', value: '${state.absentCount}', icon: Icons.cancel_outlined, color: AppColors.absent),
                      StatCard(title: 'Retards', value: '${state.lateCount}', icon: Icons.access_time, color: AppColors.late),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Graphique
                  if (state.presentCount + state.absentCount + state.lateCount > 0)
                    _PieChart(state: state),
                  const SizedBox(height: 20),

                  // Accès rapides
                  const SectionHeader(title: 'Accès rapides'),
                  const SizedBox(height: 12),
                  _QuickActions(state: state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showOrgSwitcher(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          const Text('Changer d\'organisation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...state.organizations.map((org) => ListTile(
            leading: CircleAvatar(backgroundColor: org.colorValue, child: Text(org.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            title: Text(org.name, style: TextStyle(fontWeight: state.currentOrg?.id == org.id ? FontWeight.bold : FontWeight.normal)),
            subtitle: Text('${org.memberCount ?? 0} membres · ${org.groupCount ?? 0} groupes'),
            trailing: state.currentOrg?.id == org.id ? const Icon(Icons.check, color: AppColors.present) : null,
            onTap: () {
              state.switchOrganization(org);
              Navigator.pop(context);
            },
          )),
          ListTile(
            leading: const CircleAvatar(backgroundColor: AppColors.accent, child: Icon(Icons.add, color: Colors.white)),
            title: const Text('Gérer les organisations'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const OrganizationsScreen()));
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PresenceRateCard extends StatelessWidget {
  final AppState state;
  const _PresenceRateCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final rate = double.tryParse(state.presenceRate.replaceAll('%', '')) ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Taux de présence global', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Text(state.presenceRate, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: rate / 100, backgroundColor: Colors.white30, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), minHeight: 6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.trending_up, size: 64, color: Colors.white30),
        ],
      ),
    );
  }
}

class _PieChart extends StatelessWidget {
  final AppState state;
  const _PieChart({required this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Répartition des présences'),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(PieChartData(
                      sectionsSpace: 2, centerSpaceRadius: 36,
                      sections: [
                        if (state.presentCount > 0) PieChartSectionData(value: state.presentCount.toDouble(), title: '${state.presentCount}', color: AppColors.present, radius: 55, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        if (state.absentCount > 0) PieChartSectionData(value: state.absentCount.toDouble(), title: '${state.absentCount}', color: AppColors.absent, radius: 55, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        if (state.lateCount > 0) PieChartSectionData(value: state.lateCount.toDouble(), title: '${state.lateCount}', color: AppColors.late, radius: 55, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    )),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Legend(color: AppColors.present, label: 'Présents', count: state.presentCount),
                      const SizedBox(height: 8),
                      _Legend(color: AppColors.absent, label: 'Absents', count: state.absentCount),
                      const SizedBox(height: 8),
                      _Legend(color: AppColors.late, label: 'Retards', count: state.lateCount),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color; final String label; final int count;
  const _Legend({required this.color, required this.label, required this.count});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text('$label: $count', style: const TextStyle(fontSize: 12)),
    ]);
  }
}

class _QuickActions extends StatelessWidget {
  final AppState state;
  const _QuickActions({required this.state});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {
        'label': 'Nouvel appel',
        'icon': Icons.add_task,
        'color': AppColors.primary,
        'onTap': () {
          // Navigate to attendance tab and trigger new session
          Navigator.push(context, MaterialPageRoute(builder: (_) => const NewSessionDirectScreen()));
        },
      },
      {
        'label': 'Ajouter membre',
        'icon': Icons.person_add,
        'color': AppColors.accent,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMemberScreen())),
      },
      {
        'label': 'Nouveau groupe',
        'icon': Icons.group_add,
        'color': AppColors.statGreen,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddGroupScreen())),
      },
      {
        'label': 'Exporter',
        'icon': Icons.file_download,
        'color': AppColors.statOrange,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportScreen())),
      },
      {
        'label': 'Pénalités',
        'icon': Icons.calculate,
        'color': AppColors.statPurple,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PenaltiesScreen())),
      },
      {
        'label': 'Organisations',
        'icon': Icons.business,
        'color': AppColors.primaryDark,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrganizationsScreen())),
      },
    ];

    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: actions.map((a) => _QuickActionTile(
        label: a['label'] as String,
        icon: a['icon'] as IconData,
        color: a['color'] as Color,
        onTap: a['onTap'] as VoidCallback,
      )).toList(),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionTile({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.center, maxLines: 2),
          ],
        ),
      ),
    );
  }
}
