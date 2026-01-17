package calc

import "core:os"
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
}

//
// TOKENIZE EXPR
// 

//
// GET ARGS
//

handle_args :: proc() -> (expr: string, should_run: bool){

	// Get the args to check, if the os is windows the first arg will be the path to the exe
	args: []string
	if ODIN_OS == .Windows do args = os.args[1:]
	else do args = os.args

	// TODO: Maybe we want to delete args to clear memory?

	// The expression that we want to calculate
	output: string

	for arg in args{
		switch arg{
		case "--help":
			fmt.println(HELP_MESSAGE)
			// If we have the help flag we dont want to run the actual program, so we return false
			return output, false 
		case: 
			// This will join all the args together to give us out expression, this is not perfect but it works for now
			output = strings.join({output, arg}, " ")
		}
	}

	return output, true
}

