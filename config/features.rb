Flipflop.configure do
  # Strategies will be used in the order listed here.
  strategy :session
  strategy :default

  feature :gdt,
    default: ENV.fetch('GDT', false),
    description: "Enable geodata discovery features."
end
