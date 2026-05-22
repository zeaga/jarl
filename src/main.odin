package main

import "core:fmt"

import "jarl"

main :: proc() {
	jarl.app_run({
		window_title = "Noneuclid",
		window_width = 800,
		window_height = 600,
	})
}