module FormHelper
  def source_checkbox(source, params)
    "<div class='field-subitem'>
      <label class='field-checkbox'>
        <input type='checkbox' value='#{source}' name='source[]' class='source'#{if params[:source]&.include?(source)
                                                                                   ' checked'
                                                                                 end}>
        #{source}
      </label>
    </div>".html_safe
  end
end
