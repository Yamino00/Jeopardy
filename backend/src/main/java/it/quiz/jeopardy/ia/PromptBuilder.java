package it.quiz.jeopardy.ia;

import java.util.stream.Collectors;

/**
 * The prompt, shared by every provider so that the questions do not change
 * shape depending on which backend served the request.
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
        sb.append(".\n\n");

        if (request.richieste().size() == 1) {
            sb.append("Tutte con difficolta ")
                    .append(request.richieste().get(0).difficolta())
                    .append(" su una scala da 1 (facile) a 5 (difficile).\n\n");
        } else {
            sb.append("Distribuzione richiesta, su una scala da 1 (facile) a 5 (difficile):\n")
                    .append(request.richieste().stream()
                            .map(q -> "- " + q.quantita() + " di difficolta " + q.difficolta())
                            .collect(Collectors.joining("\n")))
                    .append("\n\n");
        }

        sb.append("Rispondi SOLO con JSON valido, con questo schema esatto:\n")
                .append("{\"domande\":[{\"testo\":\"...\",\"risposta\":\"...\",")
                .append("\"entita_canonica\":\"...\",\"sotto_argomento\":\"...\",")
                .append("\"difficolta\":1}]}\n\n")
                .append("Regole:\n")
                // Senza questo vincolo il modello risponde "Chi e Annibale?" e la
                // entita_canonica calcolata in Java diventa "chi e annibale",
                // rendendo inefficace la deduplicazione
                .append("- \"risposta\" deve contenere SOLO il nome dell'entita, ")
                .append("mai una frase interrogativa: \"Annibale\", non \"Chi e Annibale?\".\n")
                .append("- \"testo\" e la domanda o l'indizio mostrato ai giocatori.\n")
                .append("- \"entita_canonica\" e la risposta normalizzata: minuscola, senza accenti, ")
                .append("senza articoli iniziali, senza contenuto fra parentesi.\n")
                .append("- \"difficolta\" deve riportare la fascia della domanda, ")
                .append("rispettando la distribuzione richiesta.\n")
                .append("- Ogni domanda deve avere una risposta diversa dalle altre.\n")
                .append("- Sii conciso: il testo non deve superare le 40 parole.\n");
        if (!request.blocklist().isEmpty()) {
            sb.append("- NON generare domande la cui risposta normalizzata sia una di queste ")
                    .append("(gia presenti in banca): ")
                    .append(String.join(", ", request.blocklist()))
                    .append('\n');
        }
        return sb.toString();
    }
}
