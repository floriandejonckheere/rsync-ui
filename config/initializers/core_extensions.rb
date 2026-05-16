# frozen_string_literal: true

Rails.root.glob("lib/core_ext/**/*.rb").each { |f| require f }
