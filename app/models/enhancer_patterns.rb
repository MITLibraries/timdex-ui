class EnhancerPatterns
  attr_accessor :enhanced_query

  def initialize(enhanced_query, term)
    @enhanced_query = enhanced_query
    term_pattern_checker(term)
  end

  private

  def term_pattern_checker(term)
    term_patterns.each_pair do |type, pattern|
      @enhanced_query[type.to_sym] = match(pattern, term) if match(pattern, term).present?
    end
  end

  def match(pattern, term)
    pattern.match(term).to_s.strip
  end

  # term_patterns are regex patterns to be applied to the basic search box input
  def term_patterns
    {
      isbn: /(ISBN-*(1[03])* *(: ){0,1})*(([0-9Xx][- ]*){13}|([0-9Xx][- ]*){10})/,
      issn: /[0-9]{4}-[0-9]{3}[0-9xX]/
    }
  end
end
