      setup_pager

        header("new file mode #{ b.mode }")
        header("deleted file mode #{ a.mode }")
        header("old mode #{ a.mode }")
        header("new mode #{ b.mode }")
      puts fmt(:cyan, hunk.header)
      hunk.edits.each { |edit| print_diff_edit(edit) }
    end

    def print_diff_edit(edit)
      text = edit.to_s.rstrip

      case edit.type
      when :eql
        puts text
      when :ins
        puts fmt(:green, text)
      when :del
        puts fmt(:red, text)
      end
    end

    def header(string)
      puts fmt(:bold, string)