# frozen_string_literal: true

# This file creates a spearate Entry class for use by its parent class Index
class Index
  REGULAR_MODE = 0o100644
  EXECUTABLE_MODE = 0o100755
  MAX_PATH_SIZE = 0xfff

  entry_fields = %i[
    ctime ctime_nsec
    mtime mtime_nsec
    dev ino mode uid gid size
    oid flags path
  ]

  Entry = Struct.new(*entry_fields) do
    def self.create(pathname, oid, stat) # rubocop:disable Metrics/AbcSize
      path = pathname.to_s
      mode = stat.executable? ? EXECUTABLE_MODE : REGULAR_MODE
      flags = [path.bytesize, MAX_PATH_SIZE].min

      Entry.new(
        stat.ctime.to_i, stat.ctime.nsec,
        stat.mtime.to_i, stat.mtime.nsec,
        stat.dev, stat.ino, mode, stat.uid, stat.gid, stat.size,
        oid, flags, path
      )
    end

    def basename
      Pathname.new(path).basename
    end

    def parent_directories
      Pathname.new(path).descend.to_a[0..-2]
    end

    def self.parse(data)
      Entry.new(*data.unpack(ENTRY_FORMAT))
    end

    def to_s
      string = to_a.pack(ENTRY_FORMAT)
      string.concat("\0") until string.bytesize % ENTRY_BLOCK == 0
      string
    end

    def key
      path
    end
  end
end