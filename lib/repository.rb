# frozen_string_literal: true

require_relative 'database'
require_relative 'index'
require_relative 'refs'
require_relative 'workspace'

# Abstraction to group Repository related logic together
class Repository
  def initialize(git_path)
    @git_path = git_path
  end

  def database
    @database ||= Database.new(@git_path.join('objects'))
  end

  def index
    @index ||= Index.new(@git_path.join('index'))
  end

  def refs
    @refs ||= Refs.new(@git_path)
  end

  def workspace
    @workspace ||= Workspace.new(@git_path.dirname)
  end
end
