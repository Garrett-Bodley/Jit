# frozen_string_literal: true

class Database
  Entry = Struct.new(:oid, :mode) do
    def tree?
      mode == Tree::TREE_MODE
    end
  end
end
