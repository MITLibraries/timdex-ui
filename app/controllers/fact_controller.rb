class FactController < ApplicationController
  layout false

  def doi
    return unless params[:doi].present?

    @json = FactDoi.new.info(params[:doi])
  end

  def issn
    return unless params[:issn].present?

    @json = FactIssn.new.info(params[:issn])
  end

  def isbn
    return unless params[:isbn].present?

    @json = FactIsbn.new.info(params[:isbn])
  end

  def pmid
    return unless params[:pmid].present?

    @json = FactPmid.new.info(params[:pmid].split.last)
  end
end
