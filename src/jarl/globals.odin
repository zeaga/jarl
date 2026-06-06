package jarl

import "core:math"

DEBUG_MODE :: true

TIMING_HISTORY_SIZE :: 30

IMGUI_ENABLED :: true

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 5
GLSL_VERSION :: "#version 450"

SHADER_DEFAULT_RAY_MAX_STEPS :: 1500
SHADER_DEFAULT_RAY_MAX_DIST :: 200.0
SHADER_DEFAULT_RAY_MAX_TELEPORTS :: 8

euler_to_mat3 :: proc(e: [3]f32) -> matrix[3, 3]f32 {
	r := e * math.RAD_PER_DEG
	cx := math.cos(r.x); sx := math.sin(r.x)
	cy := math.cos(r.y); sy := math.sin(r.y)
	cz := math.cos(r.z); sz := math.sin(r.z)

	ry := matrix[3, 3]f32{
		 cy, 0, sy,
		  0, 1,  0,
		-sy, 0, cy,
	}
	rx := matrix[3, 3]f32{
		1,   0,   0,
		0,  cx, -sx,
		0,  sx,  cx,
	}
	rz := matrix[3, 3]f32{
		 cz, sz, 0,
		-sz, cz, 0,
		  0,  0, 1,
	}
	return ry * rx * rz
}

normalize_rotation_1f32 :: proc(rot: f32) -> f32 {
	rotation := math.mod(math.mod(rot + 180.0, 360.0) + 360.0, 360.0) - 180.0
	return rotation == -180 ? 180 : rotation
}

normalize_rotation_2f32 :: proc(rot: [2]f32) -> (rotation: [2]f32) {
	for i in 0..<2 {
		rotation[i] = normalize_rotation_1f32(rot[i])
	}
	return
}

normalize_rotation_3f32 :: proc(rot: [3]f32) -> (rotation: [3]f32) {
	for i in 0..<3 {
		rotation[i] = normalize_rotation_1f32(rot[i])
	}
	return
}

normalize_rotation :: proc {
	normalize_rotation_1f32,
	normalize_rotation_2f32,
	normalize_rotation_3f32,
}

MouseMode :: enum {
	Normal,
	Hidden,
	Captured,
	Disabled,
}

// SDL3 button values: Left=1, Middle=2, Right=3, X1=4, X2=5
MouseButton :: enum i32 {
	Left   = 1,
	Middle = 2,
	Right  = 3,
	X1     = 4,
	X2     = 5,

	One   = 1,
	Two   = 2,
	Three = 3,
	Four  = 4,
	Five  = 5,

	Last  = 5,
	Count = 6,
}

// SDL3 scancode values (SDL_Scancode)
Key :: enum i32 {
	Unknown = 0,

	/* Named printable keys */
	Space        = 44,
	Apostrophe   = 52,
	Comma        = 54,
	Minus        = 45,
	Period       = 55,
	Slash        = 56,
	Semicolon    = 51,
	Equal        = 46,
	LeftBracket  = 47,
	Backslash    = 49,
	RightBracket = 48,
	GraveAccent  = 53,

	/* Alphanumeric characters */
	D1 = 30,
	D2 = 31,
	D3 = 32,
	D4 = 33,
	D5 = 34,
	D6 = 35,
	D7 = 36,
	D8 = 37,
	D9 = 38,
	D0 = 39,

	A = 4,
	B = 5,
	C = 6,
	D = 7,
	E = 8,
	F = 9,
	G = 10,
	H = 11,
	I = 12,
	J = 13,
	K = 14,
	L = 15,
	M = 16,
	N = 17,
	O = 18,
	P = 19,
	Q = 20,
	R = 21,
	S = 22,
	T = 23,
	U = 24,
	V = 25,
	W = 26,
	X = 27,
	Y = 28,
	Z = 29,

	/* Named non-printable keys */
	Escape      = 41,
	Enter       = 40,
	Tab         = 43,
	Backspace   = 42,
	Insert      = 73,
	Delete      = 76,
	Right       = 79,
	Left        = 80,
	Down        = 81,
	Up          = 82,
	PageUp      = 75,
	PageDown    = 78,
	Home        = 74,
	End         = 77,
	CapsLock    = 57,
	ScrollLock  = 71,
	NumLock     = 83,
	PrintScreen = 70,
	Pause       = 72,

	/* Function keys */
	F1  = 58,
	F2  = 59,
	F3  = 60,
	F4  = 61,
	F5  = 62,
	F6  = 63,
	F7  = 64,
	F8  = 65,
	F9  = 66,
	F10 = 67,
	F11 = 68,
	F12 = 69,
	F13 = 104,
	F14 = 105,
	F15 = 106,
	F16 = 107,
	F17 = 108,
	F18 = 109,
	F19 = 110,
	F20 = 111,
	F21 = 112,
	F22 = 113,
	F23 = 114,
	F24 = 115,

	/* Keypad numbers */
	Kp1 = 89,
	Kp2 = 90,
	Kp3 = 91,
	Kp4 = 92,
	Kp5 = 93,
	Kp6 = 94,
	Kp7 = 95,
	Kp8 = 96,
	Kp9 = 97,
	Kp0 = 98,

	/* Keypad named function keys */
	KpDecimal  = 99,
	KpDivide   = 84,
	KpMultiply = 85,
	KpSubtract = 86,
	KpAdd      = 87,
	KpEnter    = 88,
	KpEqual    = 103,

	/* Modifier keys */
	LeftControl  = 224,
	LeftShift    = 225,
	LeftAlt      = 226,
	LeftSuper    = 227,
	RightControl = 228,
	RightShift   = 229,
	RightAlt     = 230,
	RightSuper   = 231,
	Menu         = 118,

	Last  = 231,
	Count = 512, // SDL_SCANCODE_COUNT
}