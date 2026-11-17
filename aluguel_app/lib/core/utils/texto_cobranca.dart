import '../../data/models/cobranca.dart';
import 'formatters.dart';

/// A cobranca em texto, para o menu de compartilhar do sistema.
///
/// Fica aqui, e nao dentro de um dos dois ViewModels, porque os dois
/// lados mandam o mesmo texto: o dono compartilha a cobranca com o
/// inquilino, e o inquilino guarda o proprio comprovante. Duas copias
/// iriam divergir no primeiro ajuste de redacao.
///
/// É um formatador como o [Formatters], só que de um Model inteiro.
///
/// O texto vai acentuado, ao contrario do resto da interface: "Agua" na
/// tela e um deslize de estilo, "Agua" numa mensagem cobrando alguem e
/// desleixo. E vai mais explicado que a tela, porque numa tela o espaco
/// manda e numa mensagem nao.
class TextoCobranca {
  const TextoCobranca._();

  static String assunto(Cobranca cobranca) =>
      'Cobrança de ${cobranca.identificacao} — '
      '${Formatters.competencia(cobranca.competencia)}';

  static String corpo(Cobranca cobranca) => [
        '${cobranca.identificacao} — '
            '${Formatters.competencia(cobranca.competencia)}',
        '',
        'Aluguel: ${Formatters.moeda(cobranca.valorAluguel)}',
        'Água: ${Formatters.moeda(cobranca.valorAgua)}',
        if (cobranca.detalheAgua != null)
          '  ${_origem(cobranca.detalheAgua!, 'agua')}',
        'Energia: ${Formatters.moeda(cobranca.valorEnergia)}',
        if (cobranca.detalheEnergia != null)
          '  ${_origem(cobranca.detalheEnergia!, 'energia')}',
        'Total: ${Formatters.moeda(cobranca.valorTotal)}',
        '',
        if (cobranca.paga) 'Situação: pago'
        else 'Vence em ${Formatters.data(cobranca.vencimento)}',
        '',
        // A linha que evita a discussão de todo mês: sem ela o inquilino
        // soma a própria leitura, acha menos do que está cobrado, e a
        // conversa começa errada.
        'Água e energia incluem a parte da área comum do ponto, '
            'dividida igualmente entre as unidades ocupadas.',
      ].join('\n');

  static String _origem(DetalheRateio detalhe, String tipo) {
    final seu = Formatters.consumo(detalhe.consumo, tipo);
    final comum = Formatters.consumo(detalhe.rateioComum, tipo);
    final preco = Formatters.moeda(detalhe.valorUnitario.round());
    final unidade = tipo == 'agua' ? 'm³' : 'kWh';
    return '$seu seus e $comum de área comum, a $preco/$unidade';
  }
}
