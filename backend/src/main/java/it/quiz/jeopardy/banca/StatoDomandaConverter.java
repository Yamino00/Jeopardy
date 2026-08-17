package it.quiz.jeopardy.banca;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/**
 * Maps {@link StatoDomanda} to the lowercase values expected by the
 * CHECK constraint on {@code domanda.stato}.
 */
@Converter(autoApply = true)
public class StatoDomandaConverter implements AttributeConverter<StatoDomanda, String> {

    @Override
    public String convertToDatabaseColumn(StatoDomanda attribute) {
        return attribute == null ? null : attribute.dbValue();
    }

    @Override
    public StatoDomanda convertToEntityAttribute(String dbData) {
        return dbData == null ? null : StatoDomanda.fromDbValue(dbData);
    }
}
