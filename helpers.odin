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

Flags :: enum{
	help,
	version,
	print_tree,
	print_time,
}

Flag_info :: struct {
	flag: string,
	early_exit: bool,
	action: proc(),
}

flag_table : [Flags]Flag_info = {
	.help = {
		"--help",
		true,
		proc(){
			fmt.println(HELP_MESSAGE)
		}
	},
	.version = {
		"--version",
		true,
		proc(){
			fmt.println("Version:", VERSION)
		}
	},
	.print_tree = {
		"--tree",
		false,
		proc() {},
	},
	.print_time = {
		"--time",
		false,
		proc() {},
	}
}

triggered_flags : [Flags]bool = {}

handle_args :: proc() -> (expr: string, should_run: bool){

	args: []string
	args = os.args[1:]

	// Checks if args is empty
	if len(args) == 0 do return "", false

	// TODO: Maybe we want to delete args to clear memory?

	// The expression that we want to calculate
	output: string

	// Check if this arg is a flag
	outer: for arg in args {
		// Check if this arg is a flag
		for info, flag_enum in flag_table {
			if arg == info.flag {
				triggered_flags[flag_enum] = true
				if info.action != nil do info.action()

				if info.early_exit {
					return output, false
				}
				continue outer
			}
		}

		// Not a flag, part of expression
		if output == "" {
			output = arg
		} else {
			output = strings.join({output, arg}, " ")
		}
	}

	return output, true
}

