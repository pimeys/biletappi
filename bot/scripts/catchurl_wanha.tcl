##
## Script for whining about old urls
## Requires catchurl v1.1
## http://cell.isoveli.org/scripts/
##
## note:	This script doesn't whine about your own urls
##		or users with +b (bot) flag
##


namespace eval ::urlcatch {

# send private notice to <nick> if the url is already said on that channel before
# by someone else. (it's doesn't whine about one repeating he's own urls) 1=yes 0=no
set old_notice 0


# display public message to <nick> if the url is already said on that channel before
# use empty quotes ("") to disable this feature
set old_whine "wanha"

## script starts

proc wanha_ww {urllist nick handle uhost chan text} {
	variable conf
	variable sqlconf

	variable old_whine
	variable old_notice

	if {$conf(channel_specific_log)} { set check " and channel='$chan'" } else { set check "" }

	set sqlhand [urlcatch::opensql $sqlconf(host) $sqlconf(user) $sqlconf(pass) $sqlconf(db)]
	if {$sqlhand == 0} { return }

	foreach foo $urllist {
		set url [urlcatch::escape [lindex $foo 0]]
		if {$sqlconf(type) == "mysql"} {
			set duplicate [lindex [mysqlsel $sqlhand "select nick,userhost,UNIX_TIMESTAMP(entrydate) from $sqlconf(table) where ((url='$url' or url='$url/')$check) order by entrydate" -list] 0]
		} else {
			set res [pg_exec $sqlhand "select nick,userhost,date_part('epoch',\"entrydate\") from $sqlconf(table) where ((url='$url' or url='$url/')$check) order by entrydate"]
			set n [pg_result $res -numTuples]
			if {$n == 0} {
				set duplicate ""
			} else { 
				set duplicate [pg_result $res -getTuple rowNumber]
			}
			pg_result $res -clear
		}
	
		if {![matchattr $handle "b"]} {
			if {$duplicate != ""} {
				if {$old_whine != "" && $nick != "*" && [lindex $duplicate 0] != $nick} {
					if {[regexp -nocase -- "\[vw\]+a+n+h+a+" $text]} {
						putmsg $chan "$nick, joo"
					} else {
						set t [expr [clock seconds] - [lindex $duplicate 2]]
						if {$t >= 86400} {
							set t [expr $t / 86400]
							if {$t == 1} {set t "$t päivän"} else {set t "$t päivää"}
						} elseif {$t >= 3600} {
							set t [expr $t / 3600]
							if {$t == 1} {set t "$t tunnin"} else {set t "$t tuntia"}
						} elseif {$t >= 60} {
							set t [expr $t / 60]
							if {$t == 1} {set t "$t minsan"} else {set t "$t minsaa"}
						} else {
							set t "melkein minsan"
						}
						putmsg $chan "$nick, $old_whine, jo $t"
					}
				}
					
				putlog "Old url said by $nick ($url)"
				
				if {$old_notice} {
					if {[lindex $duplicate 0] != $nick} {
						set saidtime [clock format [regsub -- {\..*} [lindex $duplicate 2] {}] -format "%H:%M %d.%m.%Y"]
						putserv "NOTICE $nick :[lindex $duplicate 0] ([lindex $duplicate 1]) said that url $saidtime"
					}
				}
			}
		}
	}
	
	closesql $sqlhand
}

putlog "Catchurl Wanhaaa v1.1"

}
# end namespace


::urlcatch::addhandler ::urlcatch::wanha_ww
