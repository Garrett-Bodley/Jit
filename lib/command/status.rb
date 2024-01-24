# frozen_string_literal: true

require "sorted_set"
require_relative 'base'

module Command
  # Logic for 'jit status' command
  class Status < Base
    def run
      repo.index.load

      @untracked = SortedSet.new

      scan_workspace

      @untracked.sort.each do |path|
        puts "?? #{ path }"
      end

      exit 0
    end

    def scan_workspace(prefix = nil)
      repo.workspace.list_dir(prefix).each do |path, stat|
        if repo.index.tracked?(path)
          scan_workspace(path) if stat.directory?
        else
          path += File::SEPARATOR if stat.directory?
          @untracked.add(path)
        end
      end
    end
  end
end
