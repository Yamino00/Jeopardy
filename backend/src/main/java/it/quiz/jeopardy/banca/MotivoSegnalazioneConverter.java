package it.quiz.jeopardy.banca;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = true)
public class MotivoSegnalazioneConverter implements AttributeConverter<MotivoSegnalazione, String> {

    @Override
    public String convertToDatabaseColumn(MotivoSegnalazione attribute) {
        return attribute == null ? null : attribute.dbValue();
    }

    @Override
    public MotivoSegnalazione convertToEntityAttribute(String dbData) {
        return dbData == null ? null : MotivoSegnalazione.fromDbValue(dbData);
    }
}
