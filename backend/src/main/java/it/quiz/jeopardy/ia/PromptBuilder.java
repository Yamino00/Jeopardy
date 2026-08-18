package it.quiz.jeopardy.ia;

/**
 * The single-cell prompt, shared by every provider so that the questions do
 * not change shape depending on which backend served the request.
 */
final class PromptBuilder {

    private PromptBuilder() {
    }

    static String build(GenerationRequest request) {
        StringBuilder sb = new StringBuilder();
        sb.append("Genera esattamente ").append(request.numero())
                .append(" domande di quiz in italiano, stile Jeopardy, sull'argomento \"")
                .append(request.argomento()).append('"');
        if (request.sottoArgomento() != null && !request.sottoArgomento().isBlank()) {
            sb.append(", sotto-argomento \"").append(request.sottoArgomento()).append('"');
        }
        sb.append(", con difficolta ").append(request.difficolta())
                .append(" su una scala da 1 (facile) a 5 (difficile).\n\n")
                .append("Rispondi SOLO con JSON valido, con questo schema esatto:\n")
                .append("{\"domande\":[{\"testo\":\"...\",\"risposta\":\"...\",")
                .append("\"entita_canonica\":\"...\",\"sotto_argomento\":\"...\",\"difficolta\":")
                .append(request.difficolta()).append("}]}\n\n")
                .append("Regole:\n")
                // Senza questo vincolo il modello risponde "Chi e Annibale?" e la
                // entita_canonica calcolata in Java diventa "chi e annibale",
                // rendendo inefficace la deduplicazione
                .append("- \"risposta\" deve contenere SOLO il nome dell'entita, ")
                .append("mai una frase interrogativa: \"Annibale\", non \"Chi e Annibale?\".\n")
                .append("- \"testo\" e la domanda o l'indizio mostrato ai giocatori.\n")
                .append("- \"entita_canonica\" e la risposta normalizzata: minuscola, senza accenti, ")
                .append("senza articoli iniziali, senza contenuto fra parentesi.\n")
                .append("- Ogni domanda deve avere una risposta diversa dalle altre.\n");
        if (!request.blocklist().isEmpty()) {
            sb.append("- NON generare domande la cui risposta normalizzata sia una di queste ")
                    .append("(gia presenti in banca): ")
                    .append(String.join(", ", request.blocklist()))
                    .append('\n');
        }
        return sb.toString();
    }
}
