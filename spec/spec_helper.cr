require "spec"
require "../src/pack"

module PackSpec
  class_property crystal_path : String do
    "#{ENV["CRYSTAL_PATH"]}#{Process::PATH_DELIMITER}#{File.expand_path("#{__DIR__}/../src")}"
  end
end

module Spec::Methods
  def describe_errors(&block)
    describe "compile-time errors", tags: "error", &block
  end
end

def expect_error(code : String, message : String? = nil)
  tempfile = File.tempfile("test", ".cr") do |f|
    f.puts %(require "pack")
    f.puts code
  end
  buffer = IO::Memory.new
  result = Process.run(
    command: "crystal",
    args: ["run", "--no-color", "--no-codegen", tempfile.path],
    env: {"CRYSTAL_PATH" => PackSpec.crystal_path},
    error: buffer,
  )
  result.success?.should be_false
  buffer.to_s.should contain(message) if message
  buffer.close
  tempfile.delete
end

struct Slice(T)
  # allow Bytes[] to produce an empty Slice(UInt8)
  macro [](*args, read_only = false)
    # TODO: there should be a better way to check this, probably
    # asking if @type was instantiated or if T is defined
    {% if @type.name != "Slice(T)" && T < Number %}
      {{T}}.slice({{args.splat ", "}}read_only: {{read_only}})
    {% else %}
      %ptr = Pointer(typeof({{*args}})).malloc({{args.size}})
      {% for arg, i in args %}
        %ptr[{{i}}] = {{arg}}
      {% end %}
      Slice.new(%ptr, {{args.size}}, read_only: {{read_only}})
    {% end %}
  end
end
