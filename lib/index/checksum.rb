# frozen_string_literal: true

require 'digest/sha1'

class Index
  # Takes a file handle and creates a new Digest::SHA1 object
  class Checksum
    EndOfFile = Class.new(StandardError)
    Invalid = Class.new(StandardError)

    CHECKSUM_SIZE = 20

    def initialize(file)
      @file = file
      @digest = Digest::SHA1.new
    end

    def read(size)
      data = @file.read(size)

      raise EndOfFile, 'Unexpected end-of-file while reading index' unless data.bytesize == size

      @digest.update(data)
      data
    end

    def verify_checksum
      sum = @file.read(CHECKSUM_SIZE)

      unless sum == @digest.digest # rubocop:disable Style/GuardClause
        raise Invalid, 'Checksum does not match value stored on disk'
      end
    end

    def write(data)
      @file.write(data)
      @digest.update(data)
    end

    def write_checksum
      @file.write(@digest.digest)
    end
  end
end
