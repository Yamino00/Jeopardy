package it.quiz.jeopardy.partita;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = true)
public class StatoPartitaConverter implements AttributeConverter<StatoPartita, String> {

    @Override
    public String convertToDatabaseColumn(StatoPartita attribute) {
        return attribute == null ? null : attribute.dbValue();
    }

    @Override
    public StatoPartita convertToEntityAttribute(String dbData) {
        return dbData == null ? null : StatoPartita.fromDbValue(dbData);
    }
}
