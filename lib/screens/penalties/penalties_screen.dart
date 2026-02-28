import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/common_widgets.dart';

class PenaltiesScreen extends StatefulWidget {
  const PenaltiesScreen({super.key});
  @override
  State<PenaltiesScreen> createState() => _PenaltiesScreenState();
}

class _PenaltiesScreenState extends State<PenaltiesScreen> {
  DateTime _start = DateTime.now().subtract(const Duration(days: 30));
  DateTime _end = DateTime.now();
  int? _groupId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().loadPenaltyConfig());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pénalités'),
        actions: [IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _showConfig)],
      ),
      body: Column(children: [
        // Filtre période
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Expanded(child: _DateBtn(label: 'Du', date: _start, onTap: () => _pick(true))),
              const SizedBox(width: 10),
              Expanded(child: _DateBtn(label: 'Au', date: _end, onTap: () => _pick(false))),
            ]),
            const SizedBox(height: 8),
            Consumer<AppState>(builder: (_, state, __) => DropdownButtonFormField<int?>(
              value: _groupId,
              decoration: const InputDecoration(labelText: 'Groupe', isDense: true),
              hint: const Text('Tous les groupes'),
              items: [const DropdownMenuItem(value: null, child: Text('Tous les groupes')), ...state.groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name)))],
              onChanged: (v) => setState(() => _groupId = v),
            )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              icon: const Icon(Icons.calculate),
              label: const Text('Calculer les pénalités'),
              onPressed: _calculate,
            )),
          ]),
        ),
        Expanded(child: Consumer<AppState>(
          builder: (_, state, __) {
            if (state.isLoading) return const LoadingWidget();
            if (state.penalties.isEmpty) return const EmptyState(message: 'Calculez les pénalités pour une période', icon: Icons.calculate_outlined);
            return Column(children: [
              // Total card
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.statPurple, Color(0xFF9C27B0)]), borderRadius: BorderRadius.circular(16)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Total des pénalités', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text('${state.penalties.length} membres concernés', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ]),
                  Text('${state.totalPenalties.toStringAsFixed(0)} ${state.penaltyConfig.currency}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
              ),
              Expanded(child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: state.penalties.length,
                itemBuilder: (_, i) {
                  final p = state.penalties[i];
                  final total = p['total_penalty'] as double? ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: Container(width: 34, height: 34, decoration: BoxDecoration(color: total > 0 ? AppColors.absent.withOpacity(0.1) : AppColors.present.withOpacity(0.1), shape: BoxShape.circle), child: Center(child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: total > 0 ? AppColors.absent : AppColors.present, fontSize: 12)))),
                      title: Text('${p['last_name']} ${p['first_name']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('${p['absent_count'] ?? 0} abs · ${p['late_count'] ?? 0} retards · ${p['group_name'] ?? 'Sans groupe'}', style: const TextStyle(fontSize: 11)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: total > 0 ? AppColors.absent.withOpacity(0.1) : AppColors.present.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text('${total.toStringAsFixed(0)} ${p['currency'] ?? 'F'}', style: TextStyle(color: total > 0 ? AppColors.absent : AppColors.present, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  );
                },
              )),
            ]);
          },
        )),
      ]),
    );
  }

  Future<void> _pick(bool isStart) async {
    final d = await showDatePicker(context: context, initialDate: isStart ? _start : _end, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() => isStart ? _start = d : _end = d);
  }

  Future<void> _calculate() async {
    await context.read<AppState>().calculatePenalties(
      DateFormat('yyyy-MM-dd').format(_start),
      DateFormat('yyyy-MM-dd').format(_end),
      groupId: _groupId,
    );
  }

  void _showConfig() {
    final config = context.read<AppState>().penaltyConfig;
    final absCtrl = TextEditingController(text: config.absenceAmount.toStringAsFixed(0));
    final lateCtrl = TextEditingController(text: config.lateAmount.toStringAsFixed(0));
    final thCtrl = TextEditingController(text: config.lateThreshold.toString());
    final currCtrl = TextEditingController(text: config.currency);
    bool enabled = config.enabled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Configuration des pénalités', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: absCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pénalité absence', isDense: true))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: lateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pénalité retard', isDense: true))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: thCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seuil retard (min)', isDense: true))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: currCtrl, decoration: const InputDecoration(labelText: 'Devise', isDense: true))),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Activer les pénalités'),
            Switch(value: enabled, onChanged: (v) => setS(() => enabled = v)),
          ]),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final updated = PenaltyConfig(
                absenceAmount: double.tryParse(absCtrl.text) ?? config.absenceAmount,
                lateAmount: double.tryParse(lateCtrl.text) ?? config.lateAmount,
                lateThreshold: int.tryParse(thCtrl.text) ?? config.lateThreshold,
                currency: currCtrl.text.isNotEmpty ? currCtrl.text : config.currency,
                enabled: enabled,
              );
              await context.read<AppState>().updatePenaltyConfig(updated);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ]),
      )),
    );
  }
}

class _DateBtn extends StatelessWidget {
  final String label; final DateTime date; final VoidCallback onTap;
  const _DateBtn({required this.label, required this.date, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
      child: Row(children: [
        const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ]),
    ),
  );
}
