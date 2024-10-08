# frozen_string_literal: true

# Generates colored strings via escape codes
module Color
  SGR_CODES = {
    'bold' => 1,
    'red' => 31,
    'green' => 32,
    'cyan' => 36
  }.freeze

  def self.format(style, string)
    code = SGR_CODES.fetch(style.to_s)
    "\e[#{ code }m#{ string }\e[m"
  end
end
