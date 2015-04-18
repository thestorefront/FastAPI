module FastAPI
  module Utilities
    def clamp(value, min, max)
      [min, value, max].sort[1]
    end
  end
end
