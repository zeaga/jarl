package jarl

import "core:time"

Timing :: struct {
	start_time: time.Time,
	last_frame: time.Time,
	run_time: f32,
	delta_time: f32,
	frame_count: u32,
	delta_history: [TIMING_HISTORY_SIZE]f32,
}

timing_init :: proc(timing: ^Timing) {
	timing.start_time = time.now()
	timing.last_frame = timing.start_time
	timing.run_time = 0.0
	timing.delta_time = 0.0
	timing.frame_count = 0
	for i in 0..<TIMING_HISTORY_SIZE {
		timing.delta_history[i] = 0.0
	}
}

timing_update :: proc(timing: ^Timing) {
	current_time := time.now()
	timing.delta_time = cast(f32)time.duration_seconds(time.diff(timing.last_frame, current_time))
	timing.run_time = cast(f32)time.duration_seconds(time.diff(timing.start_time, current_time))
	timing.last_frame = current_time
	timing.delta_history[timing.frame_count % TIMING_HISTORY_SIZE] = timing.delta_time
	timing.frame_count += 1
}

timing_get_fps :: proc(timing: ^Timing) -> f32 {
	sum: f32 = 0.0
	count := min(timing.frame_count, TIMING_HISTORY_SIZE)
	for i in 0..<count {
		sum += timing.delta_history[i]
	}
	avg_delta := sum / cast(f32)count
	if avg_delta > 0.0 {
		return 1.0 / avg_delta
	} else {
		return 0.0
	}
}