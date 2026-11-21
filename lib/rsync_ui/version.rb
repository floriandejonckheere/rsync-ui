# frozen_string_literal: true

module RsyncUI
  module Version
    MAJOR = 1
    MINOR = 1
    PATCH = 1
    PRE   = nil

    GIT_HASH = "development"
    BUILD_DATE = nil

    VERSION = [MAJOR, MINOR, PATCH].compact.join(".")

    STRING = [VERSION, PRE].compact.join("-")
  end

  VERSION = Version::STRING
end
