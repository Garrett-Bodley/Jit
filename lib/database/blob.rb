# frozen_string_literal: true

class Database
  # Represents a Blob object in the database
  class Blob
    attr_accessor :oid

    def initialize(data)
      @data = data
    end

    def type
      'blob'
    end

    def to_s
      @data
    end
  end
end
