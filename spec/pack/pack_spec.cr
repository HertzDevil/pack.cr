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
  end
end
