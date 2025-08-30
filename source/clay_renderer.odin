package game
import clay "../lib/clay-odin"
import "core:math"
import la "core:math/linalg"
import "core:mem"
import rl "vendor:raylib"

clay_color_to_raylib_color :: proc(color: clay.Color) -> rl.Color {
	return rl.Color(la.to_u8(la.round(color)))
}
// Camera Raylib_camera;

CustomLayoutElementType :: enum {
	CUSTOM_LAYOUT_ELEMENT_TYPE_3D_MODEL,
}

CustomLayoutElement_3DModel :: struct {
	model:    rl.Model,
	scale:    f32,
	position: rl.Vector3,
	rotation: rl.Matrix,
}

CustomLayoutElement :: union {
	CustomLayoutElement_3DModel,
}

// Get a ray trace from the screen position (i.e mouse) within a specific section of the screen
GetScreenToWorldPointWithZDistance :: proc(
	position: rl.Vector2,
	camera: rl.Camera,
	screenWidth, screenHeight: int,
	zDistance: f32,
) -> rl.Ray {

	// Calculate normalized device coordinates
	// NOTE: y value is negative
	x: f32 = (2.0 * position.x) / f32(screenWidth) - 1.0
	y: f32 = 1.0 - (2.0 * position.y) / f32(screenHeight)
	z: f32 = 1.0

	// Store values in a vector
	deviceCoords: [3]f32 = {x, y, z}

	// Calculate view matrix from camera look at
	matView := rl.MatrixLookAt(camera.position, camera.target, camera.up)
	matProj := rl.Matrix(1)

	aspect := f32(f64(screenWidth) / f64(screenHeight))
	if (camera.projection == .PERSPECTIVE) {
		// Calculate projection matrix from perspective
		matProj = rl.MatrixPerspective(camera.fovy * rl.DEG2RAD, aspect, 0.01, zDistance)
	} else if (camera.projection == .ORTHOGRAPHIC) {
		top := camera.fovy / 2.0
		right := top * aspect

		// Calculate projection matrix from orthographic
		matProj = rl.MatrixOrtho(-right, right, -top, top, 0.01, 1000.0)
	}

	// Unproject far/near points
	nearPoint := rl.Vector3Unproject([3]f32{deviceCoords.x, deviceCoords.y, 0.0}, matProj, matView)
	farPoint := rl.Vector3Unproject([3]f32{deviceCoords.x, deviceCoords.y, 1.0}, matProj, matView)

	// Calculate normalized direction vector
	direction: [3]f32 = la.normalize0(farPoint - nearPoint)

	ray := rl.Ray {
		position  = farPoint,
		direction = direction,
	}

	return ray
}

draw_rectangle_from_floats :: proc(posX, posY, width, height: f32, color: rl.Color) {
	rl.DrawRectangle(
		i32(math.round_f32(posX)),
		i32(math.round_f32(posY)),
		i32(math.round_f32(width)),
		i32(math.round_f32(height)),
		color,
	)
}


Raylib_MeasureText :: #force_inline proc(
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	fonts: [^]rl.Font,
) -> clay.Dimensions {
	// Measure string size for Font
	textHeight := config.fontSize
	fontToUse := fonts[config.fontId]

	// Font failed to load, likely the fonts are in the wrong place relative to the execution dir.
	// RayLib ships with a default font, so we can continue with that built in one.
	if fontToUse.glyphs == nil {
		fontToUse = rl.GetFontDefault()
	}

	scaleFactor := f32(config.fontSize) / f32(fontToUse.baseSize)

	maxTextWidth: f32 = 0.0
	lineTextWidth: f32 = 0.0
	maxLineCharCount := 0
	lineCharCount := 0
	for i in 0 ..< text.length {
		character := text.chars[i]
		if character == '\n' {
			maxTextWidth = max(maxTextWidth, lineTextWidth)
			maxLineCharCount = max(maxLineCharCount, lineCharCount)
			lineTextWidth = 0
			lineCharCount = 0
			continue
		}
		index := character - 32
		if fontToUse.glyphs[index].advanceX !=
		   0 {lineTextWidth += f32(fontToUse.glyphs[index].advanceX)} else {lineTextWidth += fontToUse.recs[index].width + f32(fontToUse.glyphs[index].offsetX)}
		lineCharCount += 1
	}

	maxTextWidth = max(maxTextWidth, lineTextWidth)
	maxLineCharCount = max(maxLineCharCount, lineCharCount)

	textSize := clay.Dimensions {
		width  = maxTextWidth * scaleFactor + f32(lineCharCount * int(config.letterSpacing)),
		height = f32(textHeight),
	}
	return textSize
}

