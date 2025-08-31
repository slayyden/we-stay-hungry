package game
import clay "../lib/clay-odin"
import "base:runtime"
import "core:fmt"
import "core:math"
import "core:slice"
import rl "vendor:raylib"

UIElementType :: enum {
	ACTION_MENU,
	TURN_ORDER,
	STAT,
}

ClickData :: struct {
	action: Action,
}

end_turn_button :: proc "c" (
	elementId: clay.ElementId,
	pointerInfo: clay.PointerData,
	userData: rawptr,
) {
	if rl.IsMouseButtonPressed(.LEFT) {
		g.turn += 1
		g.click_consumed = true
		g.attack_menu = nil
	}
}
handle_button_interaction :: proc "c" (
	elementId: clay.ElementId,
	pointerInfo: clay.PointerData,
	userData: rawptr,
) {
	context = runtime.default_context()
	click_data := cast(^ClickData)userData
	// fmt.println("pointer_info:", pointerInfo)
	if rl.IsMouseButtonPressed(.LEFT) {
		//if pointerInfo.state == .PressedThisFrame {
		g.hover_state.selected_action = click_data.action
		fmt.println(g.hover_state.selected_action)
		g.click_consumed = true
		g.attack_menu = nil
	}
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
) -> (
	clay.ClayArray(clay.RenderCommand),
	bool,
) {
	font_size := u16(math.round_f32(f32(rl.GetScreenHeight()) / 20.0))
	text_config := clay.TextElementConfig {
		fontSize      = font_size,
		textColor     = clay.Color{255, 0, 0, 255},
		letterSpacing = 1,
	}

	clay.SetPointerState(rl.GetMousePosition(), rl.IsMouseButtonDown(.LEFT))
	hovered := clay.PointerOver(clay.GetElementId(clay.MakeString("AttackMenuRoot")))


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
				sizing = {width = clay.SizingFit({}), height = clay.SizingFit({})},
				layoutDirection = .TopToBottom,
			},
			floating = {
				parentId = clay.GetElementId(clay.MakeString("OuterContainer")).id,
				offset = cast([2]f32)menu_state,
				attachTo = .Parent,
			},
			backgroundColor = clay.Color{255, 255, 255, 255},
		},
		) {
			if clay.UI()(
			{
				layout = {
					sizing = {
						width = clay.SizingGrow({}),
						height = clay.SizingFixed(f32(text_config.fontSize) / 4.0),
					},
					layoutDirection = .LeftToRight,
				},
				backgroundColor = clay.Color{0, 0, 0, 255},
			},
			) {}
			if clay.UI()(
			{
				layout = {
					sizing = {width = clay.SizingFit({}), height = clay.SizingFit({})},
					layoutDirection = .TopToBottom,
					padding = {
						left = font_size / 4,
						right = font_size / 4,
						top = font_size / 8,
						bottom = font_size / 8,
					},
					childGap = font_size / 8,
				},
				backgroundColor = clay.Color{0, 0, 0, 0},
			},
			) {
				if clay.UI()(
				{
					layout = {sizing = {width = clay.SizingGrow({})}},
					backgroundColor = clay.Color{0, 255, 0, 25 if clay.Hovered() else 0},
				},
				) {

					clay.OnHover(handle_button_interaction, &attack_click_data)
					clay.Text("Attack", &text_config)
				}
				if clay.UI()(
				{
					layout = {sizing = {width = clay.SizingGrow({})}},
					backgroundColor = clay.Color{0, 255, 0, 25 if clay.Hovered() else 0},
				},
				) {
					clay.OnHover(handle_button_interaction, &move_click_data)
					clay.Text("Move", &text_config)
				}
				if clay.UI()(
				{
					layout = {sizing = {width = clay.SizingGrow({})}},
					backgroundColor = clay.Color{0, 255, 0, 25 if clay.Hovered() else 0},
				},
				) {
					clay.OnHover(end_turn_button, nil)
					clay.Text("End Turn", &text_config)
				}
			}
			if clay.UI()(
			{
				layout = {
					sizing = {
						width = clay.SizingGrow({}),
						height = clay.SizingFixed(f32(text_config.fontSize) / 4.0),
					},
					layoutDirection = .LeftToRight,
				},
				backgroundColor = clay.Color{0, 0, 0, 255},
			},
			) {}
		}

	}
	return clay.EndLayout(), hovered
}
