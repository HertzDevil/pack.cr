require "../spec_helper"

private macro it_unpacks(bytes, fmt, *values)
  %result = Pack.unpack({{ bytes }}, {{ fmt }})
  %expected = Tuple.new({{ values.splat }})
  %result.should eq(%expected)
  typeof(%result).should eq(typeof(%expected))
end

FORMAT = ""

describe Pack do
  describe ".unpack" do
    it "accepts string constants" do
      it_unpacks Bytes[], FORMAT
    end

    describe_errors do
      it "disallows non-string literals" do
        expect_error %(Pack.unpack 0, 0), "format must be a string literal or constant"
        expect_error %(Pack.unpack 0, [0]), "format must be a string literal or constant"
        expect_error %(Pack.unpack 0, '0'), "format must be a string literal or constant"
        expect_error %(Pack.unpack 0, {0}), "format must be a string literal or constant"
        expect_error %(Pack.unpack 0, ->{ }), "format must be a string literal or constant"
      end

      it "disallows non-string constants" do
        expect_error %(FOO = 1\nPack.unpack 0, FOO), "format must be a string literal or constant"
      end
    end

    describe "a" do
      it "unpacks Slice(UInt8)'s" do
        it_unpacks Bytes[0x00], "a", Bytes[0x00]
        it_unpacks Bytes[0xAA], "a", Bytes[0xAA]
        it_unpacks Bytes[0x20], "a", Bytes[0x20]
        it_unpacks Bytes[0x0A], "a", Bytes[0x0A]
        it_unpacks Bytes[], "a", Bytes[]

        it_unpacks Bytes[0x00, 0x00], "a2", Bytes[0x00, 0x00]
        it_unpacks Bytes[0x00, 0x20], "a2", Bytes[0x00, 0x20]
        it_unpacks Bytes[0x00, 0x21], "a2", Bytes[0x00, 0x21]
        it_unpacks Bytes[0x01, 0x02, 0x03], "a3", Bytes[0x01, 0x02, 0x03]
        it_unpacks Bytes[0x01, 0x02, 0x03], "a2", Bytes[0x01, 0x02]
        it_unpacks Bytes[0x01, 0x02], "a3", Bytes[0x01, 0x02]

        it_unpacks Bytes[], "a*", Bytes[]
        it_unpacks Bytes[0x01], "a*", Bytes[0x01]
        it_unpacks Bytes[0x00], "a*", Bytes[0x00]
        it_unpacks Bytes[0x00, 0x10, 0x20, 0x30, 0x40], "a*", Bytes[0x00, 0x10, 0x20, 0x30, 0x40]

        it_unpacks Bytes[0x01], "a0", Bytes[]
      end
    end

    describe "A" do
      it "unpacks Slice(UInt8)'s, trims trailing null and ASCII whitespace" do
        it_unpacks Bytes[0x00], "A", Bytes[]
        it_unpacks Bytes[0xAA], "A", Bytes[0xAA]
        it_unpacks Bytes[0x20], "A", Bytes[]
        it_unpacks Bytes[0x0A], "A", Bytes[0x0A]
        it_unpacks Bytes[], "A", Bytes[]

        it_unpacks Bytes[0x00, 0x00], "A2", Bytes[]
        it_unpacks Bytes[0x00, 0x20], "A2", Bytes[]
        it_unpacks Bytes[0x21, 0x20], "A2", Bytes[0x21]
        it_unpacks Bytes[0x00, 0x21], "A2", Bytes[0x00, 0x21]
        it_unpacks Bytes[0x01, 0x02, 0x03], "A3", Bytes[0x01, 0x02, 0x03]
        it_unpacks Bytes[0x01, 0x02, 0x03], "A2", Bytes[0x01, 0x02]
        it_unpacks Bytes[0x01, 0x02], "A3", Bytes[0x01, 0x02]

        it_unpacks Bytes[], "A*", Bytes[]
        it_unpacks Bytes[0x01], "A*", Bytes[0x01]
        it_unpacks Bytes[0x00], "A*", Bytes[]
        it_unpacks Bytes[0x00, 0x10, 0x20, 0x30, 0x40], "A*", Bytes[0x00, 0x10, 0x20, 0x30, 0x40]

        it_unpacks Bytes[0x01], "A0", Bytes[]

        it_unpacks Bytes[0x01, 0x00, 0x20, 0x01], "A*A*", Bytes[0x01, 0x00, 0x20, 0x01], Bytes[]
        it_unpacks Bytes[0x01, 0x00, 0x20, 0x01], "A3A*", Bytes[0x01], Bytes[0x01]
        it_unpacks Bytes[0x01, 0x00, 0x20, 0x01], "A2A*", Bytes[0x01], Bytes[0x20, 0x01]
      end
    end

    describe "Z" do
      it "unpacks Slice(UInt8)'s, stops at first null byte" do
        it_unpacks Bytes[0x00], "Z", Bytes[]
        it_unpacks Bytes[0xAA], "Z", Bytes[0xAA]
        it_unpacks Bytes[0x20], "Z", Bytes[0x20]
        it_unpacks Bytes[0x0A], "Z", Bytes[0x0A]
        it_unpacks Bytes[], "Z", Bytes[]

        it_unpacks Bytes[0x00, 0x00], "Z2", Bytes[]
        it_unpacks Bytes[0x20, 0x00], "Z2", Bytes[0x20]
        it_unpacks Bytes[0x00, 0x21], "Z2", Bytes[]
        it_unpacks Bytes[0x20, 0x21], "Z2", Bytes[0x20, 0x21]
        it_unpacks Bytes[0x01, 0x02, 0x03], "Z3", Bytes[0x01, 0x02, 0x03]
        it_unpacks Bytes[0x01, 0x02, 0x03], "Z2", Bytes[0x01, 0x02]
        it_unpacks Bytes[0x01, 0x02], "Z3", Bytes[0x01, 0x02]

        it_unpacks Bytes[], "Z*", Bytes[]
        it_unpacks Bytes[0x01], "Z*", Bytes[0x01]
        it_unpacks Bytes[0x00], "Z*", Bytes[]
        it_unpacks Bytes[0x00, 0x10, 0x20, 0x30, 0x40], "Z*Z*", Bytes[], Bytes[0x10, 0x20, 0x30, 0x40]
        it_unpacks Bytes[0x01, 0x00, 0x02, 0x00, 0x03, 0x00, 0x04], "Z*Z*Z*Z*", Bytes[0x01], Bytes[0x02], Bytes[0x03], Bytes[0x04]

        it_unpacks Bytes[0x01], "Z0", Bytes[]
      end
    end

    describe "c" do
      it "unpacks Int8's" do
        it_unpacks Bytes[0x00], "c", 0_i8
        it_unpacks Bytes[0x07], "c", 7_i8
        it_unpacks Bytes[0x64], "c", 100_i8
        it_unpacks Bytes[0xFF], "c", -1_i8

        expect_raises(IndexError) { Pack.unpack(Bytes[], "c") }

        it_unpacks Bytes[0x01, 0x02], "c2", Int8.static_array(1, 2)
        it_unpacks Bytes[0x03, 0xC8, 0x04], "c3", Int8.static_array(3, -56, 4)
        it_unpacks Bytes[0x03, 0xC8, 0x04], "c2", Int8.static_array(3, -56)

        expect_raises(IndexError) { Pack.unpack(Bytes[0x00], "c2") }

        it_unpacks Bytes[0x01, 0x02], "c*", Int8[1, 2]
        it_unpacks Bytes[0x03, 0xC8, 0x04], "c*", Int8[3, -56, 4]
        it_unpacks Bytes[], "c*", Int8[]
      end

      describe_errors do
        it "disallows endianness" do
          expect_error %(Pack.unpack 0, "c<"), "'<' allowed only after directives sSiIlLqQjJ"
          expect_error %(Pack.unpack 0, "c>"), "'>' allowed only after directives sSiIlLqQjJ"
        end

        it "disallows native size" do
          expect_error %(Pack.unpack 0, "c_"), "'_' allowed only after directives sSiIlLqQjJ"
          expect_error %(Pack.unpack 0, "c!"), "'!' allowed only after directives sSiIlLqQjJ"
        end
      end
    end

    describe "C" do
      it "unpacks UInt8's" do
        it_unpacks Bytes[0x00], "C", 0_u8
        it_unpacks Bytes[0x07], "C", 7_u8
        it_unpacks Bytes[0x64], "C", 100_u8
        it_unpacks Bytes[0xFF], "C", 255_u8

        expect_raises(IndexError) { Pack.unpack(Bytes[], "C") }

        it_unpacks Bytes[0x01, 0x02], "C2", UInt8.static_array(1, 2)
        it_unpacks Bytes[0x03, 0xC8, 0x04], "C3", UInt8.static_array(3, 200, 4)
        it_unpacks Bytes[0x03, 0xC8, 0x04], "C2", UInt8.static_array(3, 200)

        expect_raises(IndexError) { Pack.unpack(Bytes[0x00], "C2") }

        it_unpacks Bytes[0x01, 0x02], "C*", UInt8[1, 2]
        it_unpacks Bytes[0x03, 0xC8, 0x04], "C*", UInt8[3, 200, 4]
        it_unpacks Bytes[], "C*", UInt8[]
      end
    end

    describe "s" do
      it "unpacks Int16's" do
        it_unpacks Bytes[0x00, 0x00], "s<", 0_i16
        it_unpacks Bytes[0x01, 0x00], "s<", 1_i16
        it_unpacks Bytes[0xE8, 0x03], "s<", 1000_i16
        it_unpacks Bytes[0x00, 0x80], "s<", Int16::MIN

        it_unpacks Bytes[0x00, 0x00], "s>", 0_i16
        it_unpacks Bytes[0x00, 0x01], "s>", 1_i16
        it_unpacks Bytes[0x03, 0xE8], "s>", 1000_i16
        it_unpacks Bytes[0x80, 0x00], "s>", Int16::MIN

        expect_raises(IndexError) { Pack.unpack(Bytes[], "s<") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0x00], "s<") }
        expect_raises(IndexError) { Pack.unpack(Bytes[], "s>") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0x00], "s>") }

        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04], "s<2", Int16.static_array(0x0201, 0x0403)
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06], "s<3", Int16.static_array(0x0201, 0x0403, 0x0605)
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06], "s<2", Int16.static_array(0x0201, 0x0403)

        expect_raises(IndexError) { Pack.unpack(Bytes[0x00], "s<2") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0x00, 0x00], "s<2") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0x00, 0x00, 0x00], "s<2") }

        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04], "s<*", Int16[0x0201, 0x0403]
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06], "s<*", Int16[0x0201, 0x0403, 0x0605]
        it_unpacks Bytes[], "s<*", Int16[]

        it_unpacks Bytes[0x01, 0x02, 0x03], "s<*", Int16[0x0201]
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04, 0x05], "s<*", Int16[0x0201, 0x0403]
        it_unpacks Bytes[0x01], "s<*", Int16[]
      end
    end

    describe "S" do
      it "unpacks UInt16's" do
        it_unpacks Bytes[0x01, 0x02], "S<", 0x0201_u16
        it_unpacks Bytes[0xF1, 0x02], "S>", 0xF102_u16
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04], "S<2", UInt16.static_array(0x0201, 0x0403)
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04], "S>2", UInt16.static_array(0x0102, 0x0304)
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04], "S<*", UInt16[0x0201, 0x0403]
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04], "S>*", UInt16[0x0102, 0x0304]
      end
    end

    describe "l" do
      it "unpacks Int32's" do
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04], "l<", 0x04030201
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04], "l>", 0x01020304
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08], "l<2", Int32.static_array(0x04030201, 0x08070605)
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08], "l>2", Int32.static_array(0x01020304, 0x05060708)
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08], "l<*", [0x04030201, 0x08070605]
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08], "l>*", [0x01020304, 0x05060708]
      end
    end

    describe "L" do
      it "unpacks UInt32's" do
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04], "L<", 0x04030201_u32
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04], "L>", 0x01020304_u32
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08], "L<2", UInt32.static_array(0x04030201, 0x08070605)
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08], "L>2", UInt32.static_array(0x01020304, 0x05060708)
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08], "L<*", UInt32[0x04030201, 0x08070605]
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08], "L>*", UInt32[0x01020304, 0x05060708]
      end
    end

    describe "U" do
      it "unpacks UTF-8 byte sequences as Chars" do
        it_unpacks Bytes[0x00], "U", 0.chr
        it_unpacks Bytes[0x20], "U", ' '
        it_unpacks Bytes[0x64], "U", 'd'
        it_unpacks Bytes[0x7F], "U", 0x7F.chr

        it_unpacks Bytes[0xC2, 0xA2], "U", 0xA2.chr
        it_unpacks Bytes[0xDF, 0xBF], "U", 0x7FF.chr

        it_unpacks Bytes[0xE0, 0xA0, 0x80], "U", 0x800.chr
        it_unpacks Bytes[0xE0, 0xA4, 0xB9], "U", 0x939.chr
        it_unpacks Bytes[0xED, 0x95, 0x9C], "U", 0xD55C.chr

        it_unpacks Bytes[0xF0, 0x90, 0x80, 0x80], "U", 0x10000.chr
        it_unpacks Bytes[0xF0, 0x9F, 0x98, 0x82], "U", '😂'
        it_unpacks Bytes[0xF4, 0x8F, 0xBF, 0xBF], "U", Char::MAX

        expect_raises(IndexError) { Pack.unpack(Bytes[], "U") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0xC2], "U") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0xE1, 0x80], "U") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0xF1, 0x80, 0x80], "U") }

        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0x80], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xC0], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xC1], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xC2, 0x01], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xE0, 0x01], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xE0, 0x80, 0x01], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xE0, 0x80, 0x80], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xED, 0xA0, 0x00], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xED, 0xBF, 0xBF], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xF0, 0x01], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xF0, 0x80, 0x01], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xF0, 0x80, 0x80, 0x01], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xF0, 0x8F, 0xBF, 0xBF], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xF4, 0x90, 0x80, 0x80], "U") }
        expect_raises(InvalidByteSequenceError) { Pack.unpack(Bytes[0xF5], "U") }
      end

      it "unpacks Strings" do
        it_unpacks Bytes[0x00], "U*", "\x00"
        it_unpacks Bytes[0x61, 0xCE, 0xB1, 0xCF, 0x89, 0x7A, 0xF0, 0x9F, 0x98, 0x82], "U*", "aαωz😂"

        it_unpacks Bytes[0x21, 0x20], "U2", "! "
        it_unpacks Bytes[0x61, 0xCE, 0xB1, 0xCF, 0x89, 0x7A, 0xF0, 0x9F, 0x98, 0x82], "U3", "aαω"

        expect_raises(IndexError) { Pack.unpack(Bytes[0x20], "U2") }
      end
    end

    describe "w" do
      it "unpacks BER-compressed UInt64's" do
        it_unpacks Bytes[0x00], "w", 0_u64
        it_unpacks Bytes[0x07], "w", 7_u64
        it_unpacks Bytes[0x64], "w", 100_u64
        it_unpacks Bytes[0x81, 0x0A], "w", 0x8A_u64
        it_unpacks Bytes[0xC0, 0x00], "w", 0x2000_u64
        it_unpacks Bytes[0xFF, 0x7F], "w", 0x3FFF_u64
        it_unpacks Bytes[0x81, 0x80, 0x00], "w", 0x4000_u64
        it_unpacks Bytes[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F], "w", 0x7FFF_FFFF_FFFF_FFFF_u64

        it_unpacks Bytes[0x80, 0x00], "w", 0_u64

        expect_raises(IndexError) { Pack.unpack(Bytes[], "w") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0x80], "w") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0xFF, 0xFF], "w") }

        it_unpacks Bytes[0x81, 0x02, 0x83, 0x84, 0x05], "w2", UInt64.static_array(0x82_u64, 0xC205_u64)
        it_unpacks Bytes[0x81, 0x02, 0x83, 0x84, 0x05, 0x86, 0x87, 0x88, 0x09], "w3", UInt64.static_array(0x82_u64, 0xC205_u64, 0xC1C409_u64)
        it_unpacks Bytes[0x81, 0x02, 0x83, 0x84, 0x05, 0x86, 0x87, 0x88, 0x09], "w2", UInt64.static_array(0x82_u64, 0xC205_u64)

        expect_raises(IndexError) { Pack.unpack(Bytes[0x01], "w2") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0x81, 0x01], "w2") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0x81, 0x01, 0x81], "w2") }

        it_unpacks Bytes[0x81, 0x02, 0x83, 0x84, 0x05], "w*", UInt64[0x82_u64, 0xC205_u64]
        it_unpacks Bytes[0x81, 0x02, 0x83, 0x84, 0x05, 0x86, 0x87, 0x88, 0x09], "w*", UInt64[0x82_u64, 0xC205_u64, 0xC1C409_u64]
        it_unpacks Bytes[], "w*", UInt64[]

        expect_raises(IndexError) { Pack.unpack(Bytes[0x01, 0x80], "w*") }
      end
    end

    describe "h" do
      it "unpacks bytes as hexstring, low nibble first" do
        it_unpacks Bytes[0x00], "h", "0"
        it_unpacks Bytes[0x01], "h", "1"
        it_unpacks Bytes[0x10], "h", "0"
        it_unpacks Bytes[0xAB], "h", "b"

        it_unpacks Bytes[0x00], "h2", "00"
        it_unpacks Bytes[0x01], "h2", "10"
        it_unpacks Bytes[0x10], "h2", "01"
        it_unpacks Bytes[0xAB], "h2", "ba"

        it_unpacks Bytes[0xAB, 0xCD], "h3", "bad"
        it_unpacks Bytes[0xAB, 0xCD], "h4", "badc"

        it_unpacks Bytes[0x12, 0x34, 0x56, 0x78], "h*", "21436587"
        it_unpacks Bytes[], "h*", ""
        it_unpacks Bytes[], "h0", ""

        expect_raises(IndexError) { Pack.unpack(Bytes[], "h") }
        expect_raises(IndexError) { Pack.unpack(Bytes[], "h2") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0x00], "h3") }
      end
    end

    describe "H" do
      it "unpacks bytes as hexstring, high nibble first" do
        it_unpacks Bytes[0x00], "H", "0"
        it_unpacks Bytes[0x01], "H", "0"
        it_unpacks Bytes[0x10], "H", "1"
        it_unpacks Bytes[0xAB], "H", "a"

        it_unpacks Bytes[0x00], "H2", "00"
        it_unpacks Bytes[0x01], "H2", "01"
        it_unpacks Bytes[0x10], "H2", "10"
        it_unpacks Bytes[0xAB], "H2", "ab"

        it_unpacks Bytes[0xAB, 0xCD], "H3", "abc"
        it_unpacks Bytes[0xAB, 0xCD], "H4", "abcd"

        it_unpacks Bytes[0x12, 0x34, 0x56, 0x78], "H*", "12345678"
        it_unpacks Bytes[], "H*", ""
        it_unpacks Bytes[], "H0", ""

        expect_raises(IndexError) { Pack.unpack(Bytes[], "H") }
        expect_raises(IndexError) { Pack.unpack(Bytes[], "H2") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0x00], "H3") }
      end
    end

    describe "b" do
      it "unpacks bytes as bitstring, LSB first" do
        it_unpacks Bytes[0x00], "b", "0"
        it_unpacks Bytes[0x01], "b", "1"
        it_unpacks Bytes[0x12], "b", "0"
        it_unpacks Bytes[0xAB], "b", "1"

        it_unpacks Bytes[0x00], "b2", "00"
        it_unpacks Bytes[0x01], "b2", "10"
        it_unpacks Bytes[0x12], "b2", "01"
        it_unpacks Bytes[0xAB], "b2", "11"

        it_unpacks Bytes[0x00], "b7", "0000000"
        it_unpacks Bytes[0x01], "b7", "1000000"
        it_unpacks Bytes[0x12], "b7", "0100100"
        it_unpacks Bytes[0xAB], "b7", "1101010"

        it_unpacks Bytes[0x00], "b8", "00000000"
        it_unpacks Bytes[0x01], "b8", "10000000"
        it_unpacks Bytes[0x12], "b8", "01001000"
        it_unpacks Bytes[0xAB], "b8", "11010101"

        it_unpacks Bytes[0xAB, 0xCD], "b9", "110101011"
        it_unpacks Bytes[0xAB, 0xCD], "b15", "110101011011001"
        it_unpacks Bytes[0xAB, 0xCD], "b16", "1101010110110011"

        it_unpacks Bytes[0x12, 0x34, 0x56, 0x78], "b*", "01001000001011000110101000011110"
        it_unpacks Bytes[], "b*", ""
        it_unpacks Bytes[], "b0", ""

        it_unpacks Bytes[0xFE, 0x01, 0xFE, 0x01], "bb9b", "0", "100000000", "1"

        expect_raises(IndexError) { Pack.unpack(Bytes[], "b") }
        expect_raises(IndexError) { Pack.unpack(Bytes[], "b2") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0x00], "b9") }
      end
    end

    describe "B" do
      it "unpacks bytes as bitstring, MSB first" do
        it_unpacks Bytes[0x00], "B", "0"
        it_unpacks Bytes[0x80], "B", "1"
        it_unpacks Bytes[0x41], "B", "0"
        it_unpacks Bytes[0xCF], "B", "1"

        it_unpacks Bytes[0x00], "B2", "00"
        it_unpacks Bytes[0x80], "B2", "10"
        it_unpacks Bytes[0x41], "B2", "01"
        it_unpacks Bytes[0xCF], "B2", "11"

        it_unpacks Bytes[0x00], "B7", "0000000"
        it_unpacks Bytes[0x80], "B7", "1000000"
        it_unpacks Bytes[0x41], "B7", "0100000"
        it_unpacks Bytes[0xCF], "B7", "1100111"

        it_unpacks Bytes[0x00], "B8", "00000000"
        it_unpacks Bytes[0x80], "B8", "10000000"
        it_unpacks Bytes[0x41], "B8", "01000001"
        it_unpacks Bytes[0xCF], "B8", "11001111"

        it_unpacks Bytes[0xAB, 0xCD], "B9", "101010111"
        it_unpacks Bytes[0xAB, 0xCD], "B15", "101010111100110"
        it_unpacks Bytes[0xAB, 0xCD], "B16", "1010101111001101"

        it_unpacks Bytes[0x12, 0x34, 0x56, 0x78], "B*", "00010010001101000101011001111000"
        it_unpacks Bytes[], "B*", ""
        it_unpacks Bytes[], "B0", ""

        it_unpacks Bytes[0x7F, 0x80, 0x7F, 0x80], "BB9B", "0", "100000000", "1"

        expect_raises(IndexError) { Pack.unpack(Bytes[], "B") }
        expect_raises(IndexError) { Pack.unpack(Bytes[], "B2") }
        expect_raises(IndexError) { Pack.unpack(Bytes[0x00], "B9") }
      end
    end

    describe "P" do
      it "unpacks Void*'s" do
        it_unpacks Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08], "P", Pointer(Void).new(0x0807060504030201)
      end

      it "unpacks Slice(UInt8)'s" do
        values = Pack.unpack Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08], "P128"
        typeof(values).should eq(Tuple(Slice(UInt8)))
        values.first.to_unsafe.should eq(Pointer(UInt8).new(0x0807060504030201))
        values.first.size.should eq(128)

        values = Pack.unpack Bytes[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08], "P0"
        typeof(values).should eq(Tuple(Slice(UInt8)))
        values.first.to_unsafe.should eq(Pointer(UInt8).new(0x0807060504030201))
        values.first.size.should eq(0)
      end
    end

    it "larger examples" do
      it_unpacks Bytes[
        0x01, 0x02,
        0x03, 0x00, 0x04, 0x00,
        0x05, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00,
      ], "cCsSlL", 1_i8, 2_u8, 3_i16, 4_u16, 5_i32, 6_u32

      it_unpacks Bytes[
        0xFF, 0xFE,
        0xFD, 0xFF, 0xFC, 0xFF,
        0xFB, 0xFF, 0xFF, 0xFF, 0xFA, 0xFF, 0xFF, 0xFF,
      ], "cCsSlL", -1_i8, &-2_u8, -3_i16, &-4_u16, -5_i32, &-6_u32

      it_unpacks Bytes[0x01, 0xE8, 0x03, 0x05, 0xF5, 0xE1, 0x00], "csl>", 1_i8, 1000_i16, 100000000
      it_unpacks "abcd\x00ef\x00".to_slice, "C2Z*a*", StaticArray[97_u8, 98_u8], Bytes[99, 100], Bytes[101, 102, 0]
    end
  end
end
