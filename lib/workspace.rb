# frozen_string_literal: true

# Represents the working directory of our git repo
class Workspace
  IGNORE = ['.', '..', '.git'].freeze
  def initialize(pathname)
    @pathname = pathname
  end

  def list_files(path = @pathname)
    if File.directory?(path)
      filenames = Dir.entries(path) - IGNORE
      filenames.flat_map { |name| list_files(path.join(name))}
    else
      [path.relative_path_from(@pathname)]
    end
  end

  def stat_file(path)
    File.stat(@pathname.join(path))
  end

  def read_file(path)
    File.read(@pathname.join(path))
  end
end
