# frozen_string_literal: true

require_relative 'base'

module Command
  # Logic for 'jit status' command
  class Status < Base
    def run
      root_path = Pathname.new(@dir)
      repo = Repository.new(root_path.join('.git'))

      repo.index.load

      untracked = repo.workspace.list_files.reject do |path|
        repo.index.tracked?(path)
      end

      untracked.sort.each do |path|
        puts "?? #{ path }"
      end

      exit 0
    end
  end
end
