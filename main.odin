#+feature dynamic-literals
package calc

import "core:log"
import "core:fmt"
import "core:strings"
import "core:math"
import "core:mem"
import "core:time"

HELP_MESSAGE : string : "INSERT HELP MESSAGE HERE"
VERSION : string : "pre-release"

main :: proc(){

	start_time := time.now()
	
	context.logger = log.create_console_logger()

	// Just to enable some debug stuff
	when ODIN_DEBUG {
		triggered_flags[.print_time] = true
	 	triggered_flags[.print_tree] = true
	}

	// Handle args
	expr, should_run := handle_args()

	if !should_run || string_is_whitespace(expr) do return

	when ODIN_DEBUG do log.info("Calculating value of expression:", expr)

	tokens, tokenize_err := tokenize_expr(expr)

	defer delete(tokens)

	if tokenize_err.kind != .NONE{
		print_tokenize_error(expr, tokenize_err)
		return
	}

	value, parse_err := eval_tokens(tokens)

	if parse_err.kind != .NONE{
		print_parse_error(expr, parse_err)
		return
	}

	if !flag_is_present(.print_tree){ // If we have the tree flag we have already printed the result
		when ODIN_DEBUG do log.info("// PRINTING RESULT //")
		fmt.println(value)
	}

	if flag_is_present(.print_time) do fmt.println("Completed in", time.diff(start_time, time.now()))
}

Constant :: struct{
	name: string,
	value: string,
}

// Define some constants
constants: []Constant = {
	{
		"PI",
		"3.14159265358979323846264338327950288",
	},
	{
		"e",
		"2.71828182845904523536"
	}
}

Error :: enum{
	NONE,
	
	INVALID_CHAR,
	INVALID_CONSTANT,
	NIL_TOKEN_TYPE,

	EXPECTED_CLOSING_PARENTHESIS,
	FAILED_NUMBER_CONVERSION,
	EXPECTED_EXPRESSION_AFTER,
	EXPECTED_EXPRESSION_BEFORE,
}

// ===========
//  TOKENIZER
// ===========

Tokens :: []Token

// A tokens data
Token :: struct{
	type: Token_type,
	value: string,
	pos: int,
}

Tokenize_error :: struct{
	kind: Error, // What type of error is it
	position: int, // Where in the expression is the character(s) causing the error
	char: rune, // Char that is causing the error 
	value: string, // Value that is causing the error
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
		token: Token ={
			type = .NIL,
		}

		switch char{
		case '(':
			token = {
				.OPEN_PARENTHESIS,
				"(",
				current,
			}
			current += 1
		case ')':
			token = {
				.CLOSED_PARENTHESIS,
				")",
				current,
			}
			current += 1
		case '+':
			token = {
				.PLUS_SIGN,
				"+",
				current,
			}
			current += 1
		case '-':
			token = {
				.MINUS_SIGN,
				"-",
				current,
			}
			current += 1
		case '/':
			token = {
				.DIV_SIGN,
				"/",
				current,
			}
			current += 1
		case '*':
			token = {
				.MULT_SIGN,
				"*",
				current,
			}
			current += 1
		case '^':
			token = {
				.EXPONENTIAL_SIGN,
				"^",
				current,
			}
			current += 1
		case:
			// If the char is a number we want to convert the entire number to a token
			if char_is_digit(char){
				number_start := current

				number_cond: for current < len(expr) && char_is_digit(expr[current]){
					current += 1
				}

				// Get the value by using the substring of our expression from the start of the number to the current index
				value := expr[number_start:current]

				token = {
					.NUMBER,
					value,
					number_start,
				}

			} else if char_is_whitespace(char){
				// Skip whitespace
				current += 1
				continue outer
			} else {  // Check for constants
				if !char_is_token(char) {
					word_start := current

					word_cond: for current < len(expr) && !char_is_token(expr[current]){
						current += 1
					}

					// Get the value by using the substring of our expression from the start of the number to the current index
					word := expr[word_start:current]

					word_is_constant: bool = false

					const_check: for constant in constants{
						if word == constant.name{
							word_is_constant = true

							token = {
								type = .NUMBER,
								value = constant.value,
								pos = word_start,
							}
							
							break const_check
						}
					}

					if ! word_is_constant do return tokens[:], Tokenize_error{
						kind = .INVALID_CONSTANT,
						position = word_start,
						value = word,
					}


				}else {
					return tokens[:], Tokenize_error{
						kind     = .INVALID_CHAR,
						position = current,
						char     = rune(char),
					}
				}
			}

		}

		if token.type == .NIL do return tokens[:], Tokenize_error{
			kind 			= .NIL_TOKEN_TYPE,
			position	= current,
			char			= rune(char)
		}

		append(&tokens, token)

		when ODIN_DEBUG do log.info(token)

	}

	return tokens[:], Tokenize_error{kind = .NONE} 
}

// ===================
//  PARSER EXPRESSION
// ===================

Expr_Kind :: enum {
	NUMBER,
	UNARY,
	BINARY,
}

Expr :: struct {
	kind: Expr_Kind,

	value: Value, // NUMBER

	op: Token_type,
	left, right: ^Expr, // BINARY

	expr: ^Expr, // UNARY
}

