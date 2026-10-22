// Masukkan API key saat menjalankan build/run melalui:
// flutter run --dart-define=GEMINI_KEY=YOUR_GEMINI_API_KEY
// Jangan simpan API key rahasia langsung di dalam source code repository.

const _envKey1 = String.fromEnvironment('GEMINI_KEY');
const _envKey2 = String.fromEnvironment('GEMINI_API_KEY');
const _envKey3 = String.fromEnvironment('gemini_key');

/// Gemini API Key yang dibaca dari environment variable saat build / run:
/// flutter run --dart-define=GEMINI_KEY=AIzaSy...
const kGemini = _envKey1 != ''
    ? _envKey1
    : (_envKey2 != '' ? _envKey2 : _envKey3);

/// Model Gemini yang didukung resmi oleh Google Gemini API (v1beta & v1).
/// Model default yang digunakan adalah 'gemini-1.5-flash' (cepat, stabil, dan hemat kuota).
/// Dapat di-override melalui --dart-define=GEMINI_MODEL=gemini-2.0-flash jika diperlukan.
const kModel = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: 'gemini-1.5-flash',
);