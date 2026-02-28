import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/app_state.dart';
import '../../widgets/common_widgets.dart';
import 'dart:convert';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});
  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  DateTime _start = DateTime.now().subtract(const Duration(days: 30));
  DateTime _end = DateTime.now();
  int? _groupId;
  bool _isLoading = false;

  // Multi-param selection
  Set<String> _statusFilters = {'present', 'absent', 'late', 'permission', 'special', 'particular'};
  bool _includePenalties = false;
  bool _includeStats = true;
  bool _includeSignature = false;

  final Map<String, String> _statusLabels = {
    'present': 'Présents',
    'absent': 'Absents',
    'late': 'Retards',
    'permission': 'Permissions',
    'special': 'Autorisations',
    'particular': 'Cas particuliers',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exporter les données')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Période
          _Section(title: 'Période', child: Row(children: [
            Expanded(child: _DateTile(label: 'Début', date: _start, onTap: () => _pick(true))),
            const SizedBox(width: 12),
            Expanded(child: _DateTile(label: 'Fin', date: _end, onTap: () => _pick(false))),
          ])),
          const SizedBox(height: 12),

          // Groupe
          _Section(title: 'Groupe', child: Consumer<AppState>(
            builder: (_, state, __) => DropdownButtonFormField<int?>(
              value: _groupId,
              decoration: const InputDecoration(isDense: true),
              hint: const Text('Tous les groupes'),
              items: [const DropdownMenuItem(value: null, child: Text('Tous les groupes')), ...state.groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name)))],
              onChanged: (v) => setState(() => _groupId = v),
            ),
          )),
          const SizedBox(height: 12),

          // Statuts à inclure (multi-select)
          _Section(
            title: 'Statuts à inclure',
            action: TextButton(onPressed: () => setState(() => _statusFilters = _statusFilters.length == _statusLabels.length ? {} : Set.from(_statusLabels.keys)), child: Text(_statusFilters.length == _statusLabels.length ? 'Désélectionner tout' : 'Tout sélectionner', style: const TextStyle(fontSize: 12))),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: _statusLabels.entries.map((e) {
                final isSelected = _statusFilters.contains(e.key);
                final color = _getStatusColor(e.key);
                return FilterChip(
                  label: Text(e.value),
                  selected: isSelected,
                  onSelected: (v) => setState(() => v ? _statusFilters.add(e.key) : _statusFilters.remove(e.key)),
                  selectedColor: color.withOpacity(0.2),
                  checkmarkColor: color,
                  labelStyle: TextStyle(color: isSelected ? color : AppColors.textSecondary, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                  side: BorderSide(color: isSelected ? color : Colors.grey[300]!),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Options supplémentaires
          _Section(title: 'Options', child: Column(children: [
            SwitchListTile(dense: true, title: const Text('Inclure les statistiques globales'), value: _includeStats, onChanged: (v) => setState(() => _includeStats = v), contentPadding: EdgeInsets.zero),
            SwitchListTile(dense: true, title: const Text('Inclure le récapitulatif des pénalités'), value: _includePenalties, onChanged: (v) => setState(() => _includePenalties = v), contentPadding: EdgeInsets.zero),
            SwitchListTile(dense: true, title: const Text('Ajouter espace signature/cachet'), value: _includeSignature, onChanged: (v) => setState(() => _includeSignature = v), contentPadding: EdgeInsets.zero),
          ])),
          const SizedBox(height: 24),

          // Boutons
          if (_isLoading) const Center(child: CircularProgressIndicator()) else ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Exporter en PDF', style: TextStyle(fontSize: 15)),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52), backgroundColor: const Color(0xFFD32F2F)),
              onPressed: _exportPdf,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.table_chart, color: Color(0xFF1B5E20)),
              label: const Text('Exporter CSV (Excel)', style: TextStyle(fontSize: 15, color: Color(0xFF1B5E20))),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52), side: const BorderSide(color: Color(0xFF1B5E20), width: 1.5)),
              onPressed: _exportCsv,
            ),
          ],
          const SizedBox(height: 24),

          // Info format Excel
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue[200]!)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Pour importer dans Excel : Données → À partir d\'un fichier texte/CSV → Séparateur : point-virgule → Encodage : UTF-8', style: TextStyle(fontSize: 11, color: Colors.blue))),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(bool isStart) async {
    final d = await showDatePicker(context: context, initialDate: isStart ? _start : _end, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() => isStart ? _start = d : _end = d);
  }

  Color _getStatusColor(String s) {
    const map = {'present': AppColors.present, 'absent': AppColors.absent, 'late': AppColors.late, 'permission': AppColors.permission, 'special': AppColors.special, 'particular': AppColors.particular};
    return map[s] ?? AppColors.textSecondary;
  }

  Future<List<Map<String, dynamic>>> _getData() async {
    final state = context.read<AppState>();
    final start = DateFormat('yyyy-MM-dd').format(_start);
    final end = DateFormat('yyyy-MM-dd').format(_end);
    final all = await state.getAttendanceByPeriod(start, end, groupId: _groupId);
    return all.where((r) => _statusFilters.contains(r['status'])).toList();
  }

  Future<void> _exportPdf() async {
    setState(() => _isLoading = true);
    try {
      final state = context.read<AppState>();
      final data = await _getData();
      final orgName = state.currentOrg?.name ?? 'N\'Dofi';
      final dateRange = '${DateFormat('dd/MM/yyyy').format(_start)} - ${DateFormat('dd/MM/yyyy').format(_end)}';

      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(orgName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Rapport de présences', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            ]),
            pw.Text(dateRange, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
          ]),
          pw.Divider(color: PdfColors.blueAccent),
          pw.SizedBox(height: 8),
        ]),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          if (_includeStats && data.isNotEmpty) {
            final presentCount = data.where((d) => d['status'] == 'present').length;
            final absentCount = data.where((d) => ['absent', 'permission'].contains(d['status'])).length;
            final lateCount = data.where((d) => d['status'] == 'late').length;
            widgets.add(pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                pw.Column(children: [pw.Text('$presentCount', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)), pw.Text('Présents', style: const pw.TextStyle(fontSize: 10))]),
                pw.Column(children: [pw.Text('$absentCount', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)), pw.Text('Absents', style: const pw.TextStyle(fontSize: 10))]),
                pw.Column(children: [pw.Text('$lateCount', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)), pw.Text('Retards', style: const pw.TextStyle(fontSize: 10))]),
              ]),
            ));
            widgets.add(pw.SizedBox(height: 16));
          }

          if (data.isNotEmpty) {
            widgets.add(pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1.5), 2: const pw.FlexColumnWidth(1.5), 3: const pw.FlexColumnWidth(1)},
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: ['Membre', 'Groupe', 'Date / Session', 'Statut'].map((h) => pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)))).toList(),
                ),
                ...data.asMap().entries.map((e) {
                  final r = e.value;
                  final bg = e.key % 2 == 0 ? PdfColors.white : PdfColors.grey100;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${r['last_name']} ${r['first_name']}', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(r['group_name'] ?? '-', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${r['session_type'] ?? ''}\n${r['date'] ?? ''}', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_translateStatus(r['status'] ?? ''), style: const pw.TextStyle(fontSize: 9))),
                    ],
                  );
                }),
              ],
            ));
          } else {
            widgets.add(pw.Center(child: pw.Text('Aucune donnée pour les critères sélectionnés')));
          }

          if (_includeSignature) {
            widgets.add(pw.SizedBox(height: 40));
            widgets.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(children: [pw.Container(width: 120, height: 60, decoration: pw.BoxDecoration(border: pw.Border.all())), pw.SizedBox(height: 4), pw.Text('Signature', style: const pw.TextStyle(fontSize: 10))]),
              pw.Column(children: [pw.Container(width: 120, height: 60, decoration: pw.BoxDecoration(border: pw.Border.all())), pw.SizedBox(height: 4), pw.Text('Cachet', style: const pw.TextStyle(fontSize: 10))]),
            ]));
          }

          return widgets;
        },
      ));

      await Printing.layoutPdf(onLayout: (_) async => doc.save());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.absent));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _exportCsv() async {
    setState(() => _isLoading = true);
    try {
      final state = context.read<AppState>();
      final data = await _getData();
      final orgName = state.currentOrg?.name ?? 'N\'Dofi';

      final lines = [
        'Rapport N\'Dofi - $orgName',
        'Période: ${DateFormat('dd/MM/yyyy').format(_start)} - ${DateFormat('dd/MM/yyyy').format(_end)}',
        'Généré le: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        '',
        'Nom;Prénom;Groupe;Fonction;Date;Type de session;Statut;Retard (min);Commentaire',
        ...data.map((r) =>
          '${r['last_name']};${r['first_name']};${r['group_name'] ?? ''};${r['function'] ?? ''};${r['date']};${r['session_type'] ?? ''};${_translateStatus(r['status'] ?? '')};${r['late_minutes'] ?? 0};${r['comment'] ?? ''}'),
      ];

      if (_includePenalties) {
        await state.calculatePenalties(DateFormat('yyyy-MM-dd').format(_start), DateFormat('yyyy-MM-dd').format(_end), groupId: _groupId);
        lines.addAll(['', '', '--- RÉCAPITULATIF PÉNALITÉS ---', 'Nom;Prénom;Groupe;Absences;Retards;Total']);
        for (var p in state.penalties) {
          lines.add('${p['last_name']};${p['first_name']};${p['group_name'] ?? ''};${p['absent_count'] ?? 0};${p['late_count'] ?? 0};${(p['total_penalty'] as double? ?? 0).toStringAsFixed(0)} ${p['currency'] ?? 'F'}');
        }
      }

      final dir = await getTemporaryDirectory();
final file = File('${dir.path}/ndofi_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv');
// Avant : await file.writeAsString(lines.join('\n'), encoding: const Utf8Codec());
// Après correction :

// puis
      await file.writeAsString(lines.join('\n'), encoding: utf8);
      await Share.shareXFiles([XFile(file.path)], text: 'Export N\'Dofi - $orgName');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.absent));
    }
    setState(() => _isLoading = false);
  }

  String _translateStatus(String s) {
    const map = {'present': 'Présent', 'absent': 'Absent', 'late': 'Retard', 'permission': 'Permission', 'special': 'Autorisation', 'particular': 'Cas particulier'};
    return map[s] ?? s;
  }
}

class _Section extends StatelessWidget {
  final String title; final Widget child; final Widget? action;
  const _Section({required this.title, required this.child, this.action});
  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        if (action != null) action!,
      ]),
      const SizedBox(height: 10),
      child,
    ])));
  }
}

class _DateTile extends StatelessWidget {
  final String label; final DateTime date; final VoidCallback onTap;
  const _DateTile({required this.label, required this.date, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Row(children: [const Icon(Icons.calendar_today, size: 13, color: AppColors.primary), const SizedBox(width: 6), Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))]),
      ]),
    ),
  );
}