/*
Clay_Raylib_Initialize :: proc(width, height: i32, title: cstring, flags: rl.ConfigFlags) {
	rl.SetConfigFlags(flags)
	rl.InitWindow(width, height, title)
	//    EnableEventWaiting();
}

// A MALLOC'd buffer, that we keep modifying inorder to save from so many Malloc and Free Calls.
// Call Clay_Raylib_Close() to free
staticchar * temp_render_buffer = NULL
staticinttemp_render_buffer_len = 0

// Call after closing the window to clean up the render buffer
void Clay_Raylib_Close()
{
    if(temp_render_buffer) free(temp_render_buffer);
    temp_render_buffer_len = 0;

    CloseWindow();
    }*/


Clay_Raylib_Render :: proc(
	renderCommands: ^clay.ClayArray(clay.RenderCommand),
	fonts: [^]rl.Font,
) {
	for j in 0 ..< renderCommands.length {
		renderCommand := clay.RenderCommandArray_Get(renderCommands, j)
		boundingBox := clay.BoundingBox {
			math.round_f32(renderCommand.boundingBox.x),
			math.round_f32(renderCommand.boundingBox.y),
			math.round_f32(renderCommand.boundingBox.width),
			math.round_f32(renderCommand.boundingBox.height),
		}
		switch renderCommand.commandType {
		case .None:
		case .Text:
			{
				textData := &renderCommand.renderData.text
				fontToUse := fonts[textData.fontId]

				strlen := textData.stringContents.length + 1

				// Raylib uses standard C strings so isn't compatible with cheap slices, we need to clone the string to append null terminator
				render_string := cast(cstring)make([^]u8, strlen, context.temp_allocator)
				mem.copy_non_overlapping(
					rawptr(render_string),
					textData.stringContents.chars,
					int(textData.stringContents.length),
				)
				rl.DrawTextEx(
					fontToUse,
					render_string,
					rl.Vector2{boundingBox.x, boundingBox.y},
					f32(textData.fontSize),
					f32(textData.letterSpacing),
					clay_color_to_raylib_color(textData.textColor),
				)
			}
		case .Image:
			{
				imageTexture := (^rl.Texture2D)(renderCommand.renderData.image.imageData)
				tintColor := renderCommand.renderData.image.backgroundColor
				if (tintColor == [4]f32{0, 0, 0, 0}) {
					tintColor = (clay.Color){255, 255, 255, 255}
				}
				rl.DrawTexturePro(
					imageTexture^,
					rl.Rectangle{0, 0, f32(imageTexture.width), f32(imageTexture.height)},
					rl.Rectangle {
						boundingBox.x,
						boundingBox.y,
						boundingBox.width,
						boundingBox.height,
					},
					rl.Vector2{},
					0,
					clay_color_to_raylib_color(tintColor),
				)
			}
		case .ScissorStart:
			{
				rl.BeginScissorMode(
					i32(math.round_f32(boundingBox.x)),
					i32(math.round_f32(boundingBox.y)),
					i32(math.round_f32(boundingBox.width)),
					i32(math.round_f32(boundingBox.height)),
				)
			}
		case .ScissorEnd:
			{
				rl.EndScissorMode()
			}
		case .Rectangle:
			{
				config := &renderCommand.renderData.rectangle
				if (config.cornerRadius.topLeft > 0) {
					radius :=
						(config.cornerRadius.topLeft * 2) /
						f32(
							boundingBox.height if boundingBox.width > boundingBox.height else boundingBox.width,
						)
					rl.DrawRectangleRounded(
						rl.Rectangle {
							boundingBox.x,
							boundingBox.y,
							boundingBox.width,
							boundingBox.height,
						},
						radius,
						8,
						clay_color_to_raylib_color(config.backgroundColor),
					)
				} else {
					rl.DrawRectangle(
						i32(boundingBox.x),
						i32(boundingBox.y),
						i32(boundingBox.width),
						i32(boundingBox.height),
						clay_color_to_raylib_color(config.backgroundColor),
					)
				}
			}
		case .Border:
			{
				config := &renderCommand.renderData.border
				// Left border
				if (config.width.left > 0) {
					draw_rectangle_from_floats(
						math.round_f32(boundingBox.x),
						math.round_f32(boundingBox.y + config.cornerRadius.topLeft),
						f32(config.width.left),
						boundingBox.height -
						f32(config.cornerRadius.topLeft) -
						f32(config.cornerRadius.bottomLeft),
						clay_color_to_raylib_color(config.color),
					)
				}
				// Right border
				if (config.width.right > 0) {
					draw_rectangle_from_floats(
						boundingBox.x + boundingBox.width - f32(config.width.right),
						boundingBox.y + f32(config.cornerRadius.topRight),
						f32(config.width.right),
						boundingBox.height -
						f32(config.cornerRadius.topRight) -
						f32(config.cornerRadius.bottomRight),
						clay_color_to_raylib_color(config.color),
					)
				}
				// Top border
				if (config.width.top > 0) {
					draw_rectangle_from_floats(
						boundingBox.x + config.cornerRadius.topLeft,
						boundingBox.y,
						boundingBox.width -
						f32(config.cornerRadius.topLeft - config.cornerRadius.topRight),
						f32(config.width.top),
						clay_color_to_raylib_color(config.color),
					)
				}
				// Bottom border
				if (config.width.bottom > 0) {
					draw_rectangle_from_floats(
						boundingBox.x + config.cornerRadius.bottomLeft,
						boundingBox.y + boundingBox.height - f32(config.width.bottom),
						boundingBox.width -
						f32(config.cornerRadius.bottomLeft - config.cornerRadius.bottomRight),
						f32(config.width.bottom),
						clay_color_to_raylib_color(config.color),
					)
				}
				if (config.cornerRadius.topLeft > 0) {
					rl.DrawRing(
						rl.Vector2 {
							math.round_f32(boundingBox.x + config.cornerRadius.topLeft),
							math.round_f32(boundingBox.y + config.cornerRadius.topLeft),
						},
						math.round_f32(config.cornerRadius.topLeft - f32(config.width.top)),
						config.cornerRadius.topLeft,
						180,
						270,
						10,
						clay_color_to_raylib_color(config.color),
					)
				}
				if (config.cornerRadius.topRight > 0) {
					rl.DrawRing(
						rl.Vector2 {
							math.round_f32(
								boundingBox.x + boundingBox.width - config.cornerRadius.topRight,
							),
							math.round_f32(boundingBox.y + config.cornerRadius.topRight),
						},
						math.round_f32(config.cornerRadius.topRight - f32(config.width.top)),
						config.cornerRadius.topRight,
						270,
						360,
						10,
						clay_color_to_raylib_color(config.color),
					)
				}
				if (config.cornerRadius.bottomLeft > 0) {
					rl.DrawRing(
						rl.Vector2 {
							math.round_f32(boundingBox.x + config.cornerRadius.bottomLeft),
							math.round_f32(
								boundingBox.y +
								boundingBox.height -
								config.cornerRadius.bottomLeft,
							),
						},
						math.round_f32(config.cornerRadius.bottomLeft - f32(config.width.bottom)),
						config.cornerRadius.bottomLeft,
						90,
						180,
						10,
						clay_color_to_raylib_color(config.color),
					)
				}
				if (config.cornerRadius.bottomRight > 0) {
					rl.DrawRing(
						rl.Vector2 {
							math.round_f32(
								boundingBox.x +
								boundingBox.width -
								config.cornerRadius.bottomRight,
							),
							math.round_f32(
								boundingBox.y +
								boundingBox.height -
								config.cornerRadius.bottomRight,
							),
						},
						math.round_f32(config.cornerRadius.bottomRight - f32(config.width.bottom)),
						config.cornerRadius.bottomRight,
						0.1,
						90,
						10,
						clay_color_to_raylib_color(config.color),
					)
				}
			}
		case .Custom:
			{
				panic("unimplemented")
				/*
                config := &renderCommand.renderData.custom;
                CustomLayoutElement *customElement = (CustomLayoutElement *)config->customData;
                if (!customElement) continue;
                switch (customElement->type) {
                    case CUSTOM_LAYOUT_ELEMENT_TYPE_3D_MODEL: {
                        Clay_BoundingBox rootBox = renderCommands.internalArray[0].boundingBox;
                        float scaleValue = CLAY__MIN(CLAY__MIN(1, 768 / rootBox.height) * CLAY__MAX(1, rootBox.width / 1024), 1.5f);
                        Ray positionRay = GetScreenToWorldPointWithZDistance((Vector2) { renderCommand->boundingBox.x + renderCommand->boundingBox.width / 2, renderCommand->boundingBox.y + (renderCommand->boundingBox.height / 2) + 20 }, Raylib_camera, (int)roundf(rootBox.width), (int)roundf(rootBox.height), 140);
                        BeginMode3D(Raylib_camera);
                            DrawModel(customElement->customData.model.model, positionRay.position, customElement->customData.model.scale * scaleValue, WHITE);        // Draw 3d model with texture
                        EndMode3D();
                        break;
                    }
                    default: break;
                }
                break;*/
			}
		}
	}
}
