# pack.cr

Provides compile-time Crystal macros that mimic Perl and Ruby's `pack` and
`unpack` functions.

Format strings are parsed and translated into sequences of appropriate reads or
writes during compilation, with full type checking for packing and without "any
type" unions for unpacking.

## Usage

```crystal
require "pack"

# The following:
Pack.unpack buf, "c2S!>a*"

# roughly expands to:
def unpack(buf : Bytes)
  byte_offset = 0

  sz = sizeof(Int8)
  value1 = StaticArray(Int8, 2).new do |i|
    IO::ByteFormat::SystemEndian.decode(Int8, buf[byte_offset + sz * i, sz])
  end
  byte_offset += sz * 2

  sz = sizeof(UInt16)
  value2 = IO::ByteFormat::BigEndian.decode(UInt16, buf[byte_offset, sz])
  byte_offset += sz

  elem_count = buf.size - byte_offset
  value3 = buf[byte_offset, elem_count]
  byte_offset += elem_count

  Tuple.new(value1, value2, value3)
end

x1, x2, x3 = Pack.unpack Bytes[0x01, 0xC8, 0x03, 0x04], "cCs"
x1 # => 1_i8
x2 # => 200_u8
x3 # => 1027_i16

x1, x2 = Pack.unpack Bytes[0x41, 0x42, 0x43, 0x31, 0x32, 0x33], "a2U*"
x1 # => Bytes[65, 66]
x2 # => "C123"
```

### Current features

* [ ] Packing
* [ ] Unpacking
  * [x] Fixed-size integral types (`c` `C` `s` `S` `l` `L` `q` `Q` `n` `N` `v` `V`)
  * [x] Native integral types (`i` `I` `l` `L` `j` `J`)
  * [x] Native size modifiers (`_` `!`)
  * [x] Endianness modifiers (`<` `>`)
  * [x] Floating-point types (`d` `f` `F` `e` `E` `g` `G`)
  * [x] BER-compressed integers (`w`)
  * [x] Binary strings (`a` `A` `Z`)
  * [x] UTF-8 characters / strings (`U` `U*`)
  * [x] Bitstrings and hexstrings (`b` `B` `h` `H`)
  * [x] Raw pointers and slices (`p` `P`)
  * [ ] UU-encoded strings (`u`)
  * [ ] Base64-encoded strings (`m` `M`)
  * [ ] String lengths (`/`)
  * [x] Offset directives (`@` `x` `X`)
  * [ ] Aligned offsets (`x!` `X!`)
  * [x] Repeat counts and globs (`*`)
  * [ ] Unpacking directly from readable & rewindable `IO`?

### Non-features (probably)

* Runtime format strings
* Long double (`D`)
* Signed modifier (`!`) for `n` `N` `v` `V`
* Endianness modifiers (`<` `>`) for `d` `f` `F`
* Checksums (`%`)
* Command groups (`(` `)` `.`)

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     pack.cr:
       github: HertzDevil/pack.cr
   ```

2. Run `shards install`

## See also

* [crystal-lang/crystal#276](https://github.com/crystal-lang/crystal/issues/276)
* ["Crystal equivalent of Ruby’s open(url).read[].unpack?"](https://forum.crystal-lang.org/t/crystal-equivalent-of-rubys-open-url-read-unpack/2667)
* [Prior attempt](https://github.com/Fusion/crystal-pack)
* [perlpacktut](https://perldoc.perl.org/perlpacktut)
* [Ruby's String#unpack](https://ruby-doc.org/core-3.0.0/String.html#method-i-unpack)
* [Ruby's Array#pack](https://ruby-doc.org/core-3.0.0/Array.html#method-i-pack)

## Contributing

1. Fork it (<https://github.com/HertzDevil/pack.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

* [Quinton Miller](https://github.com/HertzDevil) - creator and maintainer
