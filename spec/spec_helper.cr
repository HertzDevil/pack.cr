require "spec"
require "../src/pack"

struct EqualExactlyExpectation(T)
  def initialize(@expected_value : T)
  end

  def match(actual_value)
    actual_value.class == @expected_value.class && actual_value == @expected_value
  end

  def failure_message(actual_value)
    "Expected: #{@expected_value.inspect} : #{@expected_value.class}\n     got: #{actual_value.inspect} : #{actual_value.class}"
  end

  def negative_failure_message(actual_value)
    "Expected: actual_value != #{@expected_value.inspect} : #{@expected_value.class}\n     got: #{actual_value.inspect} : #{actual_value.class}"
  end
end

def eq_exactly(value)
  EqualExactlyExpectation.new value
end

struct Slice(T)
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
