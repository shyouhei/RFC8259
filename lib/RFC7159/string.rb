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

# The Strings, as described in RFC7159 section 7.
class RFC7159::String < RFC7159::Value
	# Parse the AST from parser, and convert into corrsponding values.
	# @param  [::Array] ast    the AST, generated by the parser
	# @return [String]         evaluated instance
	# @raise  [ArgumentError]  malformed input
	def self.from_ast ast
		type, *ary = *ast
		raise ArgumentError, "not an object: #{ast.inspect}" if type != :string
		new ary
	end

	# @return [::String] converte string
	def plain_old_ruby_object
		return @str
	end

	alias to_s   plain_old_ruby_object
	alias to_str plain_old_ruby_object

	# @return [::String] the string, escaped
	def inspect
		sprintf "#<%p:%#016x %p>", self.class, self.object_id << 1, @str
	end

	# For pretty print
	# @param [PP] pp the pp
	def pretty_print pp
		hdr = sprintf '#<%p:%#016x', self.class, self.object_id << 1
		pp.group 1, hdr, '>' do
			pp.breakable
			@str.pretty_print pp
		end
	end

	# @return [string] original string
	def to_json *;
		# Here '"', which  is UTF-8, and @orig, which might  be UTF-16, should be
		# aligned.  We  take UTF-8  because we are  not interested  in generating
		# UTF-16 JSON and so on.
		'"' << @orig.flatten.join('').encode(Encoding::UTF_8) << '"'
	end

	# String comparisons are defined in RFC7159 section 8.3.  We follow that.
	def == other
		self.to_str == other.to_str
	rescue NoMethodError
		return false
	end

	private
	private_class_method:new
	# @private
	def initialize ary
		@orig = ary
		enc   = ary[0][0].encoding rescue Encoding::US_ASCII # empty string
		path1 = ary.map do |i|
			case i when Array
				# ['\\', 'u', 'F', 'F', 'E', 'E'] or something
				case i[1].encode(Encoding::US_ASCII)
				when "\x22" then 0x0022 # "    quotation mark  U+0022
				when "\x5C" then 0x005C # \    reverse solidus U+005C
				when "\x2F" then 0x002F # /    solidus         U+002F
				when "\x62" then 0x0008 # b    backspace       U+0008
				when "\x66" then 0x000C # f    form feed       U+000C
				when "\x6E" then 0x000A # n    line feed       U+000A
				when "\x72" then 0x000D # r    carriage return U+000D
				when "\x74" then 0x0009 # t    tab             U+0009
				else "\x75"             # uXXXX                U+XXXX
					i[2..5].join.encode(Encoding::US_ASCII).to_i 16
				end
			else
				i.ord
			end
		end

		# RFC7159 section 8.1  states that the JSON text itself  shall be written
		# in a sort of Unicode.  However  the parsed JSON value's content strings
		# are not always Unicode-valid, according to its section 8.2.  Then what?
		# It says  nothing.  Here, we  try to  preserve the JSON  text's encoding
		# i.e. if  the JSON text  is in UTF-16, we  try UTF-16.  If  that doesn't
		# fit, we give up and take BINARY.
		buf   = nil
		path2 = path1.each_with_object Array.new do |i, r|
			if buf.nil?
				next buf = i
			else
				case buf when 0xD800..0xDBFF
					case i when 0xDC00..0xDFFF
						# valid surrogate pair
						utf16str = [buf, i].pack 'nn'
						utf16str.force_encoding Encoding::UTF_16BE
						r << utf16str[0].ord
						buf = nil # consumed
					else
						# buf is a garbage
						r << buf
						buf = i
					end
				else
					# buf is a normal char
					r << buf
					buf = i
				end
			end
		end
		path2 << buf if buf # buf might remain

		path3 = path2.each_with_object ''.b do |i, r|
			case enc
			when Encoding::UTF_32BE then j = [i].pack 'N'
			when Encoding::UTF_32LE then j = [i].pack 'V'
			when Encoding::UTF_16BE then j = [i].pack 'n'
			when Encoding::UTF_16LE then j = [i].pack 'v'
			else                         j = [i].pack 'U' # sort of UTF-8
			end
			r << j.b
		end
		path4 = path3.dup.force_encoding enc
		# @str = path4.valid_encoding? ? path4 : path3
		@str = path4
		@str.freeze
	end
