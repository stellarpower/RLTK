# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/17
# Description:	This file contains the base class for lexers that use RLTK.

############
# Requires #
############

# Standard Library
require 'strscan'

#######################
# Classes and Modules #
#######################

module RLTK
	class LexingError < Exception
		def initialize(file_offset, line_number, line_offset, remainder)
			@file_offset	= file_offset
			@line_number	= line_number
			@line_offset	= line_offset
			@remainder	= remainder
		end
	end
	
	class Lexer
		attr_accessor :start_state
		
		#################
		# Class Methods #
		#################
		
		@@rules		= Hash.new()
		@@start_state	= :default
		
		class << self
			def rule(pattern, state = :default, flags = [], &action)
				r = Rule.new(pattern, action, state, flags)
				
				if state == :ALL
					@@rules.each_key do |k|
						@@rules[k] << r
					end
				else
					@@rules[state] << r
				end
			end
			
			def start_state(state)
				@@start_state = state
			end
		end
		
		####################
		# Instance Methods #
		####################
		
		def lex(string)
			#Set up the environment for this lexing pass.
			env = Environment.new(@@start_state)
			
			#Offset from start of file.
			file_offset = 0
		
			#Offset from the start of the line.
			line_offset = 0
			line_number = 1
			
			#Empty token list.
			tokens = Array.new()
			
			#The scanner.
			scanner = StringScanner.new(string)
			
			#Start scanning the input string.
			until scanner.eos?
				match = nil
				
				#All rules for the currrent state need to be scanned so
				#that we find the longest match possible.
				@@rules[env.state()].each do |rule|
					if txt = scanner.check(rule.pattern)
						if not match or match[0].length() < txt.length()
							match = [txt, rule]
						end
					end
				end
				
				if match
					rule = match.last()
					
					txt = scanner.scan(rule.pattern)
					type, value = env.instance_exec(txt, &rule.action)
					
					tokens << Token.new(type, value, file_offset, line_number, line_offset, line_offset + txt.length())
					
					#Advance our stat counters.
					file_offset += match.length()
					
					if (newlines = txt.count("\n")) > 0
						line_number += newlines
						line_offset  = 0
					else
						line_offset += match.length()
					end
				else
					error = LexingError.new(file_offset, line_number, line_offset, scanner.peak(-1))
					raise(error, 'Unable to match string with any given rules.')
				end
			end
			
			return tokens << Token.new(:EOF, nil, file_offset, line_number, nil, nil)
		end
		
		def lex_file(file_name)
			file = File.open(file_name, 'r')
			
			lex_string(file.read())
		end
		
		#################
		# Inner Classes #
		#################
		
		class Environment
			def initialize(start_state)
				@state	= [start_state]
				@flags	= Array.new()
			end
			
			def add_state(state)
				@state << state
			end
			
			def pop_state()
				@state.pop()
			end
			
			def set_state(state)
				@state[-1] = state
			end
			
			def state()
				return @state.last()
			end
			
			def set_flag(flag)
				if not @flags.include?(flag)
					@flags << flag
				end
			end
			
			def unset_flag(flag)
				@flags.delete(flag)
			end
			
			def clear_flags()
				@flags = Array.new()
			end
		end
		
		class Rule
			attr_reader :action
			attr_reader :pattern
			
			def initialize(pattern, action, state, flags)
				@pattern	= pattern
				@action	= action
				@state	= state
				@flags	= flags
			end
		end
	end
end
