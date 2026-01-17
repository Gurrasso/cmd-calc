#+feature dynamic-literals
package calc

import "core:log"
import "core:fmt"
import "core:strings"

HELP_MESSAGE : string : "INSERT HELP MESSAGE HERE"

main :: proc(){
	context.logger = log.create_console_logger()

	// Handle args
	expr, should_run := handle_args()
	if !should_run do return

	if ODIN_DEBUG do log.info("Calculating value of expression:", expr)

	tokens, err := tokenize_expr(expr)

	if err.kind != .NONE{
		print_tokenize_error(expr, err)
		return
	}
}

Error :: enum{
	NONE,
	
	INVALID_CHAR,
	SUBSTRING_FAILED,
	INVALID_MULTIPLY_COUNT,
}

// ===========
//  TOKENIZER
// ===========

Tokens :: []Token

// A tokens data
Token :: struct{
	type: Token_type,
	value: string,
}

Tokenize_error :: struct{
	kind: Error, // What type of error is it
	position: int, // Where in the expression is the character(s) causing the error
	span: int, // How many characters are contributing to the error
	char: rune, // What character is causing the error
}

// The type of a token
Token_type :: enum{
	NIL,

	NUMBER,

	OPEN_PARENTHESIS,
	CLOSED_PARENTHESIS,

	MINUS_SIGN,
	PLUS_SIGN,
	MULT_SIGN,
	DIV_SIGN,

	EXPONENTIAL_SIGN,
}

tokenize_expr :: proc(expr: string) -> (Tokens, Tokenize_error){
	current: int = 0
	tokens := make([dynamic]Token, 0)

	when ODIN_DEBUG do log.info("// PRINTING TOKENS //")

	outer: for current < len(expr){
		char := expr[current]
		token: Token

		switch char{
		case '(':
			token = {
				.OPEN_PARENTHESIS,
				"("
			}
			current += 1
		case ')':
			token = {
				.CLOSED_PARENTHESIS,
				")"
			}
			current += 1
		case '+':
			token = {
				.PLUS_SIGN,
				"+"
			}
			current += 1
		case '-':
			token = {
				.MINUS_SIGN,
				"-"
			}
			current += 1
		case '/':
			token = {
				.DIV_SIGN,
				"/"
			}
			current += 1
		case '*':
			// Check if its a mult sign or an exponential sign
			count: int = 0
			start := current

			mult_cond: for char == '*'{
				count += 1
				if current >= len(expr)-1 {
						current += 1
						break mult_cond
					}
					current += 1
					char = expr[current]
			}

			if count == 1{
				token = {
					.MULT_SIGN,
					"*"
				}
			}else if count == 2{
				token = {
					.EXPONENTIAL_SIGN,
					"**"
				}
			}else { // Too many mult signs
				return tokens[:], Tokenize_error{
					kind     = .INVALID_MULTIPLY_COUNT,
					position = start,
					char     = '*',
					span = count,
				}
			}

		case:
			// If the char is a number we want to convert the entire number to a token
			if char_is_number(char){
				number_start := current

				number_cond: for char_is_number(char){
					if current >= len(expr)-1 {
						current += 1
						break number_cond
					}
					current += 1
					char = expr[current]
				}

				// Get the value by using the substring of our expression from the start of the number to the current index
				value, ok := strings.substring(expr, number_start, current)
				if !ok do return tokens[:], Tokenize_error{
						kind     = .SUBSTRING_FAILED,
						position = number_start,
						span = current-number_start,
					}

				token = {
					.NUMBER,
					value,
				}

			} else if char_is_whitespace(char){
				// Skip whitespace
				current += 1
				continue outer
			} else {  // Not a valid character
				return tokens[:], Tokenize_error{
					kind     = .INVALID_CHAR,
					position = current,
					char     = rune(char),
				}
			}

		}

		append(&tokens, token)

		when ODIN_DEBUG do log.info(token)

	}

	return tokens[:], Tokenize_error{kind = .NONE} 
}

// ==========
//   PARSER
// ==========


