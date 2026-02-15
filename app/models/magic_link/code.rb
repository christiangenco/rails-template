module MagicLink::Code
  # Uppercase letters and digits, excluding confusable characters (O, I, L)
  ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".chars.freeze
  CODE_SUBSTITUTIONS = { "O" => "0", "I" => "1", "L" => "1" }.freeze

  class << self
    def generate(length)
      SecureRandom.alphanumeric(length, chars: ALPHABET)
    end

    def sanitize(code)
      return nil if code.blank?
      code.to_s.upcase
        .then { |c| CODE_SUBSTITUTIONS.reduce(c) { |r, (from, to)| r.gsub(from, to) } }
        .then { |c| c.gsub(/[^#{ALPHABET.join}]/, "") }
    end
  end
end
