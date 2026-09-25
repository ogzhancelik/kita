import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import '../models/match_model.dart';

/// Service responsible for exporting (downloading) and importing (loading)
/// Kita match replays across all supported platforms.
class ReplayFileService {
  ReplayFileService._();
  static final ReplayFileService instance = ReplayFileService._();

  static const String replayFormatIdentifier = 'kita_replay';
  static const int replayFormatVersion = 1;

  /// Serializes a [MatchRecordModel] into the standard Kita Replay JSON structure.
  String serializeReplay(MatchRecordModel match) {
    final payload = {
      'format': replayFormatIdentifier,
      'version': replayFormatVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'match': match.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Parses a replay JSON string into a [MatchRecordModel].
  ///
  /// Supports both standard wrapped Kita replay format and raw match JSON.
  MatchRecordModel parseReplayJson(String content) {
    if (content.trim().isEmpty) {
      throw const FormatException('Empty replay data');
    }

    final dynamic parsed = jsonDecode(content);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Replay JSON must be an object');
    }

    // Support wrapped format: { "format": "kita_replay", "match": { ... } }
    Map<String, dynamic> matchMap;
    if (parsed.containsKey('match') && parsed['match'] is Map<String, dynamic>) {
      matchMap = parsed['match'] as Map<String, dynamic>;
    } else {
      matchMap = parsed;
    }

    // Basic schema verification: must have either moves list or player info
    if (!matchMap.containsKey('moves') && !matchMap.containsKey('white_player_id')) {
      throw const FormatException('File does not contain valid Kita match replay data');
    }

    try {
      return MatchRecordModel.fromJson(matchMap);
    } catch (e) {
      throw FormatException('Failed to parse match replay: $e');
    }
  }

  /// Prompts the user to save/download the match replay file (.kita).
  ///
  /// Returns the saved file path/name if successful, or `null` if cancelled.
  Future<String?> exportReplay(
    MatchRecordModel match, {
    String? dialogTitle,
  }) async {
    try {
      final jsonString = serializeReplay(match);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      // Sanitize username characters for valid file names
      final whiteRaw = match.whitePlayer?.username ?? 'White';
      final blackRaw = match.blackPlayer?.username ?? 'Black';
      final whiteClean = whiteRaw.replaceAll(RegExp(r'[^\w\-]'), '_');
      final blackClean = blackRaw.replaceAll(RegExp(r'[^\w\-]'), '_');
      final idShort = match.id.length > 8 ? match.id.substring(0, 8) : match.id;
      final fileName = 'kita_${whiteClean}_vs_${blackClean}_$idShort.kita';

      final Uri? result = await FilePickerPlatform.instance.saveFile(
        dialogTitle: dialogTitle ?? 'Save Kita Replay',
        fileName: fileName,
        mimeType: 'application/json',
        bytes: bytes,
      );

      if (result == null) {
        // User cancelled the file dialog
        return null;
      }

      final targetPath = result.path.isNotEmpty ? result.toFilePath() : result.toString();

      // On native desktop platforms where saveFile returns path without auto-writing bytes
      if (!kIsWeb && targetPath.isNotEmpty) {
        try {
          final xFile = XFile.fromData(bytes, name: fileName);
          await xFile.saveTo(targetPath);
        } catch (e) {
          debugPrint('[ReplayFileService] saveTo note: $e');
        }
      }

      return targetPath;
    } catch (e) {
      debugPrint('[ReplayFileService] Error exporting replay: $e');
      rethrow;
    }
  }

  /// Opens the system file picker to select and load a `.kita` or `.json` replay file.
  ///
  /// Uses [FileType.any] so that custom extensions like `.kita` are never
  /// disabled or unclickable in browser and OS file dialogs.
  ///
  /// Returns the loaded [MatchRecordModel], or `null` if cancelled.
  Future<MatchRecordModel?> pickAndLoadReplay({String? dialogTitle}) async {
    try {
      final List<PlatformFile>? result = await FilePickerPlatform.instance.pickFiles(
        dialogTitle: dialogTitle ?? 'Select Kita Replay File',
        type: FileType.any,
      );

      if (result == null || result.isEmpty) {
        return null;
      }

      final file = result.single;
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes);

      return parseReplayJson(content);
    } catch (e) {
      debugPrint('[ReplayFileService] Error picking/loading replay: $e');
      rethrow;
    }
  }
}
