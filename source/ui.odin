package game
import clay "../lib/clay-odin"
import "base:runtime"
import "core:c"
import "core:fmt"

error_handler :: proc "c" (errorData: clay.ErrorData) {
	// Do something with the error data.
	context = runtime.default_context()
	fmt.println("CLAY ERROR: ", errorData.errorType)
	fmt.println(errorData.errorText)
	panic("Panicked due to Clay Error")
}
