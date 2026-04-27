module("luci.controller.tgwol", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/tgwol") then
		return
	end

	local page = entry({"admin", "services", "tgwol"},
		alias("admin", "services", "tgwol", "general"),
		_("Telegram WOL Bot"), 60)
	page.dependent = true
	page.acl_depends = { "luci-app-tgwol" }

	entry({"admin", "services", "tgwol", "general"},
		cbi("tgwol/general"), _("General"), 1).leaf = true

	entry({"admin", "services", "tgwol", "devices"},
		cbi("tgwol/devices"), _("Devices"), 2).leaf = true

	entry({"admin", "services", "tgwol", "users"},
		cbi("tgwol/users"), _("Users / Access"), 3).leaf = true

	entry({"admin", "services", "tgwol", "router"},
		cbi("tgwol/router"), _("Router actions"), 4).leaf = true

	entry({"admin", "services", "tgwol", "status"},
		template("tgwol/status"), _("Status"), 5).leaf = true

	entry({"admin", "services", "tgwol", "action"},
		call("action_handler"), nil).leaf = true
end

function action_handler()
	local http = require "luci.http"
	local sys  = require "luci.sys"
	local disp = require "luci.dispatcher"

	local act = http.formvalue("act") or http.formvalue("action") or ""

	if act == "start" then
		sys.call("/etc/init.d/tgwol start >/dev/null 2>&1")
	elseif act == "stop" then
		sys.call("/etc/init.d/tgwol stop >/dev/null 2>&1")
	elseif act == "restart" then
		sys.call("/etc/init.d/tgwol restart >/dev/null 2>&1")
	elseif act == "enable" then
		sys.call("/etc/init.d/tgwol enable >/dev/null 2>&1")
	elseif act == "disable" then
		sys.call("/etc/init.d/tgwol disable >/dev/null 2>&1")
	elseif act == "test" then
		local out = sys.exec("/usr/bin/tgwol-cli test-token 2>&1")
		http.prepare_content("text/plain; charset=utf-8")
		http.write(out)
		return
	elseif act == "wake" then
		local sec = http.formvalue("sec") or ""
		local out = sys.exec("/usr/bin/tgwol-cli wake " .. sec:gsub("[^%w_-]", "") .. " 2>&1")
		http.prepare_content("text/plain; charset=utf-8")
		http.write(out)
		return
	end

	http.redirect(disp.build_url("admin", "services", "tgwol", "status"))
end
