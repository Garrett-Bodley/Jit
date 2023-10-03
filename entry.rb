# frozen_string_literal: true

# Represents an entry
class Entry
  attr_reader :name, :oid

  def initialize(name, oid)
    @name = name
    @oid = oid
  end
end
