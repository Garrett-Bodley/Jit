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
        elsif trackable_file?(path, stat)
          path += File::SEPARATOR if stat.directory?
          @untracked.add(path)
        end
      end
    end

    def trackable_file?(path, stat)
      return false unless stat

      return !repo.index.tracked?(path) if stat.file?
      return false unless stat.directory?

      items = repo.workspace.list_dir(path)
      files = items.select { |_, item_stat| item_stat.file? }
      dirs = items.select { |_, item_stat| item_stat.directory? }

      [files, dirs].any? do |list|
        list.any? { |item_path, item_stat| trackable_file?(item_path, item_stat)}
      end
    end
  end
end
