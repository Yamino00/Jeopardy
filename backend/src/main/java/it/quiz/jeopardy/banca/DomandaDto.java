package it.quiz.jeopardy.banca;

/**
 * Read model for a question. Entities never leave the controller layer.
 */
public record DomandaDto(
        Long id,
        String testo,
        String risposta,
        String sottoArgomento,
        short difficolta) {

    public static DomandaDto from(Domanda domanda) {
        return new DomandaDto(
                domanda.getId(),
                domanda.getTesto(),
                domanda.getRisposta(),
                domanda.getSottoArgomento(),
                domanda.getDifficolta());
    }
}
