
require 'tokenizer'

class Op
  def numeric_literal? text
    text =~ /^_?\d+/
  end

  def to_numeric text
     return text.to_i if text =~ /^\d+/
     -(text[1...text.length]).to_i
  end
end

class Tally < Op
  REP = '#'
  def run ary, interpreter
    [ary.count]
  end
end


class Shape < Op
  REP = '$'
  def run ary, interpreter
    elements = interpreter.tokens.reverse
    interpreter.advance(elements.length)
    return generate_matrix(elements, ary) if numeric_literal?(elements[0]) && numeric_literal?(elements[1])
    []
  end

  private

  def fill_matrix ranges, elements
    return elements.next if ranges.size <= 0
    (0...ranges.first).map { fill_matrix(ranges.drop(1), elements) }
  end

  def generate_matrix elements, ary
    ranges = elements.take_while {|n| numeric_literal?(n) }.map(&:to_i)
    fill_matrix(ranges, ary.cycle.each)
  end

end


class Take < Op
  REP = '{.'
  def run ary, interpreter
    if interpreter.tokens.size > 0 && numeric_literal?(interpreter.tokens[0])
      number = to_numeric(interpreter.tokens[0])
      interpreter.advance(1)
      if number >= 0
        ary.take(number)
      else
        ary.reverse.take(-number).reverse
      end
     else
       ary.take(1)
     end
  end
end


class Jop
  attr_reader :tokens

  def initialize command_text
    @command_text = command_text
    @tokens = Tokenizer.new(command_text).tokens.reverse
    gather_operators
  end

  def gather_operators
    @operators = []
    ObjectSpace.each_object(::Class) {|klass| @operators << klass.new if klass < Op }
  end

  def numeric_literal? text
    text =~ /^_?\d+/
  end

  def to_numeric text
     return text.to_i if text =~ /^\d+/
     -(text[1...text.length]).to_i
  end

  def grade_up ary
    ary.zip(0...ary.length).sort_by {|e| e[0] }.map {|e| e[1] }
  end

  def grade_down ary
    grade_up(ary).reverse
  end

  def advance amount
    @tokens = @tokens[amount...@tokens.length]
  end

  def eval_on ary
    result = ary
    while not @tokens.empty?
      result = eval_op(result)
    end
    result
  end

  def eval_op ary
    op = @tokens[0]
    advance(1)
    case op
    when '{.'
      Take.new.run(ary, self)
    when '}.'
      if @tokens.size > 0 && numeric_literal?(@tokens[0])
        number = to_numeric(@tokens[0])
        advance(1)
        if number >= 0
          ary.drop(number)
        else
          ary.reverse.drop(-number).reverse
        end
      else
        ary.drop(1)
      end
    when '|.'
      if @tokens.size > 0 && numeric_literal?(@tokens[0])
        number = to_numeric(@tokens[0])
        advance(1)
        segment_length = number % ary.length
        segment = ary.take(segment_length)
        ary.drop(segment_length) + segment
      else
        ary.reverse
      end
    # when '#'
    #  Tally.new.run(ary, self)
    when '+/'
      ary.reduce(:+)
    when '*/'
      ary.reduce(:*)
    when "/:~"
      ary.sort
    when '\:~'
      ary.sort.reverse
    when '/:'
      grade_up(ary)
    when '\:'
      grade_down(ary)
    when '<:'
      ary.map {|e| e - 1 }
    when '>:'
      ary.map {|e| e + 1 }
    when '%'
      ary.map {|e| 1 / e.to_f }
    when '-.'
      ary.map {|e| 1 - e }
    when '+:'
      ary.map {|e| e * 2 }
    when '-:'
      ary.map {|e| e / 2.0 }
    when '+/\\'
      sum = 0
      ary.each_with_object([]) {|e, ac| sum = sum + e; ac << sum }
    when '{:'
      [ary.drop(ary.count-1).first]
    when '}:'
      ary.take(ary.count-1)
    when '*'
      ary.map {|e| e <=> 0 }
    when '^'
      ary.map {|n| Math::exp(n) }
    when '*:'
      ary.map {|e| e ** 2 }
    when '<.'
      ary.map {|e| e.floor }
    when '>.'
      ary.map {|e| e.ceil }
    when '$'
      Shape.new.run(ary, self)
    else
      selected = @operators.select {|op_class| op_class.class::REP == op }
      selected.first.run(ary, self) if selected.size == 1
    end
  end
end

class Array
  def j command_text
    Jop.new(command_text).eval_on(self)
  end
end





