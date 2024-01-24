# frozen_string_literal: true

module Command
  class Base
    attr_reader :status

    def initialize(dir, env, args, stdin, stdout, stderr) # rubocop:disable Metrics/ParameterLists
      @dir = dir
      @env = env
      @args = args
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
    end

    def repo
      @repo ||= Repository.new(Pathname.new(@dir).join('.git'))
    end

    def execute
      catch(:exit) { run }
    end

    private

    def expanded_pathname(path)
      Pathname.new(File.expand_path(path, @dir))
    end

    def puts(string)
      @stdout.puts(string)
    end

    def exit(status = 0)
      @status = status
      throw :exit
    end

  end
end