end

# 
# Dialogue about evaluating JSON's string
# ----
# 2014.03.17.txt:20:50:01 >#ruby-ja@ircnet:shyouhei < JSONのRFC、文字列が"\uDEAD"とかなっててもvalidだよって書いてあるけど、
# 2014.03.17.txt:20:50:14 >#ruby-ja@ircnet:shyouhei < それはいいのだが
# 2014.03.17.txt:20:50:32 >#ruby-ja@ircnet:shyouhei < たとえばそのJSONがUTF-16で書かれているとして
# 2014.03.17.txt:20:50:59 >#ruby-ja@ircnet:shyouhei < UTF-16の"\uDEAD"的なのをRubyで作ろうと思うとなかなかむずかしいな
# 2014.03.17.txt:20:51:55 >#ruby-ja@ircnet:shyouhei < "\\uDEAD"という文字列(ただしUTF-16)を入力したら"\u{DEAD}"という文字列(ただしUTF-16)を出力する関数
# 2014.03.17.txt:20:52:08 >#ruby-ja@ircnet:shyouhei < むずい。
# 2014.03.17.txt:20:52:09 <#ruby-ja@ircnet:nurse    > "\xDE\xAD".force_encoding("utf-16be")とかになっちゃいますなぁ
# 2014.03.17.txt:20:52:34 <#ruby-ja@ircnet:nurse    > [0xDEAD].pack("n").force_encoding("utf-16be")のが素直かな
# 2014.03.17.txt:20:53:35 >#ruby-ja@ircnet:shyouhei < なんか実務上はそこまでがんばるより例外で死んだ方がしあわせになれそうではある
# 2014.03.17.txt:20:54:00 >#ruby-ja@ircnet:shyouhei < 誰も幸せにしなさそう
# 2014.03.17.txt:20:54:26 <#ruby-ja@ircnet:nurse    > 死んじゃダメで、ゲタにするのが正解じゃないっけ
# 2014.03.17.txt:20:54:54 >#ruby-ja@ircnet:shyouhei < それがより正しそうですね
# 2014.03.17.txt:20:55:56 >#ruby-ja@ircnet:shyouhei < JSONはサロゲートペアもなんとかせねばならんので面倒そうだ
# 2014.03.17.txt:20:57:06 >#ruby-ja@ircnet:shyouhei < (\uXYZW が単体でNGぽいくても次にサロゲートペアが続くかもしれん)
# 2014.03.17.txt:20:57:37 >#ruby-ja@ircnet:shyouhei < めんどう！
# 2014.03.17.txt:20:57:42 >#ruby-ja@ircnet:shyouhei < UTF16しねばいいのに
# 2014.03.17.txt:20:59:06 <#ruby-ja@ircnet:nurse    > とりあえずそのままUTF-16にしてみて、encodeでinvalid replaceすればいい気がする
# 2014.03.17.txt:21:00:33 >#ruby-ja@ircnet:shyouhei < すでにUTF16な文字列にサロゲートペアの片割れ的なバイナリをがしょがしょって後ろから足してからencodeするとよしなにする?
# 2014.03.17.txt:21:01:13 >#ruby-ja@ircnet:shyouhei < (頭の悪い発言なのは自覚しております)
# 2014.03.17.txt:21:01:29 <#ruby-ja@ircnet:nurse    > invalid: :replaceつけてUTF-8にするなり、UTF-16のままscrubすれば
# 2014.03.17.txt:21:02:45 >#ruby-ja@ircnet:shyouhei < invalidなのはよいとして "\uFOO\uBAR" てきなサロゲートペアてきJSON文字列をちゃんとRuby的に(正しいUTF16文字列)に復元するシナリオ
# 2014.03.17.txt:21:03:46 <#ruby-ja@ircnet:nurse    > たぶんAScii-8BITで足さないとエラーになる気がする
# 2014.03.17.txt:21:04:05 <#ruby-ja@ircnet:nurse    > そこいがいは、無心につなげて、最後にencodeまたはscrubが正解ではないかと
# 2014.03.17.txt:21:04:13 >#ruby-ja@ircnet:shyouhei < あきらめて全部バイナリと思ってくっつけておいてから最後にencodeか
# 2014.03.17.txt:21:05:20 <#ruby-ja@ircnet:nurse    > ASCII-8BITだと文字列のvalidチェックしない分速いし。
# 2014.03.17.txt:21:06:33 >#ruby-ja@ircnet:shyouhei < 世の中のJSONパーザがUTF16サポートしないという姿勢にはそれなりの理由があることがわかった。
# 2014.03.17.txt:21:07:17 <#ruby-ja@ircnet:nurse    > そもそもHTTPで文字列流すのにASCII非互換ってのが邪悪である
# 2014.03.17.txt:21:15:04 <#ruby-ja@ircnet:nurse    > 例のOpenBSDのsignifyをportableにしたらRubyでも使えるかなぁ
# 2014.03.17.txt:21:18:39 <#ruby-ja@ircnet:nurse    > ていうか卜部さんはJSONパーサでも書いてるのかしら
# 2014.03.17.txt:21:18:56 <#ruby-ja@ircnet:nurse    > って、聞いちゃいけない質問な気がした
# ----
# 2014.03.25.txt:16:08:14 >#ruby-ja@ircnet:shyouhei < "\u{dead}" を入力されたときに "\\uDEAD" を出力する関数を作成せよ
# 2014.03.25.txt:16:09:21 >#ruby-ja@ircnet:shyouhei < str.force_encoding('utf-8').scrub {|c| "\\u" + c.unpack('H*") } はだめぽい
# 2014.03.25.txt:16:14:13 >#ruby-ja@ircnet:shyouhei < primitive_convertでなんとかなるのかこれ
# 2014.03.25.txt:16:20:10 <#ruby-ja@ircnet:n0kada   > "\u{dead}"ってinvalidなんだっけ
# 2014.03.25.txt:16:22:29 >#ruby-ja@ircnet:shyouhei < サロゲートペアのかたほう
# 2014.03.25.txt:16:22:44 >#ruby-ja@ircnet:shyouhei < それだけではinvalidすね
# 2014.03.25.txt:16:34:47 >#ruby-ja@ircnet:shyouhei < お、"\u{dead}".unpack('U*')で0xdeadが取得できる
# 2014.03.25.txt:16:34:57 >#ruby-ja@ircnet:shyouhei < ここからなんとかすればいいのか…?
# 2014.03.25.txt:16:35:00 >#ruby-ja@ircnet:shyouhei < しかしどうする
# 2014.03.25.txt:16:35:08 <#ruby-ja@ircnet:akr      > "\u{dead}".unpack("U*").map {|c| 0xD800 <= c && c <= 0xDFFF ? "\\u%04X" % c : [c].pack("U") }.join
# 2014.03.25.txt:16:38:16 >#ruby-ja@ircnet:shyouhei < おお。
# 2014.03.25.txt:16:38:46 >#ruby-ja@ircnet:shyouhei < scrubでなんとかするのは筋が悪いことが分かりつつある
# 2014.03.25.txt:16:39:36 >#ruby-ja@ircnet:shyouhei < まずは文字列じゃなくてコードポイントの配列にして、そこでごにょってから、さいごに文字列になおすのが色々正しい雰囲気を感じる
# 2014.03.25.txt:16:39:53 <#ruby-ja@ircnet:akr      > encoding が壊れている時に、文字の範囲を確定するのは難しいので。
# 2014.03.25.txt:16:43:08 <#ruby-ja@ircnet:n0kada   > unpackはサロゲートペアの片割れも扱える仕様なんだっけ
# 2014.03.25.txt:16:43:41 <#ruby-ja@ircnet:akr      > 仕様かどうかは知らない
# 2014.03.25.txt:16:44:36 <#ruby-ja@ircnet:akr      > 伝統的に寛大だったとは思う
# 2014.03.25.txt:16:45:41 (#ruby-ja@ircnet:n0kada   ) $ grep -r surrogate spec/rubyspec/core/string/unpack/
# 2014.03.25.txt:16:45:42 (#ruby-ja@ircnet:n0kada   ) bash: exit 1
# 2014.03.25.txt:16:46:06 <#ruby-ja@ircnet:n0kada   > rubyspecが持ってないとは意外だな
# 2014.03.25.txt:16:46:18 <#ruby-ja@ircnet:n0kada   > こういう重箱の隅はお得意だろうに

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
