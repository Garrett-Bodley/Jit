# frozen_string_literal: true

# Manages the Ref objects
class Refs
  LockDenied = Class.new(StandardError)

  def initialize(pathname)
    @pathname = pathname
  end

  def update_head(oid)
    lockfile = Lockfile.new(head_path)

    unless lockfile.hold_for_update
      raise LockDenied, "Could not acquire lock on file: #{ head_path }"
    end

    lockfile.write(oid)
    lockfile.write('\n')
    lockfile.commit
  end

  def read_head
    return unless File.exist?(head_path)
    binding.pry
    File.read(head_path).strip
  end

  private

  def head_path
    @pathname.join('HEAD')
  end
end
