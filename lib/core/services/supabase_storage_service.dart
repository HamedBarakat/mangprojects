import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> uploadTaskFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final path = 'tasks/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage
        .from('task-attachments')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = _client.storage
        .from('task-attachments')
        .getPublicUrl(path);

    return publicUrl;
  }
}
