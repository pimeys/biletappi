######################################################################################
#
# links v1.3.4 by (c)cell '2002
# http://cell.isoveli.org/scripts
#
# gets links from sql database and floods them to channel
# use this with catchurl (http://cell.isoveli.org/scripts/)
#
# !links [searchword] [searchword] [...] [number of links]
#
# * Use as many keywords you have to. ALL keywords are required at
#   least in one of the following: url, nick or comment.
#
# * When used without parameters, links displays the number of links
#   stored in database :)
#
# !links eggdrop 3
# displays 3 links found with search word 'eggdrop' (in url, nick or comment)
#
#
#
#	1.3.4	postgre don't support REGEXP, so multiple searchwords didn't work
#	1.3.3 	links were not displayed in the right order :I
#	1.3.2	- Dropped the 'pub' keyword support (sucked). However, since lots of
#		people are still accustomed to it, the script ignores it in order
#		to prevent confusion in searches.
#		- Also made support for postgresql AND changed mysql support to
#		mysqltcl. Mysqltcl package is way better than the tcl-sql I was
#		using before (like crashes with multiple connections etc.)
#	1.3	all search parameters given to links must match. (in previous versions
#		only one parameter needed to match the url-entry to display it)
#	1.2	fixed channel_specific to work and improved configurability a bit
#
####################################################################################
namespace eval ::urlcatch::links {
set scriptversion 1.3.4


### configuration


# channels where !links responses. Use "" to mirror
# active channels from catchurl.conf
set conf(activechannels) "!infinity"

# how many links to display by default
set conf(number_of_links) 5

# display only links said on channel where the command was called
set conf(channel_specific) 0



# If you don't have catchurl, links can't find your sql settings. You
# can however force them here.

# set ::urlcatch::sqlconf(user) "cell"
# set ::urlcatch::sqlconf(pass) ""
# set ::urlcatch::sqlconf(table) "urllog"
# set ::urlcatch::sqlconf(host) "localhost"
# set ::urlcatch::sqlconf(db) "cell"

# Ignore the following search words: (regexp, be careful)
set conf(ignore_keywords) "^pub"


#
# end of config
#############################################################################
#############################################################################


if {$::urlcatch::sqlconf(type) == "mysql"} {
	package require mysqltcl
} else {
	load libpgtcl[info sharedlibextension]
}

if {$conf(activechannels) == ""} { set conf(activechannels) $::urlcatch::conf(activechannels) }

bind pub - !links ::urlcatch::links::linkspub
bind pub - .links ::urlcatch::links::linkspub
bind msg - links ::urlcatch::links::linksmsg

proc linksmsg {nick uhost handle text} { showlinks $nick $uhost $handle $nick $text 1 }
proc linkspub {nick uhost handle chan text} { showlinks $nick $uhost $handle $chan $text 0 }

proc sqlquery {sqlhand querys} {
	if {$::urlcatch::sqlconf(type) == "mysql"} {
		set duplicate [mysqlsel $sqlhand $querys -list]
	} else {
		set res [pg_exec $sqlhand $querys]
		set n [pg_result $res -numTuples]
		set duplicate ""
		if {$n != 0} {
			for {set i 0} {$i < $n} {incr i} {
				lappend duplicate [pg_result $res -getTuple $i]
			}
		}
		pg_result $res -clear
	}
	return $duplicate
}


proc showlinks {nick uhost handle chan text priv} {
	variable conf

	# check active channels
	if {$conf(activechannels) != "" && !$priv} {
		if { [lsearch -exact [split [string tolower $conf(activechannels)]] [string tolower $chan]] == -1} {
			return 1
		}
	}

	# open sql
	set sqlhand [::urlcatch::opensql $::urlcatch::sqlconf(host) $::urlcatch::sqlconf(user) $::urlcatch::sqlconf(pass) $::urlcatch::sqlconf(db)]
	if {$sqlhand == 0} { putlog "ERROR (links.tcl): Unable to open SQL connection" ; return }

	# display how many links have bot logged (channel specific, if set)
	if {$text == ""} {
		set qs "select count(*) from $::urlcatch::sqlconf(table)"
		if {$conf(channel_specific)} { append qs " where channel='$chan'" }
		set count [sqlquery $sqlhand $qs]
            putmsg $chan "!links: $count links in db."
		::urlcatch::closesql $sqlhand
		return
	}

	set nlinks $conf(number_of_links)
	if {$conf(ignore_keywords) != ""} { regsub -all -- $conf(ignore_keywords) $text {} text }
	set args [split $text " "]
	if { [string is digit [lindex $args end]] } { set nlinks [lindex $args end] ; set args [lreplace $args end end] }
	if { $conf(channel_specific) } { set and " and channel='$chan'" } else { set and "" }

	regsub -all -- {'} [lindex $args 0] {\\\\'} searchstring
	if {$::urlcatch::sqlconf(type) == "mysql"} {
		set qs "SELECT url,nick,comment,UNIX_TIMESTAMP(entrydate),channel FROM urllog"
		if {$searchstring != ""} {
			append qs " where ((nick LIKE '%$searchstring%'$and) OR (url LIKE '%$searchstring%'$and) OR (comment LIKE '%$searchstring%'$and))"
		}
		append qs " order by entrydate desc"
	} else {
		set qs "SELECT url,nick,comment,date_part('epoch',\"entrydate\"),channel FROM urllog"
		if {$searchstring != ""} {
			append qs " where ((nick LIKE '%$searchstring%'$and) OR (url LIKE '%$searchstring%'$and) OR (comment LIKE '%$searchstring%'$and))"
		}
		append qs " order by entrydate desc"
	}

	set ls [sqlquery $sqlhand $qs]
	set linkstr ""
	set foobar 0
	set links ""

	foreach row $ls {
		if {$foobar >= $nlinks} { continue }
		set ok 0
		foreach arg $args { if {[regexp -nocase -- $arg $row]} { incr ok } }
		if {$ok == [llength $args] && ([regexp -nocase -- "^[lindex $row end]\$" $chan] || $conf(channel_specific) == 0)} {
			set url [lindex $row 0]
			set nick [lindex $row 1]
			regsub -- {\..*} [lindex $row 3] {} date
			set date [clock format $date -format "%d.%m.%Y"]
	   		lappend links "$url ($nick $date)"
			incr foobar
		}
	}

	::urlcatch::closesql $sqlhand
	if { [llength $links] == 0 } {
		putmsg $chan "!links: Ei l�ytynyt yht��n."
	} else {
		putmsg $chan "!links: [join $links ", "]"
	}

	return 1
}


putlog "links v$::urlcatch::links::scriptversion by cell"

}
#end namespace
