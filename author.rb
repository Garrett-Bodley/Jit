# frozen_string_literal: true

# Class that represents a commit's author
Author = Struct.new(:name, :email, :time) do
  def to_s
    timestamp = time.strftime('%s %z')
    "#{ name } <#{ email }> #{ timestamp }"
  end
end
