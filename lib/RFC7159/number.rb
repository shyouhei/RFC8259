#! /your/favourite/path/to/ruby
# -*- coding: utf-8 -*-

# Copyright (c) 2014 Urabe, Shyouhei.  All rights reserved.
#
# Redistribution  and  use  in  source   and  binary  forms,  with  or  without
# modification, are  permitted provided that the following  conditions are met:
#
#     - Redistributions  of source  code must  retain the  above copyright
#       notice, this list of conditions and the following disclaimer.
#
#     - Redistributions in binary form  must reproduce the above copyright
#       notice, this  list of conditions  and the following  disclaimer in
#       the  documentation  and/or   other  materials  provided  with  the
#       distribution.
#
#     - Neither the name of Internet  Society, IETF or IETF Trust, nor the
#       names of specific contributors, may  be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS”
# AND ANY  EXPRESS OR  IMPLIED WARRANTIES, INCLUDING,  BUT NOT LIMITED  TO, THE
# IMPLIED WARRANTIES  OF MERCHANTABILITY AND  FITNESS FOR A  PARTICULAR PURPOSE
# ARE  DISCLAIMED. IN NO  EVENT SHALL  THE COPYRIGHT  OWNER OR  CONTRIBUTORS BE
# LIABLE  FOR   ANY  DIRECT,  INDIRECT,  INCIDENTAL,   SPECIAL,  EXEMPLARY,  OR
# CONSEQUENTIAL  DAMAGES  (INCLUDING,  BUT   NOT  LIMITED  TO,  PROCUREMENT  OF
# SUBSTITUTE  GOODS OR SERVICES;  LOSS OF  USE, DATA,  OR PROFITS;  OR BUSINESS
# INTERRUPTION)  HOWEVER CAUSED  AND ON  ANY  THEORY OF  LIABILITY, WHETHER  IN
# CONTRACT,  STRICT  LIABILITY, OR  TORT  (INCLUDING  NEGLIGENCE OR  OTHERWISE)
# ARISING IN ANY  WAY OUT OF THE USE  OF THIS SOFTWARE, EVEN IF  ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'bigdecimal'

# The Numbers, as described in RFC7159 section 6.
class RFC7159::Number < RFC7159::Value

	# Notie  about technical  design: this  class  _could_ have  been made  much
	# faster if we implement the whole  type-conversion thing by hand.  But that
	# is very  bug-prone.  So to  avoid unnecessary  complexity here we  took an
	# approach to  first let  everything be BigDecimal,  then convert  to others
	# like Float.

	# Parse the AST from parser, and convert into corrsponding values.
	# @param  [::Array] ast    the AST, generated by the parser
	# @return [Number]         evaluated instance
	# @raise  [ArgumentError]  malformed input
	def self.from_ast ast
		type, sign, int, frac, exp = *ast
		raise ArgumentError, "not an object: #{ast.inspect}" if type != :number
		raise ArgumentError, "not a number: #{ast.inspect}" if int.nil?
		new sign, int, frac, exp
	end

	# @return [Numeric] converted numeric
	# @note  this conversion  might  lose  precision.  Use  `to_d`  if you  want
	#   something that fully represents this number.
	def plain_old_ruby_object
		if /\A[+-]?\d+\z/ =~ @to_s
			return to_i
		else
			return to_f
		end
	end

	# @return [BigDecimal] lossless conversion to numeric
	def to_d
		return @to_d
	end

	# @return [::String] the original string
	def to_s
		return @to_s.dup # dup just in case.
	end

	# JSON gem compat
	# @return [::String] the original string
	def to_json *;
		return to_s
	end

	# @return [Float] conversion to float
	def to_f
		# This method must be ideoponent so the result is cached
		unless @to_f
			num = to_d.to_f
			@to_f ||= num # ||= to avoid race
		end
		return @to_f
	end

	# @return [Integer] conversion to integer
	def to_i
		# This method must be ideoponent so the result is cached
		unless @to_i
			num = to_d.to_i
			@to_i ||= num # ||= to avoid race
		end
		return @to_i
	end

	# @return [::String] the value in string
	def inspect
		sprintf "#<%p:%p>", self.class, plain_old_ruby_object
	end

	# For pretty print (require 'pp' beforehand)
	# @param [PP] pp the pp
	def pretty_print pp
		pp.object_group self do
			pp.text ':'
			plain_old_ruby_object.pretty_print pp
		end
	end

	# Number equality is _not_ defined in the RFC so we take liberty of defining
	# that to be mathematical comparison
	def == other
		other == @to_d
	end

	private

	private_class_method:new
	# @private
	def initialize sign, int, frac, exp
		@sign = sign              # nil, '-', or '+'
		@int  = int.join
		@frac = frac && frac.join # nil, or '.dddd..'
		@exp  = exp  && exp.join  # nil, or 'e+ddd..'

		# pre-cache common computations
		@to_s = [@sign, @int, @frac, @exp].join.encode(Encoding::US_ASCII) # this must be OK
		@to_s.freeze # just in case
		@to_d = BigDecimal.new @to_s
	end
end

# 
# Local Variables:
# mode: ruby
# coding: utf-8-unix
# indent-tabs-mode: t
# tab-width: 3
# ruby-indent-level: 3
# fill-column: 79
# default-justification: full
# End:
