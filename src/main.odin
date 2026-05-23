package main

import "jarl"

main :: proc() {
	jarl.app_run({
		window_title = "Jarl Engine",
		window_width = 1920,
		window_height = 1080,
	})
}