module MarcInJsonModel
  def fixed_field (label)
    field = @data['fixedFields']
      .values
      .find { |field| field['label'] == label }
    return nil if field.nil?

    if block_given?
      yield field
    else
      field['value'] unless field.nil?
    end
  end

  def var_field (tag, subfield_tag)
    field = @data['varFields']
      .find { |field| field['marcTag'] == tag.to_s }
    if (!field.nil? && subfield_tag)
      subfield = field['subfields']
        .find { |subfield| subfield['tag'] == subfield_tag.to_s }
      subfield['content']
    else
      field
    end
  end
end
