# frozen_string_literal: true

class Database
  # Represents a Tree object in the databse
  class Tree
    ENTRY_FORMAT = 'Z*H40'
    MODE = '100644'
    TREE_MODE = 040000

    attr_accessor :oid

    def initialize
      @entries = {}
    end

    def self.build(entries)
      root = Tree.new
      entries.each do |entry|
        root.add_entry(entry.parent_directories, entry)
      end
      root
    end

    def add_entry(parents, entry)
      if parents.empty?
        @entries[entry.basename] = entry
      else
        tree = @entries[parents.first.basename] ||= Tree.new
        tree.add_entry(parents.drop(1), entry)
      end
    end

    def traverse(&block)
      @entries.each do |name, entry|
        entry.traverse(&block) if entry.is_a?(Tree)
      end
      block.call(self)
    end

    def type
      'tree'
    end

    def to_s
      entries = @entries.map do |name, entry|
        mode = entry.mode.to_s(8)
        ["#{ mode } #{ name }", entry.oid].pack(ENTRY_FORMAT)
      end

      entries.join('')
    end

    def mode
      TREE_MODE
    end
  end
end
