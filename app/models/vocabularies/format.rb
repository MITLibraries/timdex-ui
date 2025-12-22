module Vocabularies
  class Format
    # FORMAT_MAPPINGS is an object listing all the machine-friendly format values we have encountered from TIMDEX or
    # Primo, and the human-friendly values we want to normalize to. Entries should be alphabetized for easier
    # maintenance.
    FORMAT_MAPPINGS = {
      'bkse' => 'eBook',
      'book_chapter' => 'Book Chapter',
      'conference_proceeding' => 'Conference Proceeding',
      'magazinearticle' => 'Magazine Article',
      'newsletterarticle' => 'Newsletter Article',
      'reference_entry' => 'Reference Entry',
      'researchdatabases' => 'Research Database'
    }.freeze

    # The lookup method attemps to look up a human-friendly value for any of the format values we get back from our
    # source systems. The fetch method used allows a default value, which is what happens when a more human-friendly
    # value isn't found in the FORMAT_MAPPINGS constant.
    #
    # @param value [String] A format value to be looked up, if a better version exists.
    # @return [String, nil] The cleaned up version, or nil if a nil was submited.
    def self.lookup(value)
      FORMAT_MAPPINGS.fetch(value.downcase, value&.capitalize)
    end
  end
end
