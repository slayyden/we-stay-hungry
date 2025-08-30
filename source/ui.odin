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

	text_config := clay.TextElementConfig {
		fontSize  = 24,
		textColor = clay.Color{255, 0, 0, 255},
	}
	clay.BeginLayout()
	if clay.UI()(
	{
		id = clay.ID("OuterContainer"),
		layout = {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
			padding = {16, 16, 16, 16},
			childGap = 16,
		},
		backgroundColor = {250, 250, 255, 0},
	},
	) {
		if clay.UI()(
		{
			id = clay.ID("AttackMenuRoot"),
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
				layoutDirection = .TopToBottom,
			},
			floating = {offset = cast([2]f32)menu_state},
			backgroundColor = clay.Color{255, 255, 255, 255},
		},
		) {
			clay.Text("Attack", &text_config)
		}

	}
	return clay.EndLayout()
}
