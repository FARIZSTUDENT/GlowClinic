const _envKey1 = String.fromEnvironment('GEMINI_KEY');
const _envKey2 = String.fromEnvironment('GEMINI_API_KEY');
const _envKey3 = String.fromEnvironment('gemini_key');

const kGemini =
    _envKey1 != '' ? _envKey1 : (_envKey2 != '' ? _envKey2 : _envKey3);

const kModel = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: 'gemini-3.5-flash-lite',
);

// ---- Blockchain (Polygon Amoy testnet) ----
// Isi lewat --dart-define-from-file=dart_defines.json (lihat dart_defines.example.json).
// PERINGATAN: kunci privat di dalam aplikasi bisa diekstrak dari APK.
// Pakai wallet testnet khusus demo, jangan wallet berisi uang sungguhan.
const kChainRpc = String.fromEnvironment(
  'CHAIN_RPC',
  defaultValue: 'https://rpc-amoy.polygon.technology',
);
const kChainId = int.fromEnvironment('CHAIN_ID', defaultValue: 80002);
const kChainKey = String.fromEnvironment('CHAIN_PRIVATE_KEY');
const kChainContract = String.fromEnvironment('CHAIN_CONTRACT');
const kChainExplorerTx = String.fromEnvironment(
  'CHAIN_EXPLORER_TX',
  defaultValue: 'https://amoy.polygonscan.com/tx/',
);
