require "./pack/pack_impl"
require "./pack/unpack_impl"

# Crystal port of Perl / Ruby's `pack` / `unpack` functions.
#
# The basic usage is `Pack.pack_to` for writing to an `IO`, and `Pack.unpack`
# for reading from a `Bytes`. The function `Pack.pack` writes to a new `Bytes`
# and returns it.
#
# ```
# require "pack"
#
# Pack.unpack Bytes[0x01, 0xC8, 0x03, 0x04], "cCs" # => {1_i8, 200_u8, 1027_i16}
# Pack.pack "csl>", 42_i8, -1000_i16, 1 << 31      # => Bytes[42, 24, 252, 128, 0, 0, 0]
# ```
#
# The format string consists of any number of commands, which consist of a
# directive (usually indicating the type of value to be read or written),
# optionally followed by an integer count or a glob (`*`). Whitespaces between
# commands are ignored, but must not appear in the middle of a command. The
# directives are classified as below:
#
# * [Fixed-size integers](#fixed-size-integers) (`c` `C` `s` `S` `l` `L` `q` `Q` `n` `N` `v` `V`)
# * [Native integers](#native-integers) (`i` `I` `j` `J`)
# * [Floating-point values](#floating-point-values) (`d` `f` `F` `e` `E` `g` `G`)
# * BER-compressed integers (`w`)
# * Binary strings (`a` `A` `Z`)
# * UTF-8 characters / strings (`U` `U*`)
# * Bitstrings and hexstrings (`b` `B` `h` `H`)
# * Raw pointers and slices (`p` `P`)
# * UU-encoded strings (`u`)
# * Base64-encoded strings (`m` `M`)
#
# ### Fixed-size integers
#
# These directives pack and unpack values of type `T`, where `T` <
# `Int::Primitive`. The type `T` depends on the directive being used:
#
# * `Int8`: `c`
# * `UInt8`: `C`
# * `Int16`: `s`
# * `UInt16`: `S`
# * `Int32`: `l`
# * `UInt32`: `L`
# * `Int64`: `q`
# * `UInt64`: `Q`
#
# Due to auto-casting, compatible integer literals are allowed during packing:
#
# ```
# Pack.pack("cs", 1, 1) # => Bytes[1, 1, 0]
# ```
#
# These directives obey the system endianness, unless an endianness modifier is
# supplied. `<` and `>` force the command to use little-endian and big-endian
# respectively. The two modifiers cannot be specified in the same command.
#
# The `_` or `!` modifier forces the command to use native-size integers
# instead. See [Native integers](#native-integers) for the corresponding integer
# types used.
#
# The following aliases are defined:
#
# * `n` is equivalent to `S>` (stands for network byte order)
# * `N` is equivalent to `L>`
# * `v` is equivalent to `S<` (stands for
#   [VAX](https://en.wikipedia.org/wiki/VAX) byte order)
# * `V` is equivalent to `L<`
#
# Endianness and native-size modifiers are not allowed after `c`, `C`, `n`, `N`,
# `v`, and `V`.
#
# Repeat counts are supported. Unpacking produces values of type
# `StaticArray(T, N)`, where `N` is the count specified in the command. Packing
# accepts any `Enumerable` that is a collection of the appropriate element type.
# If the value does not contain as many elements as specified, `IndexError` is
# raised.
#
# Globs are supported. Unpacking produces values of type `Array(T)`. Packing
# accepts any `Enumerable` that is a collection of the appropriate element type.
#
# ### Native integers
#
# These directives pack and unpack values of type `T`, where `T` <
# `Int::Primitive`. The type `T` depends on the directive being used:
#
# * `LibC::Short`: `s!`
# * `LibC::UShort`: `S!`
# * `LibC::Int`: `i` `i!`
# * `LibC::UInt`: `I` `I!`
# * `LibC::Long`: `l!`
# * `LibC::ULong`: `L!`
# * `LibC::LongLong`: `q!`
# * `LibC::ULongLong`: `Q!`
# * `LibC::Int64T`: `j` `j!` (stands for C's `intptr_t`)
# * `LibC::UInt64T`: `J` `J!` (stands for C's `uintptr_t`)
#
# Endianness modifiers are allowed on all of them, and have the same effect as
# fixed-size integers.
#
# Native-size modifiers are allowed on all of them, including `i`, `I`, `j`, and
# `J` for completeness.
#
# Repeat counts and globs are supported in the same way as fixed-size integers.
#
# ### Floating-point values
#
# These directives pack and unpack values of type `T`, where `T` <
# `Float::Primitive`. The type `T` depends on the directive being used:
#
# * `Float32`: `f` `e` `g`
# * `Float64`: `d` `E` `G`
# * `LibC::Float32`: `F`
#
# The endianness also depends on the directive:
#
# * System endian: `d` `f` `F`
# * Little-endian: `e` `E`
# * Big-endian: `g` `G`
#
# The `D` directive represents a native double-precision value in Ruby but a
# long double value in Perl. To avoid confusion, this library does not support
# `D`, because Crystal doesn't support long doubles.
#
# Endianness and native-size modifiers are not allowed.
#
# Repeat counts and globs are supported in the same way as fixed-size integers.
module Pack
  VERSION = "0.1.0"
end
