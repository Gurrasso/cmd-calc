package calc

import "core:os"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:mem"

// ============
//   GET ARGS
// ============

handle_args :: proc() -> (expr: string, should_run: bool){

	if len(os.args) == 0 do return "", false

	// Get the args to check, if the os is windows the first arg will be the path to the exe
	args: []string
	when ODIN_OS == .Windows do args = os.args[1:]
	else do args = os.args

	// TODO: Maybe we want to delete args to clear memory?

	// The expression that we want to calculate
	output: string

	for arg, i in args{

		switch arg{
		case "--help":
			fmt.println(HELP_MESSAGE)
			// If we have the help flag we dont want to run the actual program, so we return false
			return output, false 
		case "--version":
			fmt.println("Version:", VERSION)
			return output, false
		case: 
			// This will join all the args together to give us out expression, this is not perfect but it works for now
			if i == 0 do output = arg
			else do output = strings.join({output, arg}, " ")
		}
	}

	return output, true
}

// ==============
//  TYPE CHECKS
// ==============


NUMBERS : [11]u8: {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.'}

// checks if char is a number, a "." or a + or -
char_is_digit :: proc(char: u8) -> bool{
	for num in NUMBERS{
		if char == num do return true
	}

	return false
}

char_is_whitespace :: proc(char: u8) -> bool{
	return strings.is_ascii_space(rune(char))
}

string_is_whitespace :: proc(str: string) -> bool{
	for char in str{
		if strings.is_ascii_space(char) do continue
		else do return false
	}

	return true
}

// =================
//  ERROR HANDLING
// =================

ANSI_RED   :: "\x1b[31m"
ANSI_RESET :: "\x1b[0m"
ANSI_YELLOW :: "\x1b[33m"
ANSI_BLUE   :: "\x1b[34m"

// Print the error to stderr with some nice formatting
print_tokenize_error :: proc(expr: string, err: Tokenize_error){
	fmt.eprintln(ANSI_RED, "ERROR:", ANSI_RESET, tokenize_error_message(err))

	// Print expression
	fmt.eprintln(" ", expr)

	// Print caret
	fmt.eprintln("", strings.repeat(" ", err.position), strings.repeat("^", max(err.span, 1)))
}

// Get the error message depending on the error
tokenize_error_message :: proc(err: Tokenize_error) -> string{
	#partial switch err.kind{
	case .NONE:
		return fmt.tprintf("No Error at character '%v' at position %v", err.char, err.position+1)
	case .INVALID_CHAR:
		return fmt.tprintf("Invalid character '%v' at position %v", err.char, err.position+1)
	case .NIL_TOKEN_TYPE:
		return fmt.tprintf("Nil token type when tokenizing character '%v' at position %v", err.char, err.position+1)
	case:
		return "Unknown tokenizer error"
	}
}

// Print the error to stderr with some nice formatting
print_parse_error :: proc(expr: string, err: Parse_error){
	fmt.eprintln(ANSI_RED, "ERROR:", ANSI_RESET, parse_error_message(err))

	// Print expression
	fmt.eprintln(" ", expr)

	// Print caret
	fmt.eprintln("", strings.repeat(" ", err.position), strings.repeat("^", max(len(err.value), 1)))
}

// Get the error message depending on the error
parse_error_message :: proc(err: Parse_error) -> string{
	#partial switch err.kind{
	case .NONE:
		return fmt.tprintf("No Error at character '%v' at position %v", err.value, err.position+1)
	case .EXPECTED_CLOSING_PARENTHESIS:
		return fmt.tprintf("Expected closing parenthesis at position %v", err.position+1)
	case .EXPECTED_EXPRESSION:
		return fmt.tprintf("Expected expression after '%v' at position %v", err.value, err.position)
	case .FAILED_NUMBER_CONVERSION:
		if len(err.value) > 1 do return fmt.tprintf("Number conversion failed at '%v', at position %v-%v", err.value, err.position+1, err.position+1+len(err.value))
		else do return fmt.tprintf("Number conversion failed at '%v', at position %v", err.value, err.position+1)
	case:
		return "Unknown tokenizer error"
	}
}

// ================
//  PARSER HELPERS
// ================

// Returns the current token
parser_peek :: proc(p: ^Parser) -> Token {
	return p.tokens[p.current]
}

// Returns the previous token
parser_previous :: proc(p: ^Parser) -> Token {
	return p.tokens[p.current - 1]
}

// Checks if the parser has reached the end
parser_is_at_end :: proc(p: ^Parser) -> bool {
	return p.current >= len(p.tokens)
}

// Advances the parser through the tokens array
parser_advance :: proc(p: ^Parser) -> Token {
	if !parser_is_at_end(p) {
		p.current += 1
	}
	return parser_previous(p)
}

// Checks if the current token is of a certain type
parser_check :: proc(p: ^Parser, t: Token_type) -> bool {
	if parser_is_at_end(p) do return false
	return parser_peek(p).type == t
}

// Checks if the current token is of one of multiple types
parser_match :: proc(p: ^Parser, types: ..Token_type) -> bool {
	for t in types {
		if parser_check(p, t) {
			parser_advance(p)
			return true
		}
	}
	return false
}

// Allocs a number expr with the arena allocator
new_number :: proc(p: ^Parser, value: f64) -> ^Expr {
	e := new(Expr, mem.arena_allocator(&p.arena))
	e^ = {
		kind  = .NUMBER,
		value = value,
	}
	return e
}

// Allocs a unary expr with the arena allocator
new_unary :: proc(p: ^Parser, op: Token_type, expr: ^Expr) -> ^Expr {
	e := new(Expr, mem.arena_allocator(&p.arena))
	e^ = {
		kind = .UNARY,
		op   = op,
		expr = expr,
	}
	return e
}

// Allocs a binary expr with the arena allocator
new_binary :: proc(
	p: ^Parser,
	op: Token_type,
	left, right: ^Expr
) -> ^Expr {
	e := new(Expr, mem.arena_allocator(&p.arena))
	e^ = {
		kind = .BINARY,
		op = op,
		left  = left,
		right = right,
	}
	return e
}

// Converts a string to an f64
f64_from_string :: proc(s: string) -> (f64, bool){
	return strconv.parse_f64(s)
}
