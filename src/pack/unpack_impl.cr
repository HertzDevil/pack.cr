# :nodoc:
module Pack::UnpackImpl
  def self.to_slice(bytes : Bytes)
    bytes
  end

  def self.to_hex(c)
    ((c < 10 ? 48_u8 : 87_u8) + c)
  end

  # def self.to_slice(bytes : String)
  #   bytes.to_slice
  # end

  macro unpack_utf8
    %value = obj[byte_offset].to_u32
    case %value
    when 0x00..0x7F
      byte_offset += 1
    when 0xC2..0xDF
      c1 = obj[byte_offset + 1]
      raise InvalidByteSequenceError.new unless 0x80 <= c1 <= 0xBF
      %value = ((%value & 0x1F) << 6) | (c1 & 0x3F)
      byte_offset += 2
    when 0xE0..0xEF
      c1 = obj[byte_offset + 1]
      raise InvalidByteSequenceError.new unless 0x80 <= c1 <= 0xBF
      c2 = obj[byte_offset + 2]
      raise InvalidByteSequenceError.new unless 0x80 <= c2 <= 0xBF
      %value = ((%value & 0x0F) << 12) | ((c1 & 0x3F).to_u32 << 6) | (c2 & 0x3F)
      raise InvalidByteSequenceError.new unless (0x0800 <= %value <= 0xD7FF) || 0xE000 <= %value
      byte_offset += 3
    when 0xF0..0xF4
      c1 = obj[byte_offset + 1]
      raise InvalidByteSequenceError.new unless 0x80 <= c1 <= 0xBF
      c2 = obj[byte_offset + 2]
      raise InvalidByteSequenceError.new unless 0x80 <= c2 <= 0xBF
      c3 = obj[byte_offset + 3]
      raise InvalidByteSequenceError.new unless 0x80 <= c3 <= 0xBF
      %value = ((%value & 0x07) << 18) | ((c1 & 0x3F).to_u32 << 12) | ((c2 & 0x3F).to_u32 << 6) | (c3 & 0x3F)
      raise InvalidByteSequenceError.new unless 0x10000 <= %value <= Char::MAX_CODEPOINT
      byte_offset += 4
    else
      raise InvalidByteSequenceError.new
    end
    %value.unsafe_chr
  end

  macro unpack_ber
    %ch = obj[byte_offset]
    byte_offset += 1
    %value = 0x7F_u64 & %ch

    while %ch & 0x80_u8 != 0
      %ch = obj[byte_offset]
      byte_offset += 1
      %value = (%value << 7) | (%ch & 0x7F_u8)
    end

    %value
  end

  # accesses `obj` and `byte_offset` from outer scope
  # defines `sz` and `elem_count` in outer scope
  macro do_unpack1(directive, native_size, endianness, count, glob)
    {% p [directive, native_size, endianness, count, glob] if false %}

    {% if "cCsSlLqQiIjJnNvVdfFeEgG".includes?(directive) %}
      {% if directive == 'n' %}
        {% directive, endianness = 'S', :NetworkEndian %}
      {% elsif directive == 'N' %}
        {% directive, endianness = 'L', :NetworkEndian %}
      {% elsif directive == 'v' %}
        {% directive, endianness = 'S', :LittleEndian %}
      {% elsif directive == 'V' %}
        {% directive, endianness = 'L', :LittleEndian %}
      {% elsif directive == 'e' %}
        {% directive, endianness = 'f', :LittleEndian %}
      {% elsif directive == 'E' %}
        {% directive, endianness = 'd', :LittleEndian %}
      {% elsif directive == 'g' %}
        {% directive, endianness = 'f', :BigEndian %}
      {% elsif directive == 'G' %}
        {% directive, endianness = 'd', :BigEndian %}
      {% end %}

      {%
        if directive == 'i'
          value_type = ::LibC::Int
        elsif directive == 'I'
          value_type = ::LibC::UInt
        elsif directive == 'j'
          value_type = ::LibC::Int64T
        elsif directive == 'J'
          value_type = ::LibC::UInt64T
        elsif directive == 'F'
          value_type = ::LibC::Float32
        elsif native_size
          if directive == 's'
            value_type = ::LibC::Short
          elsif directive == 'S'
            value_type = ::LibC::UShort
          elsif directive == 'l'
            value_type = ::LibC::Long
          elsif directive == 'L'
            value_type = ::LibC::ULong
          elsif directive == 'q'
            value_type = ::LibC::LongLong
          elsif directive == 'Q'
            value_type = ::LibC::ULongLong
          end
        else
          if directive == 'c'
            value_type = ::Int8
          elsif directive == 'C'
            value_type = ::UInt8
          elsif directive == 's'
            value_type = ::Int16
          elsif directive == 'S'
            value_type = ::UInt16
          elsif directive == 'l'
            value_type = ::Int32
          elsif directive == 'L'
            value_type = ::UInt32
          elsif directive == 'q'
            value_type = ::Int64
          elsif directive == 'Q'
            value_type = ::UInt64
          elsif directive == 'f'
            value_type = ::Float32
          elsif directive == 'd'
            value_type = ::Float64
          end
        end
      %}

      {% converter = ::IO::ByteFormat.constant(endianness) %}
      sz = sizeof({{ value_type }})

      {% if count %}
        %value = StaticArray({{ value_type }}, {{ count }}).new do |i|
          {{ converter }}.decode({{ value_type }}, obj[byte_offset + sz * i, sz])
        end
        byte_offset += sz * {{ count }}
      {% elsif glob %}
        elem_count = (obj.size - byte_offset) // sz
        %value = Array({{ value_type }}).new(elem_count) do |i|
          {{ converter }}.decode({{ value_type }}, obj[byte_offset + sz * i, sz])
        end
        byte_offset += sz * elem_count
      {% else %}
        %value = {{ converter }}.decode({{ value_type }}, obj[byte_offset, sz])
        byte_offset += sz
      {% end %}

    {% elsif directive == 'U' %}
      {% if count %}
        %value = String.build do |b|
          {{ count }}.times do
            b << Pack::UnpackImpl.unpack_utf8
          end
        end
      {% elsif glob %}
        %value = String.build do |b|
          while byte_offset < obj.size
            b << Pack::UnpackImpl.unpack_utf8
          end
        end
      {% else %}
        %value = Pack::UnpackImpl.unpack_utf8
      {% end %}

    {% elsif directive == 'w' %}
      {% if count %}
        %value = StaticArray(UInt64, {{ count }}).new do
          Pack::UnpackImpl.unpack_ber
        end
      {% elsif glob %}
        %value = Array(UInt64).new
        while byte_offset < obj.size
          %value << Pack::UnpackImpl.unpack_ber
        end
      {% else %}
        %value = Pack::UnpackImpl.unpack_ber
      {% end %}

    {% elsif directive == 'a' || directive == 'A' %}
      {% if glob %}
        elem_count = obj.size - byte_offset
      {% else %}
        elem_count = { obj.size - byte_offset, {{ count || 1 }} }.min
      {% end %}
      %value = obj[byte_offset, elem_count]
      byte_offset += elem_count

      {% if directive == 'A' %}
        sz = %value.size
        while sz > 0 && %value.unsafe_fetch(sz - 1).in?(0x00_u8, 0x20_u8)
          sz -= 1
        end
        %value = %value[0, sz]
      {% end %}

    {% elsif directive == 'Z' %}
      {% if glob %}
        elem_count = 0
        sz = byte_offset
        while sz < obj.size
          sz += 1
          break if obj.unsafe_fetch(sz - 1) == 0x00_u8
          elem_count += 1
        end
        %value = obj[byte_offset, elem_count]
        byte_offset = sz
      {% else %}
        elem_count = { obj.size - byte_offset, {{ count || 1 }} }.min
        %value = obj[byte_offset, elem_count]
        byte_offset += elem_count

        elem_count = 0
        while elem_count < %value.size && %value.unsafe_fetch(elem_count) != 0x00_u8
          elem_count += 1
        end
        %value = %value[0, elem_count]
      {% end %}

    {% elsif directive == 'h' || directive == 'H' %}
      {% if glob %}
        elem_count = (obj.size - byte_offset) * 2
      {% else %}
        elem_count = {{ count || 1 }}
      {% end %}

      %value = String.build do |b|
        (elem_count // 2).times do
          ch = obj[byte_offset]
          byte_offset += 1
          {% if directive == 'H' %}
            b.write_byte(Pack::UnpackImpl.to_hex((ch >> 4) & 0xF))
            b.write_byte(Pack::UnpackImpl.to_hex(ch & 0xF))
          {% else %}
            b.write_byte(Pack::UnpackImpl.to_hex(ch & 0xF))
            b.write_byte(Pack::UnpackImpl.to_hex((ch >> 4) & 0xF))
          {% end %}
        end

        if elem_count % 2 != 0
          {% if directive == 'H' %}
            b.write_byte(Pack::UnpackImpl.to_hex((obj[byte_offset] >> 4) & 0xF))
          {% else %}
            b.write_byte(Pack::UnpackImpl.to_hex(obj[byte_offset] & 0xF))
          {% end %}
          byte_offset += 1
        end
      end

    {% elsif directive == 'b' || directive == 'B' %}
      {% if glob %}
        elem_count = (obj.size - byte_offset) * 8
      {% else %}
        elem_count = {{ count || 1 }}
      {% end %}

      %value = String.build do |b|
        (elem_count // 8).times do
          ch = obj[byte_offset]
          byte_offset += 1
          {% if directive == 'B' %}
            7.downto(0) do |i|
              b.write_byte((ch >> i) & 0x01 | 0x30)
            end
          {% else %}
            0.upto(7) do |i|
              b.write_byte((ch >> i) & 0x01 | 0x30)
            end
          {% end %}
        end

        rest = elem_count % 8
        if rest != 0
          ch = obj[byte_offset]
          byte_offset += 1
          {% if directive == 'B' %}
            7.downto(8 - rest) do |i|
              b.write_byte((ch >> i) & 0x01 | 0x30)
            end
          {% else %}
            0.upto(rest - 1) do |i|
              b.write_byte((ch >> i) & 0x01 | 0x30)
            end
          {% end %}
        end
      end

    {% elsif directive == 'P' %}
      sz = sizeof(Void*)
      {% if count %}
        %value = Slice.new(obj[byte_offset, sz].to_unsafe.as(UInt8**).value, {{ count }})
      {% else %}
        %value = obj[byte_offset, sz].to_unsafe.as(Void**).value
      {% end %}
      byte_offset += sz
    {% elsif directive == 'p' %}
      sz = sizeof(UInt8*)
      {% if count %}
        %value = String.new(obj[byte_offset, sz].to_unsafe.as(UInt8**).value, {{ count }})
      {% else %}
        %value = String.new(obj[byte_offset, sz].to_unsafe.as(UInt8**).value)
      {% end %}
      byte_offset += sz

    {% elsif directive == '@' %}
      byte_offset = {{ count || 0 }}
    {% elsif directive == 'x' %}
      {% if glob %}
        byte_offset = obj.size
      {% else %}
        byte_offset += {{ count || 1 }}
      {% end %}
    {% elsif directive == 'X' %}
      {% if glob %}
        byte_offset = 0
      {% else %}
        byte_offset = { 0, byte_offset - {{ count || 1 }} }.max
      {% end %}

    {% else %}
      # u mM
      {% raise "BUG: unknown directive #{directive}" %}
    {% end %}

    {% unless "@xX".includes?(directive) %}
      %value
    {% end %}
  end
end

module Pack
  # Unpacks a buffer of *bytes* according to the given format string *fmt*.
  # Returns a `Tuple` of unpacked values, without flattening directives that
  # contain repeat counts.
  #
  # *bytes* must be a `Slice(UInt8)`. *fmt* must be a string literal or constant
  # representing a valid sequence of unpacking directives.
  #
  # ```
  # Pack.unpack(Bytes[0x01, 0xE8, 0x03, 0x05, 0xF5, 0xE1, 0x00], "csl>") # => {1_i8, 1000_i16, 100000000}
  # Pack.unpack("abcd\x00ef\x00".to_slice, "CCZ*a*")                     # => {StaticArray[97_u8, 98_u8], Bytes[99, 100], Bytes[101, 102, 0]}
  # ```
  macro unpack(bytes, fmt)
    {% if fmt.is_a?(Path) %}
      {% fmt = fmt.resolve %}
    {% end %}
    {% unless fmt.is_a?(StringLiteral) %}
      {% fmt.raise "format must be a string literal or constant" %}
    {% end %}

    {% commands = [] of ASTNode %}
    {% directive = nil %}
    {% native_size = false %}
    {% endianness = :SystemEndian %}
    {% count = nil %}
    {% glob = false %}

    {% chars = fmt.chars %}
    {% chars << ' ' %}
    {% accepts_modifiers = false %}
    {% directive_start = nil %}

    {% for ch, index in chars %}
      {% if "cCsSlLqQiIjJnNvVdfFeEgGUwaAZbBhHumMpP@xX \n\t\f\v\r".includes?(ch) %}
        {% if directive %}
          {% name = chars[directive_start...index].join("") %}
          {% commands << {name, directive, native_size, endianness, count, glob, index} %}
        {% end %}

        {% directive = nil %}
        {% native_size = false %}
        {% endianness = :SystemEndian %}
        {% count = nil %}
        {% glob = false %}
        {% accepts_modifiers = false %}
        {% directive_start = index %}

        {% unless " \n\t\f\v\r".includes?(ch) %}
          {% directive = ch %}
          {% accepts_modifiers = "sSlLqQjJiI".includes?(ch) %}
        {% end %}

      {% elsif ch == '_' || ch == '!' %}
        {% fmt.raise "#{ch} allowed only after directives sSiIlLqQjJ" unless accepts_modifiers %}
        {% fmt.raise "#{ch} allowed only before '*' and count" if glob || count %}
        {% native_size = true %}

      {% elsif ch == '<' %}
        {% fmt.raise "#{ch} allowed only after directives sSiIlLqQjJ" unless accepts_modifiers %}
        {% fmt.raise "#{ch} allowed only before '*' and count" if glob || count %}
        {% fmt.raise "can't use both '<' and '>'" if endianness == :BigEndian %}
        {% endianness = :LittleEndian %}
      {% elsif ch == '>' %}
        {% fmt.raise "#{ch} allowed only after directives sSiIlLqQjJ" unless accepts_modifiers %}
        {% fmt.raise "#{ch} allowed only before '*' and count" if glob || count %}
        {% fmt.raise "can't use both '<' and '>'" if endianness == :LittleEndian %}
        {% endianness = :BigEndian %}

      {% elsif ch == '*' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "#{ch} not allowed for '@'" if directive == '@' %}
        {% fmt.raise "#{ch} not allowed for 'P'" if directive == 'P' %}
        {% fmt.raise "can't use both '*' and count" if count %}
        {% glob = true %}

      {% elsif ch == '0' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 0 : 0 %}
      {% elsif ch == '1' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 1 : 1 %}
      {% elsif ch == '2' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 2 : 2 %}
      {% elsif ch == '3' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 3 : 3 %}
      {% elsif ch == '4' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 4 : 4 %}
      {% elsif ch == '5' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 5 : 5 %}
      {% elsif ch == '6' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 6 : 6 %}
      {% elsif ch == '7' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 7 : 7 %}
      {% elsif ch == '8' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 8 : 8 %}
      {% elsif ch == '9' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 9 : 9 %}

      {% elsif ch == 'D' %}
        {% fmt.raise "long double is not supported, use 'd' instead" %}

      {% else %}
        {% fmt.raise "unexpected directive: #{ch}" %}
      {% end %}
    {% end %}

    obj = Pack::UnpackImpl.to_slice({{ bytes }})
    byte_offset = 0

    {% used_indices = [] of ASTNode %}
    {% for command in commands %}
      {% name, directive, native_size, endianness, count, glob, index = command %}
      {% if "@xX".includes?(directive) %}
        Pack::UnpackImpl.do_unpack1({{ directive }}, {{ native_size }}, {{ endianness }}, {{ count }}, {{ glob }})
      {% else %}
        %values{index} = Pack::UnpackImpl.do_unpack1({{ directive }}, {{ native_size }}, {{ endianness }}, {{ count }}, {{ glob }})
        {% used_indices << index %}
      {% end %}
    {% end %}

    Tuple.new(
      {% for index in used_indices %}
        %values{index},
      {% end %}
    )
  end
end
