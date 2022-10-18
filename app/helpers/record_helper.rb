module RecordHelper
  def doi(metadata)
    dois = metadata['identifiers']&.select { |id| id['kind'].downcase == 'doi' }
    return unless dois.present?

    dois.first['value']
  end

  def date_parse(date)
    return unless date.present?

    Date.parse(date).to_fs(:long)
  rescue Date::Error
    date
  end

  def date_range(range)
    return unless range.present?

    "#{date_parse(range['gte'])} to #{date_parse(range['lte'])}"
  end

  def publication_date(metadata)
    metadata['dates'].select { |date| date['kind'] == 'Publication date' }.first['value']
  end

  # Display the machine-format key in human-readable text.
  def render_key(string)
    string.capitalize.gsub('_', ' ').gsub('Mit', 'MIT')
  end

  # Field type helpers
  def field_list(record, element)
    return unless record[element].present?

    markupclass = 'field-list'

    title = "<h3>#{render_key(element)}</h3>"
    values = if record[element].length == 1
               "<p class='#{markupclass}'>#{record[element][0]}</p>".html_safe
             else
               "<ul class='#{markupclass}'>#{render_list_items(record[element])}</ul>"
             end
    (title + values).html_safe
  end

  def field_object(record, element)
    return unless record[element].present?

    markupclass = 'field-object'

    title = "<h3>#{render_key(element)}</h3>"
    values = "<ul class='#{markupclass}'>#{render_kind_value(record[element])}</ul>"
    (title + values).html_safe
  end

  def field_string(record, element)
    return unless record[element].present?

    markupclass = 'field-string'

    "<h3>#{render_key(element)}</h3><p class='#{markupclass}'>#{record[element]}</p>".html_safe
  end

  def field_table(record, element, fields, label = '')
    return unless record[element].present?

    title = if label.present?
              "<h3>#{label}</h3>"
            else
              "<h3>#{render_key(element)}</h3>"
            end
    labels = "<table><thead><tr>#{render_table_header(fields)}</tr></thead>"
    values = "<tbody>#{render_table_row(record[element], fields)}</tbody></table>"
    (title + labels + values).html_safe
  end

  private

  def render_kind_value(list)
    list.map { |item| "<li>#{item['kind']}: #{render_list(item['value'])}</li>" }.join
  end

  def render_list_items(list)
    list.map { |item| "<li>#{item}</li>" }.join
  end

  def render_table_header(list)
    list.map { |item| "<th scope='col'>#{render_key(item)}</th>" }.join
  end

  def render_table_row(object, order)
    object.map { |row| "<tr>#{order.map { |field| "<td>#{render_list(row[field])}</td>" }.join}</tr>" }.join
  end

  def render_list(list)
    return if list.nil?
    return list.to_s if list.instance_of?(String)
    return list[0].to_s if list.length == 1

    "<ul>#{render_list_items(list)}</ul>"
  end
end
