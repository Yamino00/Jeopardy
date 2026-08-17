package it.quiz.jeopardy.partita;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = true)
public class EsitoCellaConverter implements AttributeConverter<EsitoCella, String> {

    @Override
    public String convertToDatabaseColumn(EsitoCella attribute) {
        return attribute == null ? null : attribute.dbValue();
    }

    @Override
    public EsitoCella convertToEntityAttribute(String dbData) {
        return dbData == null ? null : EsitoCella.fromDbValue(dbData);
    }
}
