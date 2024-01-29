# frozen_string_literal: true

class Database
  # Represents a Blob object in the database
  class Blob
    attr_accessor :oid
    attr_reader :data

    def initialize(data)
      @data = data
    end

    def self.parse(scanner)
      Blob.new(scanner.rest)
    end

    def type
      'blob'
    end

    def to_s
      @data
    end
  end
end
