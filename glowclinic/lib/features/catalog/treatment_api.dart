
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TreatmentApi {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchTreatments() async {
    try {
      final response = await _client
          .from('treatments')
          .select()
          .order('nama');

      final treatments =
          List<Map<String, dynamic>>.from(response);

      // Debug URL foto di terminal Flutter.
      for (final treatment in treatments) {
        debugPrint(
          'Treatment: ${treatment['nama']} | '
          'Foto: ${treatment['foto_url']}',
        );
      }

      return treatments;
    } catch (error, stackTrace) {
      debugPrint('Gagal mengambil treatment: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
