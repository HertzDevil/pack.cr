# :nodoc:
module Pack::PackImpl
  class BytesWriter < IO
    @buffer = Bytes.new(8)
    property pos = 0

    def to_slice
      @buffer[0, @pos]
    end

    def read(slice : Bytes)
      raise RuntimeError.new "cannot read from BytesWriter"
    end

    def write(slice : Bytes) : Nil
      if @pos + slice.size > @buffer.size
        new_buffer = Bytes.new(@buffer.size * 2)
        @buffer.copy_to(new_buffer)
        @buffer = new_buffer
      end

      slice.copy_to(@buffer.to_unsafe + @pos, slice.size)
      @pos += slice.size
    end

    def seek(offset, whence : IO::Seek = IO::Seek::Set)
      case whence
      in .set?     then @pos = offset
      in .current? then @pos += offset
      in .end?     then raise ArgumentError.new "seek to end not supported"
      end
      self
    end
  end

  def self.pack_with_count(value : Enumerable, count : Int)
    check_enumerable(value)
    byte_offset = 0

    if count > 0
      value.each do |elem|
        byte_offset += yield elem
        count -= 1
        break if count <= 0
      end
      raise IndexError.new("not enough elements") unless count == 0
    end

    byte_offset
  end

  def self.pack_with_star(value : Enumerable)
    check_enumerable(value)
    byte_offset = 0

    value.each do |elem|
      byte_offset += yield elem
    end

    byte_offset
  end

  # workaround to reject unions of `Enumerable`s
  private def self.check_enumerable(x : T) forall T
    {% unless T.ancestors.any? { |t| t.name(generic_args: false) == "Enumerable" } %}
      {% T.raise "T must be an unambiguous Enumerable, not a union of Enumerables" %}
    {% end %}
  end

  def self.pack_num(type : T.class, value : T) forall T
    yield value
  end

  def self.pack_num_count(type : T.class, value : Enumerable(T), count : Int) forall T
    check_enumerable(value)
    if count > 0
      value.each do |elem|
        pack_num(type, elem) { |x| yield x }
        count -= 1
        break if count <= 0
      end
      raise IndexError.new("not enough elements") unless count == 0
    end
  end

  def self.pack_num_star(type : T.class, value : Enumerable(T)) forall T
    check_enumerable(value)
    count = 0
    value.each do |elem|
      pack_num(type, elem) { |x| yield x }
      count += 1
    end
    count
  end

  def self.pack_ber(io, value : Int::Primitive)
    if value < 0
      raise ArgumentError.new("can't pack negative numbers with 'w' directive")
    end

    digits = value.digits(128)
    last = digits.shift

    digits.reverse_each do |digit|
      io.write_byte(digit.to_u8! | 0x80_u8)
    end
    io.write_byte(last.to_u8!)

    digits.size
  end

  def self.pack_ber(io, value : BigInt)
    if value < 0
      raise ArgumentError.new("can't pack negative numbers with 'w' directive")
    end

    if value == 0
      io.write_byte(0)
      return 1
    end

    digits = Array(UInt8).new
    while value != 0
      digits << value.remainder(128).to_u8!
      value = value.tdiv(128)
    end

    last = digits.shift
    digits.reverse_each do |digit|
      io.write_byte(digit | 0x80_u8)
    end
    io.write_byte(last)

    digits.size
  end

  def self.pack_bitstring_lsb(io, str : String, len : Int)
    raise IndexError.new("not enough elements") unless len <= str.size
    if len > 0
      count = 0
      b = 0_u8
      str.each_char do |ch|
        b <<= 1
        b |= ch.to_i(2)
        count += 1
        break if count >= len
        if count % 8 == 0
          io.write_byte(b)
          b = 0_u8
        end
      end
      io.write_byte(b)
    end
    (len + 7) // 8
  end

  def self.pack_bitstring_msb(io, str : String, len : Int)
    raise IndexError.new("not enough elements") unless len <= str.size
    if len > 0
      count = 0
      b = 0_u8
      str.each_char do |ch|
        i = count % 8
        b |= ch.to_i(2) << (7 - i)
        count += 1
        break if count >= len
        if i == 7
          io.write_byte(b)
          b = 0_u8
        end
      end
      io.write_byte(b)
    end
    (len + 7) // 8
  end

  def self.pack_hexstring_lsb(io, str : String, len : Int)
    raise IndexError.new("not enough elements") unless len <= str.size
    if len > 0
      count = 0
      b = 0_u8
      str.each_char do |ch|
        i = count % 2
        b |= ch.to_i(16) << (i * 4)
        count += 1
        break if count >= len
        if count % 2 == 0
          io.write_byte(b)
          b = 0_u8
        end
      end
      io.write_byte(b)
    end
    (len + 1) // 8
  end

  def self.pack_hexstring_msb(io, str : String, len : Int)
    raise IndexError.new("not enough elements") unless len <= str.size
    if len > 0
      count = 0
      b = 0_u8
      str.each_char do |ch|
        i = count % 2
        b |= ch.to_i(16) << (4 - i * 4)
        count += 1
        break if count >= len
        if i == 1
          io.write_byte(b)
          b = 0_u8
        end
      end
      io.write_byte(b)
    end
    (len + 1) // 8
  end

  macro do_pack1(io, byte_offset, arg, command)
    {% p [arg, command] if false %}

    {% directive = command[:directive] %}
    {% endianness = command[:endianness] %}

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
        elsif command[:bang]
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

      {% converter = ::IO::ByteFormat.constant(endianness || :SystemEndian) %}

      {% if count = command[:count] %}
        ::Pack::PackImpl.pack_num_count({{ value_type }}, {{ arg }}, {{ count }}) do |value|
          {{ io }}.write_bytes(value, {{ converter }})
        end
        {{ byte_offset }} += sizeof({{ value_type }}) * {{ count }}
      {% elsif command[:glob] %}
        {{ byte_offset }} += sizeof({{ value_type }}) * ::Pack::PackImpl.pack_num_star({{ value_type }}, {{ arg }}) { |value|
          {{ io }}.write_bytes(value, {{ converter }})
        }
      {% else %}
        ::Pack::PackImpl.pack_num({{ value_type }}, {{ arg }}) do |value|
          {{ io }}.write_bytes(value, {{ converter }})
        end
        {{ byte_offset }} += sizeof({{ value_type }})
      {% end %}

    {% elsif directive == 'w' %}
      {% if count = command[:count] %}
        {{ byte_offset }} += ::Pack::PackImpl.pack_with_count({{ arg }}, {{ count }}) do |elem|
          ::Pack::PackImpl.pack_ber({{ io }}, elem)
        end
      {% elsif command[:glob] %}
        {{ byte_offset }} += ::Pack::PackImpl.pack_with_star({{ arg }}) do |elem|
          ::Pack::PackImpl.pack_ber({{ io }}, elem)
        end
      {% else %}
        {{ byte_offset }} += ::Pack::PackImpl.pack_ber({{ io }}, {{ arg }})
      {% end %}

    {% elsif "bBhH".includes?(directive) %}
      {% if directive == 'b' %}
        {% packer = "pack_bitstring_lsb".id %}
      {% elsif directive == 'B' %}
        {% packer = "pack_bitstring_msb".id %}
      {% elsif directive == 'h' %}
        {% packer = "pack_hexstring_lsb".id %}
      {% elsif directive == 'H' %}
        {% packer = "pack_hexstring_msb".id %}
      {% end %}

      {% if command[:glob] %}
        %arg = {{ arg }}
        {{ byte_offset }} += ::Pack::PackImpl.{{ packer }}({{ io }}, %arg, %arg.size)
      {% else %}
        {{ byte_offset }} += ::Pack::PackImpl.{{ packer }}({{ io }}, {{ arg }}, {{ command[:count] || 1 }})
      {% end %}

    {% else %}
      # UaAZbBhHumMpP@xX
      {% raise "BUG: unknown directive #{directive}" %}
    {% end %}
  end
