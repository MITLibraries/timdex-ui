# Central feature flag management class for the application. This class provides a simple,
# centralized way to manage feature flags throughout the codebase.
#
# Feature flags are controlled through environment variables with the prefix 'FEATURE_'
# followed by the uppercase feature name. Each flag defaults to false unless explicitly
# enabled via environment variable to ensure consistency in how our features work.
#
# @example Basic Usage
#   Feature.enabled?(:geodata)       # true if FEATURE_GEODATA=true in ENV
#   Feature.enabled?(:unknown)       # Returns false for undefined features
#
# @example Setting Flags in Environment
#   # In local ENV or Heroku config:
#   FEATURE_GEODATA=true             # Enables the GDT feature
#   FEATURE_BOOLEAN_PICKER=true      # Enables the boolean picker feature
#
#   # Any non-true value or not setting ENV does not enable the feature
#   FEATURE_GEODATA=false            # Does not enable the GDT feature
#   FEATURE_GEODATA=1                # Does not enable the GDT feature
#   FEATURE_GEODATA=on               # Does not enable the GDT feature
#
# @example Usage in Different Contexts
#   # In models/controllers:
#   return unless Feature.enabled?(:geodata)
#
#   # In views:
#   <% if Feature.enabled?(:geodata) %>
#
#   # In tests:
#   ClimateControl.modify FEATURE_GEODATA: 'true' do
#     assert Feature.enabled?(:geodata)
#   end
#
class Feature
  # List of all valid features in the application
  VALID_FEATURES = %i[geodata boolean_picker].freeze

  # Check if a feature is enabled by name
  #
  # @param feature_name [Symbol] The name of the feature to check
  # @return [Boolean] true if the feature is enabled, false otherwise
  # @example Check if a feature is enabled
  #   Feature.enabled?(:geodata)
  def self.enabled?(feature_name)
    return false unless VALID_FEATURES.include?(feature_name)

    ENV.fetch("FEATURE_#{feature_name.to_s.upcase}", false).to_s.downcase == 'true'
  end
end
