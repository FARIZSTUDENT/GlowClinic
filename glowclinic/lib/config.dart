// Masukkan API key saat menjalankan build melalui --dart-define=GEMINI_KEY=...
// Jangan simpan API key di Git atau file yang dibagikan.
const kGemini = String.fromEnvironment('GEMINI_KEY');
const kModel = 'gemini-3.5-flash-lite';