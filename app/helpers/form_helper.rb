module FormHelper
  def source_checkbox(source, params)
    "<div class='field-subitem'>
      <label class='field-checkbox'>
        <input type='checkbox' value='#{source.downcase}' name='sourceFilter[]'
               class='source'#{' checked' if params[:sourceFilter]&.include?(source.downcase) }>
        #{source}
      </label>
    </div>".html_safe
  end
end
