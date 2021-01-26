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

  # workaround to reject unions of `Enumerable`s
  private def self.check_enumerable(x : T) forall T
    {% unless T.ancestors.any? { |t| t.name(generic_args: false) == "Enumerable" } %}
      {% T.raise "T must be an unambiguous Enumerable, not a union of Enumerables" %}
    {% end %}
  end

  # accesses `io` and `byte_offset` from outer scope
  # defines `elem_count` in outer scope
  macro do_pack1(arg, directive, native_size, endianness, count, glob)
    {% p [arg, directive, native_size, endianness, count, glob] if false %}

    {% if "cCsSlLqQiIjJnNvVdfFeEgG".includes?(directive) %}
      {% if directive == 'n' %}
        {% directive, endianness = 'S', :BigEndian %}
      {% elsif directive == 'N' %}
        {% directive, endianness = 'L', :BigEndian %}
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

      {% if count %}
        ::Pack::PackImpl.pack_num_count({{ value_type }}, {{ arg }}, {{ count }}) do |value|
          io.write_bytes(value, {{ converter }})
        end
        byte_offset += sizeof({{ value_type }}) * {{ count }}
      {% elsif glob %}
        elem_count = ::Pack::PackImpl.pack_num_star({{ value_type }}, {{ arg }}) do |value|
          io.write_bytes(value, {{ converter }})
        end
        byte_offset += sizeof({{ value_type }}) * elem_count
      {% else %}
        ::Pack::PackImpl.pack_num({{ value_type }}, {{ arg }}) do |value|
          io.write_bytes(value, {{ converter }})
        end
        byte_offset += sizeof({{ value_type }})
      {% end %}

    {% else %}
      # UwaAZbBhHumMpP@xX
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

    {% directive = nil %}
    {% native_size = false %}
    {% endianness = :SystemEndian %}
    {% count = nil %}
    {% glob = false %}

    {% chars = fmt.chars %}
    {% chars << ' ' %}
    {% arg_pos = 0 %}
    {% accepts_modifiers = false %}

    {% directive_start = nil %}

    io = ({{ io }}).as(::IO)
    byte_offset = 0

    {% for ch, index in chars %}
      {% if "cCsSlLqQiIjJnNvVdfFeEgGUwaAZbBhHumMpP@xX \n\t\f\v\r".includes?(ch) %}
        {% if directive %}
          {% if arg_pos >= args.size %}
            {% args.raise "missing argument for directive #{chars[directive_start...index].join("")}" %}
          {% end %}
          {% arg = args[arg_pos] %}
          {% arg_pos += 1 %}
          Pack::PackImpl.do_pack1({{ arg }}, {{ directive }}, {{ native_size }}, {{ endianness }}, {{ count }}, {{ glob }})
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
        {% fmt.raise "count not allowed for 'P'" if directive == 'P' %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 0 : 0 %}
      {% elsif ch == '1' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "count not allowed for 'P'" if directive == 'P' %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 1 : 1 %}
      {% elsif ch == '2' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "count not allowed for 'P'" if directive == 'P' %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 2 : 2 %}
      {% elsif ch == '3' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "count not allowed for 'P'" if directive == 'P' %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 3 : 3 %}
      {% elsif ch == '4' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "count not allowed for 'P'" if directive == 'P' %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 4 : 4 %}
      {% elsif ch == '5' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "count not allowed for 'P'" if directive == 'P' %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 5 : 5 %}
      {% elsif ch == '6' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "count not allowed for 'P'" if directive == 'P' %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 6 : 6 %}
      {% elsif ch == '7' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "count not allowed for 'P'" if directive == 'P' %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 7 : 7 %}
      {% elsif ch == '8' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "count not allowed for 'P'" if directive == 'P' %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 8 : 8 %}
      {% elsif ch == '9' %}
        {% fmt.raise "#{ch} allowed only after a directive" unless directive %}
        {% fmt.raise "count not allowed for 'P'" if directive == 'P' %}
        {% fmt.raise "can't use both '*' and count" if glob %}
        {% count = count ? count * 10 + 9 : 9 %}

      {% elsif ch == 'D' %}
        {% fmt.raise "long double is not supported, use 'd' instead" %}

      {% else %}
        {% fmt.raise "unexpected directive: #{ch}" %}
      {% end %}
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
