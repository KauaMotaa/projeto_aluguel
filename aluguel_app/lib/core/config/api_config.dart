/// Endereco do backend.
///
/// O valor certo depende de onde o app roda:
///
///   emulador Android  ->  http://10.0.2.2:8000/api/v1
///   celular fisico    ->  http://SEU_IP_NA_REDE:8000/api/v1
///   Chrome / desktop  ->  http://localhost:8000/api/v1
///
/// 10.0.2.2 e o apelido que o emulador do Android usa para falar com a
/// maquina que o hospeda: dentro do emulador, localhost e ele mesmo.
///
/// Para trocar sem mexer no codigo:
///   flutter run --dart-define=API_URL=http://192.168.0.15:8000/api/v1
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
}
