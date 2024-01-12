# frozen_string_literal: true

require 'pathname'
require_relative '../repository'

module Command
  # Handles init command logic
  class Init
    def run
      path = ARGV.fetch(0, Dir.getwd)

      root_path = Pathname.new(File.expand_path(path))
      git_path = root_path.join('.git')

      ['objects', 'refs'].each do |dir|
        begin
          FileUtils.mkdir_p(git_path.join(dir))
        rescue Errno::EACCES => error
          $stderr.puts "Fatal: #{ error.message }"
          exit 1
        end
      end

      puts "Initialized empty Jit repository in #{ git_path }"
      exit 0
    end
  end
end
