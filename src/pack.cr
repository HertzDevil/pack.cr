require "./pack/pack_impl"
require "./pack/unpack_impl"

# Crystal port of Perl / Ruby's `pack` / `unpack` functions.
module Pack
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
end
