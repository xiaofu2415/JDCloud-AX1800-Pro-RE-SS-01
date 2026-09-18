module("luci.controller.re_ss_01_quickstart", package.seeall)

local http = require "luci.http"
local jsonc = require "luci.jsonc"
local sys = require "luci.sys"

local temperature_helper = "/usr/libexec/re-ss-01-cpu-temperature"

function index()
	local page = entry({"admin", "status", "re_ss_01_cpu_temperature"}, call("cpu_temperature"), nil)
	page.leaf = true
	page.dependent = false
end

function cpu_temperature()
	local value = sys.exec(temperature_helper .. " 2>/dev/null"):gsub("%s+$", "")
	local temperature = tonumber(value)

	http.prepare_content("application/json")
	if not temperature then
		http.status(503, "temperature unavailable")
		http.write(jsonc.stringify({
			success = 1,
			error = "temperature unavailable"
		}))
		return
	end

	http.write(jsonc.stringify({
		success = 0,
		result = {
			cpuTemperature = temperature
		}
	}))
end
