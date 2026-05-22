package jarl

import "core:fmt"
import lua "vendor:lua/5.4"

LuaVm :: struct {
	state: ^lua.State,
}

lvm_init :: proc(lvm: ^LuaVm) {
	lvm.state = lua.L_newstate()
	lua.open_base(lvm.state)
}

lvm_run_string :: proc(lvm: ^LuaVm, code: cstring) -> (ok: bool) {
	if lua.L_dostring(lvm.state, code) != 0 {
		err := lua.tostring(lvm.state, -1)
		fmt.println(err)
		lua.pop(lvm.state, -1)
		return false
	}
	return true
}

lvm_destroy :: proc(lvm: ^LuaVm) {
	lua.close(lvm.state)
} 