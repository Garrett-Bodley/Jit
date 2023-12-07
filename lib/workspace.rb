# frozen_string_literal: true

# Represents the working directory of our git repo
class Workspace
  IGNORE = ['.', '..', '.git'].freeze
  MissingFile = Class.new(StandardError)
  NoPermission = Class.new(StandardError)
  def initialize(pathname)
    @pathname = pathname
  end

  def list_files(path = @pathname)
    relative = path.relative_path_from(@pathname)
    if File.directory?(path)
      filenames = Dir.entries(path) - IGNORE
      filenames.flat_map { |name| list_files(path.join(name))}
    elsif File.exist?(path)
      [relative]
    else
      raise MissingFile, "pathspec #{relative} did not match any files"
    end
  end

  def stat_file(path)
    File.stat(@pathname.join(path))
  rescue Errno::EACCES
    raise NoPermission, "stat('#{path}'): Permission denied"
  end

  def read_file(path)
    File.read(@pathname.join(path))
  rescue Errno::EACCES
    raise NoPermission, "open('#{path}'): Permission denied"
  end
end