// Checks if we have the tree flag
flag_is_present :: proc(flag: Flags) -> bool{
	return triggered_flags[flag]
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

Color :: struct {
	reset, dim, yellow, cyan, red, green: string
}

colors :: Color{
	reset  = "\x1b[0m",
	dim    = "\x1b[90m",
	yellow = "\x1b[33m",
	cyan   = "\x1b[36m",
	red		 = "\x1b[31m",
	green	 = "\x1b[32m",
}

// Print the error to stderr with some nice formatting
print_tokenize_error :: proc(expr: string, err: Tokenize_error){
	fmt.eprintln(colors.red, "ERROR:", colors.reset, tokenize_error_message(err))

	// Print expression
	fmt.eprintln(" ", expr)

	// Print caret
	fmt.eprintln(strings.repeat(" ", err.position+1), strings.repeat("^", max(err.span, 1)))
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
	fmt.eprintln(colors.red, "ERROR:", colors.reset, parse_error_message(err))

	// Print expression
	fmt.eprintln(" ", expr)

	// Print caret
	fmt.eprintln(strings.repeat(" ", err.position+1), strings.repeat("^", max(len(err.value), 1)))
}

// Get the error message depending on the error
parse_error_message :: proc(err: Parse_error) -> string{
	#partial switch err.kind{
	case .NONE:
		return fmt.tprintf("No Error at character '%v' at position %v", err.value, err.position+1)
	case .EXPECTED_CLOSING_PARENTHESIS:
		return fmt.tprintf("Expected closing parenthesis at position %v", err.position+1)
	case .EXPECTED_EXPRESSION_AFTER:
		return fmt.tprintf("Expected expression after '%v' at position %v", err.value, err.position)
	case .EXPECTED_EXPRESSION_BEFORE:
		return fmt.tprintf("Expected expression before '%v' at position %v", err.value, err.position+2)
	case .FAILED_NUMBER_CONVERSION:
		if len(err.value) > 1 do return fmt.tprintf("Number conversion failed on '%v', at position %v-%v", err.value, err.position+1, err.position+1+len(err.value))
		else do return fmt.tprintf("Number conversion failed on '%v' at position %v", err.value, err.position+1)
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

parser_peek_next :: proc(p: ^Parser) -> Token{
	if p.current >= len(p.tokens) - 1 do return {}
	else do return p.tokens[p.current+1]
}

// Returns the previous token
parser_previous :: proc(p: ^Parser) -> Token {
	return p.tokens[p.current - 1]
}

parser_previous_2 :: proc(p: ^Parser) -> Token {
	if p.current < 2 do return {}
	return p.tokens[p.current - 2]
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

valid_parenthesis_multiplication :: proc(p: ^Parser) -> bool{
	if parser_is_at_end(p) do return false

	if parser_peek(p).type == .OPEN_PARENTHESIS && (parser_previous(p).type == .NUMBER || parser_previous(p).type == .CLOSED_PARENTHESIS) do return true
	else if parser_previous(p).type == .CLOSED_PARENTHESIS && (parser_peek(p).type == .NUMBER || parser_peek(p).type == .OPEN_PARENTHESIS) && (parser_previous_2(p).type == .NUMBER || parser_previous_2(p).type == .CLOSED_PARENTHESIS) do return true

	return false
}


// Allocs a number expr with the arena allocator
new_number :: proc(p: ^Parser, value: f64) -> ^Expr {
	e := new(Expr, mem.dynamic_arena_allocator(&p.arena))
	e^ = {
		kind  = .NUMBER,
		value = value,
	}
	return e
}

// Allocs a unary expr with the arena allocator
new_unary :: proc(p: ^Parser, op: Token_type, expr: ^Expr) -> ^Expr {
	e := new(Expr, mem.dynamic_arena_allocator(&p.arena))
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
	e := new(Expr, mem.dynamic_arena_allocator(&p.arena))
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

// =================
//   VISUALIZATION 
// =================

token_type_to_string :: proc(t: Token_type) -> string {
	#partial switch t {
	case .PLUS_SIGN:        return "+"
	case .MINUS_SIGN:       return "-"
	case .MULT_SIGN:        return "*"
	case .DIV_SIGN:         return "/"
	case .EXPONENTIAL_SIGN: return "^"
	case:                   return "?"
	}
}

// Tries to check if unicode is supported
unicode_supported :: proc() -> bool {
	// Windows Terminal sets this
	if os.get_env("WT_SESSION") != "" {
		return true
	}

	// UTF-8 locale (Unix, macOS, WSL, Linux)
	lang := os.get_env("LANG")
	if strings.contains(lang, "UTF-8") || strings.contains(lang, "utf8") {
		return true
	}

	lc_all := os.get_env("LC_ALL")
	if strings.contains(lc_all, "UTF-8") || strings.contains(lc_all, "utf8") {
		return true
	}

	return false
}

// Prints a tree to visualize the expressions evaluation using unicode characters
print_expr_unicode :: proc(e: ^Expr, prefix: string = "", is_last: bool = true) {
	if e == nil do return

	branch := is_last ? "└─" : "├─"
	fmt.print(prefix, branch)

	switch e.kind {
	case .NUMBER:
		fmt.println(colors.cyan, e.value, colors.reset)

	case .UNARY:
		fmt.println(colors.yellow, token_type_to_string(e.op), colors.reset)
		new_prefix := strings.concatenate({prefix, (is_last ? "  " : "│ ")})
		print_expr_unicode(e.expr, new_prefix, true)

	case .BINARY:
		fmt.println(colors.yellow, token_type_to_string(e.op), colors.reset)
		new_prefix := strings.concatenate({prefix, (is_last ? "  " : "│ ")})
		print_expr_unicode(e.left,  new_prefix, false)
		print_expr_unicode(e.right, new_prefix, true)
	}
}

// Prints a tree to visualize the expressions evaluation using only ascii characters
print_expr_ascii :: proc(e: ^Expr, prefix: string = "", is_last: bool = true) {
	if e == nil do return

	branch := "+--"
	fmt.print(prefix, branch)

	switch e.kind {
	case .NUMBER:
		fmt.println(colors.cyan, e.value, colors.reset)

	case .UNARY:
		fmt.println(colors.yellow, token_type_to_string(e.op), colors.reset)
		new_prefix := strings.concatenate({prefix, (is_last ? "  " : "| ")})
		print_expr_ascii(e.expr, new_prefix, true)

	case .BINARY:
		fmt.println(colors.yellow, token_type_to_string(e.op), colors.reset)
		new_prefix := strings.concatenate({prefix, (is_last ? "  " : "| ")})
		print_expr_ascii(e.left,  new_prefix, false)
		print_expr_ascii(e.right, new_prefix, true)
	}
}
