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

# The Objects, as described in RFC7159 section 4.
class RFC7159::Object < RFC7159::Value

	# Parse the AST from parser, and convert into corrsponding values.
	# @param  [::Array] ast    the AST, generated by the parser
	# @return [Object]         evaluated instance
	# @raise  [ArgumentError]  malformed input
	def self.from_ast ast
		type, *assoc = *ast
		raise ArgumentError, "not an object: #{ast.inspect}" if type != :object
		assoc.map! do |a|
			a.map! do |b|
				RFC7159::Value.from_ast b
			end
		end
		new assoc
	end

	# fetch the key.
	# @note   RFC7159 allows identical key to appear multiple times in an object.
	# @note   This is O(1)
	# @param  [::String, String]  key  key to look at
	# @return [ [Value] ]              corresponding value(s)
	def [] key
		ret = @assoc.select do |(k, v)| k == key end
		ret.map! do |(k, v)| v end
		return ret
	end

	# iterates over the pairs.
	# @yield [key, value] the pair.
	def each_pair
		e = Enumerator.new do |y|
			@assoc.each do |a|
				y << a
			end
		end
		return block_given? ? e.each(&b) : e
	end

	alias each each_pair

	# @raise  [RuntimeError]  keys conflict
	# @return [::Hash]        converted object
	def plain_old_ruby_object
		ret = Hash.new
		@assoc.each do |(k, v)|
			kk = k.plain_old_ruby_object
			if ret.include? kk
				raise RuntimeError, "key #{kk} conflict."
			else
				vv = v.plain_old_ruby_object
				ret.store kk, vv
			end
		end
		return ret
	end

	alias to_h    plain_old_ruby_object
	alias to_hash plain_old_ruby_object

	# @return [::String] the object in string
	def inspect
		hdr = sprintf "#<%p:%#016x {", self.class, self.object_id << 1
		map = @assoc.map do |(k, v)|
			sprintf '%p: %p', k.to_s, v
		end.join ', '
		hdr << map << '}>'
	end

	# For pretty print
	# @param [PP] pp the pp
	def pretty_print pp
		hdr = sprintf '#<%p:%#016x', self.class, self.object_id << 1
		pp.group 1, hdr, '>' do
			pp.breakable
			pp.group 1, '{', '}' do
				@assoc.each_with_index do |(k, v), i|
					pp.breakable ',' if i.nonzero?
					k.to_s.pretty_print pp
					pp.text ': '
					v.pretty_print pp
				end
			end
		end
	end

	private
	private_class_method:new
	# @private
	def initialize assoc
		@assoc = assoc
		@assoc.each {|i| i.freeze }
		@assoc.freeze
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
