package calc

import "core:os"
import "core:log"
import "core:fmt"
import "core:strings"

// ============
//   GET ARGS
// ============

handle_args :: proc() -> (expr: string, should_run: bool){

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
char_is_number :: proc(char: u8) -> bool{
	for num in NUMBERS{
		if char == num do return true
	}

	return false
}

// checks if a string is a number
string_is_number :: proc(value: string) -> bool{
	for _, i in value{
		if !char_is_number(value[i]) do return false
	}

	return true
}

char_is_whitespace :: proc(char: u8) -> bool{
	if strings.is_ascii_space(rune(char)) do return true
	else do return false
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
	case .INVALID_CHAR:
		return fmt.tprintf("Invalid character '%v' at position %v", err.char, err.position+1)
	case .INVALID_MULTIPLY_COUNT:
		return fmt.tprintf("Invalid number of '*' characters at position %v-%v", err.position+1, err.position+1+err.span)
	case .SUBSTRING_FAILED:
		return "Internal error while parsing number"
	case:
		return "Unknown tokenizer error"
	}
}