// Goes through the tree of expressions and collapses it to a single value
eval_expr :: proc(e: ^Expr) -> Value{
	when ODIN_DEBUG do log.debug(e)

	switch e.kind {
	case .NUMBER: // If its a number return the number
		return e.value

	case .UNARY: // If its a unary, calculate the value of that unary and return it
		val := eval_expr(e.expr)

		#partial switch e.op {
		case .MINUS_SIGN:
			return -val
		case .PLUS_SIGN:
			return val
		case:
			panic("Unknown unary operator")
		}

	case .BINARY: // If its a binary, calculate the value of that binary and return it
		left  := eval_expr(e.left)
		right := eval_expr(e.right)

		#partial switch e.op {
		case .PLUS_SIGN:
			return left + right
		case .MINUS_SIGN:
			return left - right
		case .MULT_SIGN:
			return left * right
		case .DIV_SIGN:
			return left / right
		case .EXPONENTIAL_SIGN:
			return math.pow(left, right)
		case:
			panic("Unknown binary operator")
		}
	}

	panic("Unreachable")
}

// ==========
//   PARSER
// ==========

Value :: f64

Parse_error :: struct{
	kind: Error, // What type of error is it
	position: int,
	value: string,
}

Parser :: struct {
	tokens: []Token,
	current: int,
	arena: mem.Dynamic_Arena,
}

// Parses the tokens and evaluates the expr
eval_tokens :: proc(tokens: Tokens) -> (Value, Parse_error){
	// Create the parser
	p := new(Parser)

	p^ = {
		tokens,
		0,
		{},
	}

	// Allocate with a dynamic arena allocator so we can free it all later
	mem.dynamic_arena_init(&p.arena)
	defer{
		mem.dynamic_arena_destroy(&p.arena)
		free(p)
	}


	// Parse the tokens to get an expr
	when ODIN_DEBUG do log.info("Parsing tokens...")
	expr, err := parse_expression(p)

	if err.kind != .NONE do return 0, err

	// Evalue the expr
	when ODIN_DEBUG do log.info("// PRINTING EXPRESSION EVALS //")
	value := eval_expr(expr)

	// Check if we want to print the eval tree
	if flag_is_present(.print_tree){
		fmt.println(colors.cyan, value ,colors.reset)				// Print our value in a nice color
		if unicode_supported() do print_expr_unicode(expr)
		else do print_expr_ascii(expr)
	}

	return value, {kind = .NONE}
}

parse_expression :: proc(p: ^Parser) -> (^Expr, Parse_error) {
	expr, err := parse_term(p)

	if err.kind != .NONE do return expr, err

	for parser_match(p, .PLUS_SIGN, .MINUS_SIGN) {
		op := parser_previous(p).type
		right, err := parse_term(p)

		if err.kind != .NONE do return right, err

		expr = new_binary(p, op, expr, right)
	}

	return expr, {kind = .NONE}
}

parse_term :: proc(p: ^Parser) -> (^Expr, Parse_error) {
	expr, err := parse_power(p)

	if err.kind != .NONE do return expr, err

	for valid_parenthesis_multiplication(p) || parser_match(p, .MULT_SIGN, .DIV_SIGN) {
		op := valid_parenthesis_multiplication(p) ? Token_type.MULT_SIGN : parser_previous(p).type
		right, err := parse_power(p)

		if err.kind != .NONE do return right, err

		expr = new_binary(p, op, expr, right)
	}

	return expr, {kind = .NONE}
}

parse_power :: proc(p: ^Parser) -> (^Expr, Parse_error) {
	expr, err := parse_unary(p)

	if err.kind != .NONE do return expr, err

	if parser_match(p, .EXPONENTIAL_SIGN) {
		op := parser_previous(p).type
		right, err := parse_power(p)

		if err.kind != .NONE do return right, err

		expr = new_binary(p, op, expr, right)
	}

	return expr, {kind = .NONE}
}

parse_unary :: proc(p: ^Parser) -> (^Expr, Parse_error) {
	if parser_match(p, .MINUS_SIGN, .PLUS_SIGN) {
		op := parser_previous(p).type
		right, err := parse_unary(p)
		
		if err.kind != .NONE do return right, err

		return new_unary(p, op, right), {kind = .NONE}
	}

	return parse_primary(p)
}

parse_primary :: proc(p: ^Parser) -> (^Expr, Parse_error) {
	if parser_match(p, .NUMBER) {
		val, ok := f64_from_string(parser_previous(p).value)
		err : Parse_error = ok ? {kind = .NONE} : {
			.FAILED_NUMBER_CONVERSION,
			parser_previous(p).pos,
			parser_previous(p).value
		}

		return new_number(p, val), err
	}

	if parser_match(p, .OPEN_PARENTHESIS) {
		expr, err := parse_expression(p)

		if err.kind != .NONE do return expr, err

		if !parser_match(p, .CLOSED_PARENTHESIS) {
			return expr, {
				.EXPECTED_CLOSING_PARENTHESIS,
				parser_previous(p).pos,
				parser_previous(p).value,
			}
		}

		return expr, {kind = .NONE}
	}

	//Think this is fine
	err : Parse_error = p.current <= 0 ? {
		.EXPECTED_EXPRESSION_BEFORE,
		parser_peek(p).pos-1,
		parser_peek(p).value,
	} : {
		.EXPECTED_EXPRESSION_AFTER,
		parser_previous(p).pos+1,
		parser_previous(p).value,
	}

	return new(Expr, mem.dynamic_arena_allocator(&p.arena)), err
}
