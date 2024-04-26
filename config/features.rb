Flipflop.configure do
  # Strategies will be used in the order listed here.
  strategy :session
  strategy :default

  feature :gdt,
    default: ENV.fetch('GDT', false),
    description: "Enable geodata discovery features."

  feature :boolean_picker,
    default: ENV.fetch('BOOLEAN_PICKER', false),
    description: "Enable user configurable boolean type selection."
end
