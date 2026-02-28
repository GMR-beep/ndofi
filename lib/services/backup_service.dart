import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/database/database_helper.dart';

class BackupService {
  /// Exporte toutes les données en JSON et ouvre le partage système
  static Future<String?> exportBackup() async {
    try {
      final data = await DatabaseHelper.instance.exportAll();
      final json = const JsonEncoder.withIndent('  ').convert(data);

      final dir = await getApplicationDocumentsDirectory();
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${dir.path}/ndofi_backup_$date.json');
      await file.writeAsString(json, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: "Sauvegarde N'Dofi – $date",
      );
      return null; // null = succès
    } catch (e) {
      debugPrint('Export error: $e');
      return 'Erreur lors de l\'export : $e';
    }
  }

  /// Ouvre le sélecteur de fichier puis restaure les données
  static Future<String?> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return 'Aucun fichier sélectionné';

      final bytes = result.files.single.bytes;
      final path  = result.files.single.path;

      String content;
      if (bytes != null) {
        content = utf8.decode(bytes);
      } else if (path != null) {
        content = await File(path).readAsString();
      } else {
        return 'Impossible de lire le fichier';
      }

      final data = jsonDecode(content);
      if (data is! Map<String, dynamic>) return 'Format de fichier invalide';
      if (data['version'] == null || data['organizations'] == null) {
        return 'Ce fichier n\'est pas une sauvegarde N\'Dofi valide';
      }

      await DatabaseHelper.instance.importAll(data);
      return null; // null = succès
    } catch (e) {
      debugPrint('Import error: $e');
      return 'Erreur lors de la restauration : $e';
    }
  }
}
