package it.quiz.jeopardy.partita;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = true)
public class TipoEventoConverter implements AttributeConverter<TipoEvento, String> {

    @Override
    public String convertToDatabaseColumn(TipoEvento attribute) {
        return attribute == null ? null : attribute.dbValue();
    }

    @Override
    public TipoEvento convertToEntityAttribute(String dbData) {
        return dbData == null ? null : TipoEvento.fromDbValue(dbData);
    }
}
