# typed: strict
# frozen_string_literal: true

class RuboCop::Cop::VariableForce::Variable
  sig { returns(RuboCop::AST::Node) }
  def declaration_node; end
end

class RuboCop::Cop::VariableForce::VariableTable < Object; end
