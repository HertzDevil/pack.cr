# pack.cr

![Linux status](https://img.shields.io/github/workflow/status/HertzDevil/pack.cr/Linux%20CI?label=Linux)
![macOS status](https://img.shields.io/github/workflow/status/HertzDevil/pack.cr/macOS%20CI?label=macOS)
![Windows status](https://img.shields.io/github/workflow/status/HertzDevil/pack.cr/Windows%20CI?label=Windows)
![Docs status](https://img.shields.io/github/deployments/HertzDevil/pack.cr/github-pages?label=docs)
![License](https://img.shields.io/github/license/HertzDevil/pack.cr)

This Crystal library provides macros that transform simple values to and from
byte sequences according to compile-time format strings, based on Perl and
Ruby's `pack` and `unpack` functions. Packing enforces full type safety and
unpacking directly returns extracted values in their specified types.

The library is still under early development.

## Usage

### `Pack.pack`

```crystal
require "pack"

# `Pack.pack` returns a new writable `Bytes`
Pack.pack "csl>", 42_i8, -1000_i16, 1 << 31 # => Bytes[42, 24, 252, 128, 0, 0, 0]

# `Pack.pack_to` writes to an `IO` instance
File.open("my.bin", "rb") do |f|
  version = 1_u8
  total_songs = 5_u8
  first_song = 1_u8
  Pack.pack_to f, "U4CCCCS*",
    {'N', 'E', 'S', 'M'}, 0x1A, version, # 0x1A allowed due to auto-casting
    total_songs, first_song, [0x8000, 0xE000, 0xE003] of UInt16
end
```

### `Pack.unpack`

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

# `Pack.unpack` returns a tuple of extracted values
x1, x2, x3 = Pack.unpack Bytes[0x01, 0xC8, 0x03, 0x04], "cCs"
x1 # => 1_i8
x2 # => 200_u8
x3 # => 1027_i16

# No need for further casts
typeof(x1) # => Int8
typeof(x2) # => UInt8
typeof(x3) # => Int16

# Repeat counts and globs become `StaticArray`s and `Array`s
x1, x2 = Pack.unpack Bytes[1, 0, 2, 0, 3, 0], "c2s>*"
x1 # => StaticArray[1_i8, 0_i8]
x2 # => [512_i16, 768_i16]

# Binaries become `Bytes`, UTF-8 values become `Char`s and `String`s
x1, x2, x3 = Pack.unpack Bytes[0x41, 0x42, 0x43, 0x31, 0x32, 0x33, 0x34], "a2U2U*"
x1 # => Bytes[65, 66]
x2 # => "C1"
x3 # => "234"
```

### Current features

* [ ] Packing
  * [x] Fixed-size integral types (`c` `C` `s` `S` `l` `L` `q` `Q` `n` `N` `v` `V`)
  * [x] Native integral types (`i` `I` `l` `L` `j` `J`)
  * [x] Native size modifiers (`_` `!`)
  * [x] Endianness modifiers (`<` `>`)
  * [x] Floating-point types (`d` `f` `F` `e` `E` `g` `G`)
  * [x] BER-compressed integers (`w`)
  * [ ] Binary strings (`a` `A` `Z`)
  * [ ] UTF-8 characters / strings (`U` `U*`)
  * [x] Bitstrings and hexstrings (`b` `B` `h` `H`)
  * [ ] Raw pointers and slices (`p` `P`)
  * [ ] UU-encoded strings (`u`)
  * [ ] Base64-encoded strings (`m` `M`)
  * [ ] String lengths (`/`)
  * [ ] Offset directives (`@` `x` `X`)
  * [ ] Aligned offsets (`x!` `X!`)
  * [x] Repeat counts and globs (`*`)
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
