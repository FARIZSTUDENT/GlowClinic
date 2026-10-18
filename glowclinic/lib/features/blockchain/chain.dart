import 'package:glowclinic/core/core.dart';

/// Blockchain sederhana: hash = SHA256(index + ts + data + prevHash)
class Chain {
  static String h(int i, String t, String d, String p) => sha('$i$t$d$p');

  static Future<void> add(String data) async {
    final last = await qry('select * from blocks order by idx desc limit 1');

    final i = last.isEmpty ? 0 : (last[0]['idx'] as int) + 1;
    final p = last.isEmpty ? '0' : last[0]['hash'] as String;
    final t = DateTime.now().toUtc().toIso8601String();

    await db.insert('blocks', {
      'idx': i,
      'ts': t,
      'data': data,
      'prev_hash': p,
      'hash': h(i, t, data, p),
    });
  }

  static Future<bool> valid() async {
    final bs = await qry('select * from blocks order by idx');

    for (var k = 0; k < bs.length; k++) {
      final b = bs[k];

      if (b['hash'] !=
          h(
            b['idx'] as int,
            b['ts'] as String,
            b['data'] as String,
            b['prev_hash'] as String,
          )) {
        return false;
      }

      if (k > 0 && b['prev_hash'] != bs[k - 1]['hash']) {
        return false;
      }
    }

    return true;
  }
}
