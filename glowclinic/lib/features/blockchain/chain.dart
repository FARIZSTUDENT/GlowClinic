import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:glowclinic/config.dart';
import 'package:glowclinic/core/core.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

/// Hasil verifikasi gabungan (lokal + blockchain publik).
class ChainReport {
  const ChainReport({
    required this.localValid,
    required this.total,
    required this.anchored,
    required this.pending,
    required this.missing,
    this.error,
  });

  /// Hash-chain lokal tidak rusak.
  final bool localValid;

  /// Jumlah blok lokal.
  final int total;

  /// Blok yang terbukti ada di blockchain publik.
  final int anchored;

  /// Blok yang belum berhasil dikirim ke blockchain (offline / gagal).
  final int pending;

  /// Blok yang tercatat terkirim tetapi TIDAK ditemukan di blockchain.
  final int missing;

  /// Pesan error bila blockchain tidak bisa dihubungi.
  final String? error;

  bool get ok => localValid && missing == 0 && error == null;
}

/// Blockchain GlowClinic.
///
/// Dua lapis:
/// 1. Hash-chain lokal (SQLite): hash = SHA256(index + ts + data + prevHash).
///    Berguna sebagai log audit offline.
/// 2. Anchoring ke blockchain publik (smart contract `GlowRegistry`, mis. di
///    Polygon Amoy). Hash blok dikirim langsung dari aplikasi lewat web3dart
///    (kunci wallet testnet diisi via --dart-define). Karena hash blok memuat
///    `prevHash`, satu hash on-chain mengunci seluruh riwayat sebelumnya.
///    Data asli tidak pernah dikirim ke chain, hanya hash-nya.
class Chain {
  static const _abi = '['
      '{"type":"function","name":"anchor","stateMutability":"nonpayable",'
      '"inputs":[{"name":"hash","type":"bytes32"},{"name":"kind","type":"string"}],"outputs":[]},'
      '{"type":"function","name":"verify","stateMutability":"view",'
      '"inputs":[{"name":"hash","type":"bytes32"}],'
      '"outputs":[{"name":"","type":"uint256"}]}]';

  static bool get configured => kChainKey.isNotEmpty && kChainContract.isNotEmpty;

  static Web3Client? _client;
  static DeployedContract? _contract;
  // Kirim transaksi satu per satu supaya nonce tidak bentrok.
  static Future<void> _queue = Future.value();

  static Web3Client get _web3 => _client ??= Web3Client(kChainRpc, http.Client());

  static DeployedContract get _reg => _contract ??= DeployedContract(
        ContractAbi.fromJson(_abi, 'GlowRegistry'),
        EthereumAddress.fromHex(kChainContract),
      );

  static Uint8List _b32(String hexHash) => hexToBytes(hexHash);

  static Future<BigInt> _anchoredAt(String hash) async {
    final r = await _web3.call(
      contract: _reg,
      function: _reg.function('verify'),
      params: [_b32(hash)],
    );
    return r.first as BigInt;
  }

  static const _kinds = {'booking', 'payment', 'treatment', 'spin'};

  static String h(int i, String t, String d, String p) => sha('$i$t$d$p');

  static bool _tableReady = false;

  static Future<void> _ensureTable() async {
    if (_tableReady) return;
    await db.execute(
      'create table if not exists chain_anchors('
      'hash text primary key, kind text, status text not null default \'pending\', '
      'tx_hash text, created_at text)',
    );
    _tableReady = true;
  }

  static String _kind(String data) {
    final k = data.split(':').first;
    if (k == 'booking' && data.contains('Treatment selesai')) return 'treatment';
    return _kinds.contains(k) ? k : 'other';
  }

  /// Tambah blok lokal, lalu kirim hash-nya ke blockchain di latar belakang.
  /// Kegagalan jaringan TIDAK melempar error: blok ditandai `pending` dan
  /// dicoba lagi lewat [syncPending].
  static Future<void> add(String data) async {
    await _ensureTable();
    final last = await qry('select * from blocks order by idx desc limit 1');

    final i = last.isEmpty ? 0 : (last[0]['idx'] as int) + 1;
    final p = last.isEmpty ? '0' : last[0]['hash'] as String;
    final t = DateTime.now().toUtc().toIso8601String();
    final hash = h(i, t, data, p);

    await db.insert('blocks', {
      'idx': i,
      'ts': t,
      'data': data,
      'prev_hash': p,
      'hash': hash,
    });

    final kind = _kind(data);
    await db.insert('chain_anchors', {
      'hash': hash,
      'kind': kind,
      'status': 'pending',
      'created_at': t,
    });

    unawaited(_anchor(hash, kind));
  }

  static Future<bool> _anchor(String hash, String kind) {
    final run = _queue.then((_) => _anchorNow(hash, kind));
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  static Future<bool> _anchorNow(String hash, String kind) async {
    if (!configured) return false;
    try {
      String? txHash;
      // Idempotent: kalau hash sudah ada di chain, tidak perlu bayar gas lagi.
      if ((await _anchoredAt(hash)) == BigInt.zero) {
        txHash = await _web3
            .sendTransaction(
              EthPrivateKey.fromHex(kChainKey),
              Transaction.callContract(
                contract: _reg,
                function: _reg.function('anchor'),
                parameters: [_b32(hash), kind],
              ),
              chainId: kChainId,
            )
            .timeout(const Duration(seconds: 60));
      }
      await db.update(
        'chain_anchors',
        {'status': 'anchored', 'tx_hash': txHash},
        where: 'hash = ?',
        whereArgs: [hash],
      );
      return true;
    } catch (e) {
      debugPrint('[CHAIN] anchor gagal (akan dicoba lagi): $e');
      return false;
    }
  }

  /// Coba kirim ulang semua blok yang masih `pending`.
  static Future<void> syncPending() async {
    await _ensureTable();
    final rows = await qry(
      "select hash, kind from chain_anchors where status = 'pending' "
      'order by created_at limit 20',
    );
    for (final r in rows) {
      await _anchor(r['hash'] as String, (r['kind'] ?? 'other') as String);
    }
  }

  /// Verifikasi hash-chain lokal saja (tidak butuh internet).
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

  /// Verifikasi lengkap: hash-chain lokal + keberadaan tiap hash di blockchain.
  static Future<ChainReport> verifyOnChain() async {
    await _ensureTable();
    final localOk = await valid();
    await syncPending();

    final total =
        (await qry('select count(*) c from blocks')).first['c'] as int;
    final pending = (await qry(
      "select count(*) c from chain_anchors where status = 'pending'",
    )).first['c'] as int;

    final rows = await qry(
      "select hash from chain_anchors where status = 'anchored'",
    );
    final hashes = rows.map((r) => r['hash'] as String).toList();

    if (!configured) {
      return ChainReport(
        localValid: localOk,
        total: total,
        anchored: 0,
        pending: pending,
        missing: 0,
        error: 'Blockchain belum dikonfigurasi (CHAIN_PRIVATE_KEY / CHAIN_CONTRACT).',
      );
    }

    var found = 0;
    try {
      for (final hash in hashes) {
        if ((await _anchoredAt(hash)) > BigInt.zero) found++;
      }
    } catch (e) {
      return ChainReport(
        localValid: localOk,
        total: total,
        anchored: found,
        pending: pending,
        missing: 0,
        error: 'Tidak bisa menghubungi blockchain.',
      );
    }

    return ChainReport(
      localValid: localOk,
      total: total,
      anchored: found,
      pending: pending,
      missing: hashes.length - found,
    );
  }
}
