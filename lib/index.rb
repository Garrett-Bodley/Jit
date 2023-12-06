# frozen_string_literal: true

require 'digest/sha1'
require 'sorted_set'

require_relative 'index/entry'
require_relative 'lockfile'
require_relative 'index/checksum'

# Logic related to managing the .git/index file
class Index
  HEADER_SIZE = 12
  HEADER_FORMAT = 'a4N2'
  SIGNATURE = 'DIRC'
  VERSION = 2

  ENTRY_FORMAT = 'N10H40nZ*'
  ENTRY_BLOCK = 8
  ENTRY_MIN_SIZE = 64

  def initialize(pathname)
    @pathname = pathname
    @lockfile = Lockfile.new(pathname)
    clear
  end

  def clear
    @entries = {}
    @keys = SortedSet.new
    @changed = false
  end

  def add(pathname, oid, stat)
    entry = Entry.create(pathname, oid, stat)
    store_entry(entry)
    @changed = true
  end

  def each_entry
    if block_given?
      @keys.each { |key| yield @entries[key] }
    else
      enum_for(:each_entry)
    end
  end

  def load
    clear
    file = open_index_file
    if file
      reader = Checksum.new(file)
      count = read_header(reader)
      reader_entries(reader, count)
      reader.verify_checksum
    end
  ensure
    file&.close
  end

  def load_for_update
    if @lockfile.hold_for_update
      load
      true
    else
      false
    end
  end

  def open_index_file
    File.open(@pathname, File::RDONLY)
  rescue Errno::ENOENT
    nil
  end

  def reader_entries(reader, count)
    count.times do
      entry = reader.read(ENTRY_MIN_SIZE)

      entry.concat(reader.read(ENTRY_BLOCK)) until entry.byteslice(-1) == "\0"

      store_entry(Entry.parse(entry))
    end
  end

  def read_header(reader)
    data = reader.read(HEADER_SIZE)
    signature, version, count = data.unpack(HEADER_FORMAT)

    raise Invalid, "Signature: expected '#{ SIGNATURE }' but found '#{ signature }'" unless signature == SIGNATURE
    raise Invalid, "Version: expected `#{ VERSION }` but found `#{ version }`" unless version == VERSION

    count
  end

  def store_entry(entry)
    @keys.add(entry.key)
    @entries[entry.key] = entry
  end

  def write_updates
    return @lockfile.rollback unless @changed

    writer = Checksum.new(@lockfile)

    header = [SIGNATURE, VERSION, @entries.size].pack(HEADER_FORMAT)
    writer.write(header)
    each_entry { |entry| writer.write(entry.to_s) }

    writer.write_checksum
    @lockfile.commit
    @changed = false
  end

  def begin_write
    @digest = Digest::SHA1.new
  end

  def write(data)
    @lockfile.write(data)
    @digest.update(data)
  end

  def finish_write
    @lockfile.write(@digest.digest)
    @lockfile.commit
  end
end