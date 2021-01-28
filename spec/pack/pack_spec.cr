require "../spec_helper"

private macro it_packs(fmt, *values_and_expected)
  {% values = values_and_expected[0..-2] %}
  {% expected = values_and_expected[-1] %}
  Pack.pack({{ fmt }}, {{ values.splat }}).should eq({{ expected }})
end

private def iterator_of(*values)
  values.each
end

describe Pack do
  describe ".pack" do
    describe "c" do
      it "packs Int8's" do
        it_packs "c", 0_i8, Bytes[0x00]
        it_packs "c", 7_i8, Bytes[0x07]
        it_packs "c", 100_i8, Bytes[0x64]
        it_packs "c", -1_i8, Bytes[0xFF]

        x = 3_i8 << 2
        it_packs "c", x, Bytes[0x0C]

        it_packs "ccc", 11, x, 13_i8, Bytes[0x0B, 0x0C, 0x0D]

        it_packs "c2", {1_i8, 2_i8}, Bytes[0x01, 0x02]
        it_packs "c3", [3_i8, 4_i8, 5_i8], Bytes[0x03, 0x04, 0x05]
        it_packs "c2", iterator_of(-5_i8, -10_i8, -15_i8, -20_i8), Bytes[0xFB, 0xF6]

        expect_raises(IndexError) { Pack.pack "c2", {1_i8} }
        expect_raises(IndexError) { Pack.pack "c3", [1_i8, 2_i8] }

        it_packs "c*", {1_i8, 2_i8}, Bytes[0x01, 0x02]
        it_packs "c*", [3_i8, 4_i8, 5_i8], Bytes[0x03, 0x04, 0x05]
        it_packs "c*", iterator_of(-5_i8, -10_i8, -15_i8, -20_i8), Bytes[0xFB, 0xF6, 0xF1, 0xEC]
        it_packs "c*", [] of Int8, Bytes[]
      end
    end

    describe "C" do
      it "packs UInt8's" do
        it_packs "C", 0_u8, Bytes[0x00]
        it_packs "C", 7_u8, Bytes[0x07]
        it_packs "C", 100_u8, Bytes[0x64]
        it_packs "C", &-1_u8, Bytes[0xFF]

        x = 3_u8 << 2
        it_packs "C", x, Bytes[0x0C]

        it_packs "CCC", 11, x, 13_u8, Bytes[0x0B, 0x0C, 0x0D]

        it_packs "C2", {1_u8, 2_u8}, Bytes[0x01, 0x02]
        it_packs "C3", [3_u8, 4_u8, 5_u8], Bytes[0x03, 0x04, 0x05]
        it_packs "C2", iterator_of(&-5_u8, &-10_u8, &-15_u8, &-20_u8), Bytes[0xFB, 0xF6]

        expect_raises(IndexError) { Pack.pack "C2", {1_u8} }
        expect_raises(IndexError) { Pack.pack "C3", [1_u8, 2_u8] }

        it_packs "C*", {1_u8, 2_u8}, Bytes[0x01, 0x02]
        it_packs "C*", [3_u8, 4_u8, 5_u8], Bytes[0x03, 0x04, 0x05]
        it_packs "C*", iterator_of(&-5_u8, &-10_u8, &-15_u8, &-20_u8), Bytes[0xFB, 0xF6, 0xF1, 0xEC]
        it_packs "C*", [] of UInt8, Bytes[]
      end
    end

    describe "b" do
      it "packs bitstrings, LSB first" do
        it_packs "b", "0", Bytes[0b0]
        it_packs "b", "1", Bytes[0b1]

        expect_raises(IndexError) { Pack.pack "b", "" }

        it_packs "b2", "01", Bytes[0b01]
        it_packs "b2", "10", Bytes[0b10]
        it_packs "b2", "11", Bytes[0b11]
        it_packs "b8", "10010110", Bytes[0b10010110]

        expect_raises(IndexError) { Pack.pack "b2", "0" }
        expect_raises(IndexError) { Pack.pack "b3", "00" }

        it_packs "b14", "00010010001101", Bytes[0b00010010, 0b001101]
        it_packs "b16", "0001001000110100", Bytes[0b00010010, 0b00110100]
        it_packs "b14", "0001001000110100", Bytes[0b00010010, 0b001101]

        it_packs "b*", "1", Bytes[0b1]
        it_packs "b*", "00010010001101", Bytes[0b00010010, 0b001101]
        it_packs "b*", "0001001000110100", Bytes[0b00010010, 0b00110100]
        it_packs "b*", "", Bytes[]
      end
    end

    describe "B" do
      it "packs bitstrings, MSB first" do
        it_packs "B", "0", Bytes[0b00000000]
        it_packs "B", "1", Bytes[0b10000000]

        expect_raises(IndexError) { Pack.pack "B", "" }

        it_packs "B2", "01", Bytes[0b01000000]
        it_packs "B2", "10", Bytes[0b10000000]
        it_packs "B2", "11", Bytes[0b11000000]
        it_packs "B8", "10010110", Bytes[0b10010110]

        expect_raises(IndexError) { Pack.pack "B2", "0" }
        expect_raises(IndexError) { Pack.pack "B3", "00" }

        it_packs "B14", "00010010001101", Bytes[0b00010010, 0b00110100]
        it_packs "B16", "0001001000110100", Bytes[0b00010010, 0b00110100]
        it_packs "B14", "0001001000110100", Bytes[0b00010010, 0b00110100]

        it_packs "B*", "1", Bytes[0b10000000]
        it_packs "B*", "00010010001101", Bytes[0b00010010, 0b00110100]
        it_packs "B*", "0001001000110100", Bytes[0b00010010, 0b00110100]
        it_packs "B*", "", Bytes[]
      end
    end

    describe "h" do
      it "packs hexstrings, low nibble first" do
        it_packs "h", "0", Bytes[0x0]
        it_packs "h", "1", Bytes[0x1]
        it_packs "h", "f", Bytes[0xF]
        it_packs "h", "F", Bytes[0xF]

        expect_raises(IndexError) { Pack.pack "h", "" }

        it_packs "h2", "ab", Bytes[0xBA]
        it_packs "h2", "Ba", Bytes[0xAB]
        it_packs "h8", "13579bdf", Bytes[0x31, 0x75, 0xB9, 0xFD]

        expect_raises(IndexError) { Pack.pack "h2", "0" }
        expect_raises(IndexError) { Pack.pack "h3", "00" }

        it_packs "h3", "abc", Bytes[0xBA, 0xC]
        it_packs "h4", "abcd", Bytes[0xBA, 0xDC]
        it_packs "h3", "abcd", Bytes[0xBA, 0xC]

        it_packs "h*", "1", Bytes[0x1]
        it_packs "h*", "12", Bytes[0x21]
        it_packs "h*", "34567", Bytes[0x43, 0x65, 0x7]
        it_packs "h*", "", Bytes[]
      end
    end

    describe "H" do
      it "packs hexstrings, high nibble first" do
        it_packs "H", "0", Bytes[0x00]
        it_packs "H", "1", Bytes[0x10]
        it_packs "H", "f", Bytes[0xF0]
        it_packs "H", "F", Bytes[0xF0]

        expect_raises(IndexError) { Pack.pack "H", "" }

        it_packs "H2", "ab", Bytes[0xAB]
        it_packs "H2", "Ba", Bytes[0xBA]
        it_packs "H8", "13579bdf", Bytes[0x13, 0x57, 0x9B, 0xDF]

        expect_raises(IndexError) { Pack.pack "H2", "0" }
        expect_raises(IndexError) { Pack.pack "H3", "00" }

        it_packs "H3", "abc", Bytes[0xAB, 0xC0]
        it_packs "H4", "abcd", Bytes[0xAB, 0xCD]
        it_packs "H3", "abcd", Bytes[0xAB, 0xC0]

        it_packs "H*", "1", Bytes[0x10]
        it_packs "H*", "12", Bytes[0x12]
        it_packs "H*", "34567", Bytes[0x34, 0x56, 0x70]
        it_packs "H*", "", Bytes[]
      end
    end
  end
end