end

module Pack
  macro pack_to(io, fmt, *args)
    {% if fmt.is_a?(Path) %}
      {% fmt = fmt.resolve %}
    {% end %}
    {% unless fmt.is_a?(StringLiteral) %}
      {% fmt.raise "format must be a string literal or constant" %}
    {% end %}

    {% commands = [] of ASTNode %}
    {% current = {directive: nil} %}

    {% chars = fmt.chars %}
    {% chars << ' ' %}
    {% accepts_modifiers = false %}

    {% for ch, index in chars %}
      {% if "cCsSlLqQiIjJnNvVdfFeEgGUwaAZbBhHumMpP@xX \n\t\f\v\r".includes?(ch) %}
        {% if current[:directive] %}
          {% current[:name] = chars[current[:index]...index].join("") %}
          {% commands << current %}
        {% end %}

        {% current = {directive: nil, index: index} %}
        {% accepts_modifiers = false %}

        {% unless " \n\t\f\v\r".includes?(ch) %}
          {% current[:directive] = ch %}
          {% accepts_modifiers = "sSlLqQjJiI".includes?(ch) %}
        {% end %}

      {% elsif ch == '_' || ch == '!' %}
        {% fmt.raise "#{ch} allowed only after directives sSiIlLqQjJ" unless accepts_modifiers %}
        {% fmt.raise "#{ch} allowed only before '*' and count" if current[:glob] || current[:count] %}
        {% current[:bang] = true %}

      {% elsif ch == '<' %}
        {% fmt.raise "#{ch} allowed only after directives sSiIlLqQjJ" unless accepts_modifiers %}
        {% fmt.raise "#{ch} allowed only before '*' and count" if current[:glob] || current[:count] %}
        {% fmt.raise "can't use both '<' and '>'" if current[:endianness] == :BigEndian %}
        {% current[:endianness] = :LittleEndian %}
      {% elsif ch == '>' %}
        {% fmt.raise "#{ch} allowed only after directives sSiIlLqQjJ" unless accepts_modifiers %}
        {% fmt.raise "#{ch} allowed only before '*' and count" if current[:glob] || current[:count] %}
        {% fmt.raise "can't use both '<' and '>'" if current[:endianness] == :LittleEndian %}
        {% current[:endianness] = :BigEndian %}

      {% elsif ch == '*' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless current[:directive] %}
        {% fmt.raise "#{ch} not allowed for '@'" if current[:directive] == '@' %}
        {% fmt.raise "#{ch} not allowed for 'P'" if current[:directive] == 'P' %}
        {% fmt.raise "can't use both '*' and count" if current[:count] %}
        {% current[:glob] = true %}

      {% elsif ch == '0' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless current[:directive] %}
        {% fmt.raise "can't use both '*' and count" if current[:glob] %}
        {% current[:count] = (current[:count] || 0) * 10 + 0 %}
      {% elsif ch == '1' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless current[:directive] %}
        {% fmt.raise "can't use both '*' and count" if current[:glob] %}
        {% current[:count] = (current[:count] || 0) * 10 + 1 %}
      {% elsif ch == '2' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless current[:directive] %}
        {% fmt.raise "can't use both '*' and count" if current[:glob] %}
        {% current[:count] = (current[:count] || 0) * 10 + 2 %}
      {% elsif ch == '3' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless current[:directive] %}
        {% fmt.raise "can't use both '*' and count" if current[:glob] %}
        {% current[:count] = (current[:count] || 0) * 10 + 3 %}
      {% elsif ch == '4' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless current[:directive] %}
        {% fmt.raise "can't use both '*' and count" if current[:glob] %}
        {% current[:count] = (current[:count] || 0) * 10 + 4 %}
      {% elsif ch == '5' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless current[:directive] %}
        {% fmt.raise "can't use both '*' and count" if current[:glob] %}
        {% current[:count] = (current[:count] || 0) * 10 + 5 %}
      {% elsif ch == '6' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless current[:directive] %}
        {% fmt.raise "can't use both '*' and count" if current[:glob] %}
        {% current[:count] = (current[:count] || 0) * 10 + 6 %}
      {% elsif ch == '7' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless current[:directive] %}
        {% fmt.raise "can't use both '*' and count" if current[:glob] %}
        {% current[:count] = (current[:count] || 0) * 10 + 7 %}
      {% elsif ch == '8' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless current[:directive] %}
        {% fmt.raise "can't use both '*' and count" if current[:glob] %}
        {% current[:count] = (current[:count] || 0) * 10 + 8 %}
      {% elsif ch == '9' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless current[:directive] %}
        {% fmt.raise "can't use both '*' and count" if current[:glob] %}
        {% current[:count] = (current[:count] || 0) * 10 + 9 %}

      {% elsif ch == 'D' %}
        {% fmt.raise "long double is not supported, use 'd' instead" %}

      {% else %}
        {% fmt.raise "unexpected directive: #{ch}" %}
      {% end %}
    {% end %}

    %io = ({{ io }}).as(::IO)
    %byte_offset = 0

    {% arg_pos = 0 %}
    {% for command in commands %}
      {% if command[:directive] == 'P' && command[:count] %}
        {% fmt.raise "count not allowed for 'P'" %}
      {% end %}
      {% if arg_pos >= args.size %}
        {% args.raise "missing argument for directive #{name}" %}
      {% end %}
      {% arg = args[arg_pos] %}
      {% arg_pos += 1 %}
      Pack::PackImpl.do_pack1(%io, %byte_offset, {{ arg }}, {{ command }})
    {% end %}

    {% if arg_pos < args.size %}
      {% args.raise "wrong number of values for Pack.pack (expected #{arg_pos}, got #{args.size})" %}
    {% end %}
  end

  macro pack(fmt, *args)
    %io = ::Pack::PackImpl::BytesWriter.new
    ::Pack.pack_to(%io, {{ fmt }}, {{ args.splat }})
    %io.to_slice
  end
end
