/// Formatadores de exibicao.
///
/// Ficam aqui, e nao no widget, porque quem formata e o ViewModel: a View
/// recebe String pronta. E o que mantem a View burra, que e o ponto do MVVM.
class Formatters {
  const Formatters._();

  /// Centavos para "R$ 1.027,99".
  static String moeda(int centavos) {
    final negativo = centavos < 0;
    final texto = (centavos.abs() / 100).toStringAsFixed(2);
    final partes = texto.split('.');
    final milhar = partes[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}.',
    );
    return '${negativo ? '-' : ''}R\$ $milhar,${partes[1]}';
  }

  /// Centavos para "1.234,56", sem o simbolo. E o que vai dentro de um
  /// campo de digitacao: o "R$" fica no rotulo, nao no texto editavel.
  static String valor(int centavos) => moeda(centavos).replaceFirst(r'R$ ', '');

  /// Inverso de [moeda]: "R$ 1.234,56", "1234,56" e "1234.56" viram 123456.
  ///
  /// O ponto so e descartado quando ha virgula no texto, porque ai ele e
  /// separador de milhar. Sem virgula, quem digita "384.50" quer centavos.
  static int? centavos(String texto) {
    var limpo = texto.replaceAll(RegExp(r'[R$\s]'), '');
    if (limpo.isEmpty) return null;
    if (limpo.contains(',')) {
      limpo = limpo.replaceAll('.', '').replaceAll(',', '.');
    }
    final numero = double.tryParse(limpo);
    if (numero == null) return null;
    return (numero * 100).round();
  }

  /// "2026-11" para "Novembro de 2026".
  static String competencia(String valor) {
    const meses = [
      // "Marco" sem cedilha e outra palavra, e esse nome sai do app na
      // cobranca que o inquilino recebe.
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    final partes = valor.split('-');
    if (partes.length != 2) return valor;
    final mes = int.tryParse(partes[1]);
    if (mes == null || mes < 1 || mes > 12) return valor;
    return '${meses[mes - 1]} de ${partes[0]}';
  }

  /// "2026-11" para "Nov 2026". Serve nas tabelas, onde o nome inteiro do
  /// mes empurra a coluna de valores para fora da tela.
  static String competenciaCurta(String valor) {
    const meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
    ];
    final partes = valor.split('-');
    if (partes.length != 2) return valor;
    final mes = int.tryParse(partes[1]);
    if (mes == null || mes < 1 || mes > 12) return valor;
    return '${meses[mes - 1]} ${partes[0]}';
  }

  /// "2026-11-10" para "10/11/2026".
  static String data(String iso) {
    final partes = iso.split('-');
    if (partes.length != 3) return iso;
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  /// Consumo com a unidade certa: agua com uma casa, energia inteira.
  static String consumo(double valor, String tipo) {
    if (tipo == 'agua') {
      return '${valor.toStringAsFixed(1).replaceAll('.', ',')} m³';
    }
    return '${valor.round()} kWh';
  }

  static String numero(double valor, {int casas = 1}) =>
      valor.toStringAsFixed(casas).replaceAll('.', ',');
}
