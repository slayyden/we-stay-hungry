package game
import clay "../lib/clay-odin"
import "base:runtime"
import "core:fmt"
import "core:slice"

UIElementType :: enum {
	ACTION_MENU,
	TURN_ORDER,
	STAT,
}

error_handler :: proc "c" (errorData: clay.ErrorData) {
	// Do something with the error data.
	context = runtime.default_context()
	fmt.println("CLAY ERROR: ", errorData.errorType)
	fmt.println(slice.from_ptr(errorData.errorText.chars, int(errorData.errorText.length)))
	panic("Panicked due to Clay Error")
}

FloatingMenuState :: distinct [2]f32

action_menu_layout_new :: proc(
	menu_state: FloatingMenuState,
) -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()
	if clay.UI()(
	{
		id = clay.ID("AttackMenuRoot"),
		floating = {offset = cast([2]f32)menu_state, expand = {16, 16}},
		backgroundColor = clay.Color{255, 255, 255, 255},
	},
	) {}
	return clay.EndLayout()
}
