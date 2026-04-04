module Wnd
  module Nostr
    BECH32_CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l".chars.freeze

    def self.to_npub(hex_pubkey)
      bech32_encode("npub", hex_to_bytes(hex_pubkey))
    end

    def self.hex_to_bytes(hex)
      [ hex ].pack("H*").bytes
    end

    def self.bech32_encode(hrp, data_bytes)
      data = convertbits(data_bytes, 8, 5)
      checksum = create_checksum(hrp, data)
      hrp + "1" + (data + checksum).map { |d| BECH32_CHARSET[d] }.join
    end

    def self.convertbits(data, frombits, tobits)
      acc = 0
      bits = 0
      ret = []
      data.each do |value|
        acc = (acc << frombits) | value
        bits += frombits
        while bits >= tobits
          bits -= tobits
          ret << ((acc >> bits) & ((1 << tobits) - 1))
        end
      end
      ret << ((acc << (tobits - bits)) & ((1 << tobits) - 1)) if bits > 0
      ret
    end

    def self.create_checksum(hrp, data)
      values = hrp_expand(hrp) + data
      polymod = polymod(values + [ 0, 0, 0, 0, 0, 0 ]) ^ 1
      6.times.map { |i| (polymod >> 5 * (5 - i)) & 31 }
    end

    def self.hrp_expand(hrp)
      hrp.chars.map { |c| c.ord >> 5 } + [ 0 ] + hrp.chars.map { |c| c.ord & 31 }
    end

    def self.polymod(values)
      gen = [ 0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3 ]
      chk = 1
      values.each do |v|
        b = chk >> 25
        chk = ((chk & 0x1ffffff) << 5) ^ v
        5.times { |i| chk ^= gen[i] if ((b >> i) & 1) != 0 }
      end
      chk
    end

    private_class_method :bech32_encode, :convertbits, :create_checksum, :hrp_expand, :polymod, :hex_to_bytes
  end
end
