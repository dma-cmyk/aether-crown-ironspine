extends Node
## Dev helper: waits N frames, saves a screenshot and prints frame timings, then quits.
## Args: --capture=<preset> --out=<png> --frames=<n> [--keep]

signal before_capture

var frames := 90
var out_path := ""
var done := false
var _count := 0
var _acc := 0.0
var _n := 0
var _gpu := 0.0
var _cpu := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	frames = int(Game.arg("frames", "90"))
	out_path = Game.arg("out", "user://capture.png")


func _process(delta: float) -> void:
	if done:
		return
	_count += 1
	if _count > frames / 2:
		var rid := get_viewport().get_viewport_rid()
		_acc += delta
		_n += 1
		_gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		_cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
	if _count == frames - 2:
		before_capture.emit()
	if _count >= frames:
		done = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_path)
		print("[capture] saved %s avg_fps=%.1f" % [out_path, _n / maxf(_acc, 0.001)])
		print("[perf] render_cpu_ms=%.2f gpu_ms=%.2f draw_calls=%d prims=%dk" % [_cpu / maxi(_n, 1), _gpu / maxi(_n, 1),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
		if not Game.args.has("keep"):
			get_tree().quit()
