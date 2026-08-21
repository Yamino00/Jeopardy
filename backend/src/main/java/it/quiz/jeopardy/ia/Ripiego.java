package it.quiz.jeopardy.ia;

/**
 * Fin dove ci si puo' spingere, pescando dalla banca, quando l'IA non basta.
 *
 * <p>La distinzione non e' un dettaglio implementativo: le due chiamate hanno
 * scopi opposti. Chi crea un tabellone vuole una griglia intera e accetta
 * volentieri una domanda gia' vista pur di non avere un buco. Chi preme
 * "rigenera" sta chiedendo <b>un'altra</b> domanda, e ridargli quella che ha
 * gia' sul tabellone non e' un ripiego: e' non aver fatto niente.
 */
public enum Ripiego {

    /**
     * Solo domande che questo client non ha mai visto, di qualunque fascia.
     * Se non ce ne sono, la richiesta torna a mani vuote e chi ha chiamato
     * decide cosa farne.
     */
    SOLO_NUOVE_PER_IL_CLIENT,

    /**
     * Anche domande gia' viste da questo client, meno usate per prime. Serve
     * al tabellone: una ripetizione si nota, una cella senza domanda e' rotta.
     */
    ANCHE_GIA_VISTE
}
