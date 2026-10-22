const _envKey1 = String.fromEnvironment('GEMINI_KEY');
const _envKey2 = String.fromEnvironment('GEMINI_API_KEY');
const _envKey3 = String.fromEnvironment('gemini_key');

const kGemini =
    _envKey1 != '' ? _envKey1 : (_envKey2 != '' ? _envKey2 : _envKey3);

const kModel = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: 'gemini-3.5-flash-lite',
);
