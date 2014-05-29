### the tappi eggdrop library of fun
### v2.0

### utils

proc putmsg {target text} {
	if {[regexp "^!" $target]} {
		set target [chandname2name $target]
	}

	putserv "PRIVMSG $target :$text"
}

proc tappi_say {target usenick text} {
	if {$usenick != ""} {
		set text "$usenick, $text"
	}
	putmsg $target $text
}

######

### INTERFACE: arguments for function:
### $nick $userhost $handle $channel $cmd $xargs

proc cmd_add {trigger function} {
	global commands
	set commands($trigger) $function
}

### INTERFACE:
### $nick $userhost $handle $cmd $xargs

proc mcmd_add {trigger function} {
	global mcommands
	set mcommands($trigger) $function
}

bind pub - ${nick} cmd
bind pub - ${nick}: cmd
bind pub - ${nick}, cmd
bind msgm - * mcmd

proc cmd {nick userhost handle channel args} {
	global commands

	### $args on lista listan sis�ll�... otetaan se sis�ll� oleva lista
	set args [lindex $args 0]

	### $cmd -> ensimm&inen sana, $xargs -> loput
	if {[llength $args] == 0} {
		return -1
	}
	set cmd [lindex $args 0]
	if {[llength $args] > 1} {
		set xargs [lrange $args 1 end]
	} else {
		set xargs {}
	}

	if {[array names commands $cmd] != ""} {
		$commands($cmd) $nick $userhost $handle $channel $cmd $xargs
	} else {
		tappi_megahal $nick $channel [join $args " "]
	}
}

proc mcmd {nick userhost handle args} {
	global mcommands
	set args [lindex $args 0]

	### $cmd -> ensimm�inen sana, $xargs ->
	if {[llength $args] == 0} {
		return -1
	}
	set cmd [lindex $args 0]
	if {[llength $args] > 1} {
		set xargs [lrange $args 1 end]
	} else {
		set xargs {}
	}

	if {[array names bt_mcommands $cmd] != ""} {
		$mcommands($cmd) $nick $userhost $handle $cmd $xargs
	}

}

set previous_reply ""
proc tappi_megahal {nick channel text} {
	global previous_reply

	if {[regexp -nocase "ruff" $nick] || [regexp -nocase "moon" $nick] || [regexp -nocase "ekix" $nick] || [regexp -nocase "tumpsi" $nick]} {
		return
	}
	if {[regexp {\xc3[\xa4\x84\xb6\x96]} $text]} {
		set text [encoding convertfrom utf-8 $text]
	}
	
	tappi_learn $nick "foo" "foo" $channel $text
	set reply $previous_reply
	set c 0
	while {$reply == $previous_reply && $c < 5} {
		set reply [getreply $text]
		incr c
	}
	tappi_say $channel $nick $reply
}

bind pubm - * tappi_learn
proc tappi_learn {nick userhost handle channel text} {
	if {[regexp -nocase -- "b.?letap" $text] || [regexp -nocase -- "natinat" $text]} {
		return
	}
	if {[regexp -nocase -- "http" $text]} {
		return
	}
	if {[regexp -nocase "ruff" $nick] || [regexp -nocase "moon" $nick] || [regexp -nocase "ekix" $nick] || [regexp -nocase "tumpsi" $nick]} {
		return
	}
	regsub -nocase -- {^\s*\S+[,:]\s+} $text "" text
	if {[string length $text] < 20} {
		return
	}
	learn $text
}



### kumpi

cmd_add kumpi kumpi
cmd_add kumpi, kumpi
cmd_add kumpi: kumpi

proc kumpi {nick userhost handle channel cmd args} {
	set args [lindex $args 0]

	if {[llength $args] == 0} {
		tappi_say $channel $nick "kampi"
		return -1
	}

	if {[regexp "^(on|olisi?) " $args]} {
		kumpi $nick $userhost $handle $channel kumpi [lrange $args 2 end]
		return 0
	}

	set vai [lsearch $args "vai"]
	if {$vai == -1} {
		tappi_say $channel $nick "kumpi vaan"
		return -1
	} elseif {$vai == 0} {
		tappi_say $channel $nick "kampi"
		return -1
	} elseif {$vai == [expr [llength $args] - 1]} {
		tappi_say $channel $nick "sepä se"
		return -1
	}

	set str(0) [lrange $args 0 [expr $vai - 1]]
	set str(1) [lrange $args [expr $vai + 1] end]

	set ans [rand 100]
	if {$ans < 49} {
		set anss $str(0)
	} 
	if {$ans >= 49 && $ans < 98} {
		set anss $str(1)
	}
	if {$ans == 98} {
		set anss "ei kumpikaan"
	}
	if {$ans == 99} {
		set anss "molemmat"
	}

	tappi_say $channel $nick "$anss"
}

bind pub - !kello kello
cmd_add kello kello

proc kello_bang {nick userhost handle channel text} {
    kello $nick $userhost $handle $channel kello $text
}

proc kello {nick userhost handle channel text} {
	global kellot

	if {[llength $text] < 2} {
		putmsg $channel "!kello <hh:mm> <asia|pois>"
		return
	}

	if {! [regexp "^\[0-9\]\[0-9\]:\[0-9\]\[0-9\]\$" [lindex $text 0]]} {
		putmsg $channel "$nick, aika annetaan muodossa tunti:minuutti eikä muuta voi"
		return
	}

	set aika [lindex $text 0]
	if {[string range $aika 0 1] > 23 || [string range $aika 3 4] > 59} {
		if {![matchattr $handle +n]} {
			putmsg $channel "$nick, olepas nyt kunnolla"
			return
		}
	}

	if {[lindex $text 1] == "pois"} {
		kello_pois [lindex $text 0] $nick $handle
		return
	}

	# korvaa huonot merkit
	set asia [lrange $text 1 end]
	regsub -all "\[^0-9a-zA-Z\xc5\xc4\xd6\xe5\xe4\xf6\xc3\xa5\xa4\xb6\x85\x84\x96\.\-\]" $asia " " asia

	tappi_say $channel $nick "herätän sut kello [lindex $text 0]."
	lappend kellot "[lindex $text 0] $nick $channel $asia"
}

bind time - * kello_bling

proc kello_bling {minute hour day month year} {
	global kellot

	for {set i 0} {$i < [llength $kellot]} {incr i} {
		set tmp [lindex $kellot $i]
		if {[lindex $tmp 0] == "$hour:$minute"} {
			tappi_say [lindex $tmp 2] [lindex $tmp 1] "pling. [lrange $tmp 3 end]"
			set kellot [lreplace $kellot $i $i]
			incr i -1
		}
	}
}

proc kello_pois {time nick handle} {
	global kellot

	for {set i 0} {$i < [llength $kellot]} {incr i} {
		set tmp [lindex $kellot $i]
		if {[lindex $tmp 0] == $time && ([lindex $tmp 1] == $nick || [matchattr $handle +n])} {
			tappi_say [lindex $tmp 2] [lindex $tmp 1] "poistin sen herätyksen."
			set kellot [lreplace $kellot $i $i]
			incr i -1
		}
	}
}
