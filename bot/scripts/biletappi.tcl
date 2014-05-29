### on ei onko

cmd_add on bt_chat
cmd_add ei bt_chat
cmd_add onko bt_chat

proc bt_chat {nick userhost handle channel cmd args} {
	if {[rand 100] < 10} {
		set reverse 1
	} else {
		set reverse 0
	}

	if {$cmd == "on" && !$reverse} {
		set response "eihän ole"
	} elseif {$cmd == "on"} {
		set response "niin on"
	} elseif {$cmd == "ei" && !$reverse} {
		set response "ei niin"
	} elseif {$cmd == "ei"} {
		set response "onpas"
	} elseif {$cmd == "onko" && !$reverse} {
		set response "ei ole"
	} elseif {$cmd == "onko"} {
		set response "onhan se"
	} else {
		return
	}
	if {[rand 100] < 10} {
		set response "$response!"
	}
	tappi_say $channel $nick $response
}
