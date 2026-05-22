package jarl

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"
import lua "vendor:lua/5.4"

LuaVm :: struct {
	state: ^lua.State,
}

lvm_create :: proc(lvm: ^LuaVm) {
	lvm.state = lua.L_newstate()
	lua.L_openlibs(lvm.state)

	exe_path := os.args[0]
	exe_dir := filepath.dir(exe_path)

	// setup package.path so we can load from /lua
	lua_path, _ := filepath.join({exe_dir, "lua", "?.lua"}, context.temp_allocator)
	lua.getglobal(lvm.state, "package")
	lua.pushstring(lvm.state, strings.clone_to_cstring(lua_path, context.temp_allocator))
	lua.setfield(lvm.state, -2, "path")
	lua.pop(lvm.state, 1)

	if !lvm_run_string(lvm, #load("res/base.lua")) {
		log.error("Failed to load base.lua")
		return
	}

	// easy way to load main.lua lmao
	lvm_run_string(lvm, "require('main')")
}

lvm_run_string :: proc(lvm: ^LuaVm, code: cstring) -> (ok: bool) {
	if lua.L_dostring(lvm.state, code) != 0 {
		err := lua.tostring(lvm.state, -1)
		log.warn(err)
		lua.pop(lvm.state, 1)
		return false
	}
	return true
}

lvm_run_file :: proc(lvm: ^LuaVm, path: cstring) -> (ok: bool) {
	if lua.L_dofile(lvm.state, path) != 0 {
		err := lua.tostring(lvm.state, -1)
		log.warn(err)
		lua.pop(lvm.state, 1)
		return false
	}
	return true
}

lvm_destroy :: proc(lvm: ^LuaVm) {
	lua.close(lvm.state)
} 