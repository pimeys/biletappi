#################################################################
#
# URL Catcher 1.1.2 by (c)cell '2002
# http://cell.isoveli.org/scripts
# Requires TCL8.4 and eggdrop something something.
#
# Extracts URLs from string and sends them to handlers
# Configure handlers at the bottom of this file
# The default handler assumes you have the following sql urllog-table:
#
# MYSQL:
#	CREATE TABLE urllog (
#		id int(11) NOT NULL auto_increment,
#		url text,
#		entrydate timestamp(14) NOT NULL,
#		nick varchar(9) default NULL,
#		userhost varchar(255) default NULL,
#		comment text,
#		channel varchar(255) default NULL,
#		KEY id (id)
#	) TYPE=MyISAM;
#
# POSTGRESQL:
#	CREATE TABLE urllog {
#		id bigserial,
#		url text,
#		entrydate timestamp with time zone,
#		userhost varchar(255),
#		nick varchar(9),
#		comment text,
#		channel varchar(255),
#		KEY id (id)
#	}
#
#
#
# NOTE: postgresql table definition above is something i cooked up
# after about ten minutes of browsing postgresql.com..
# but it seems to work ;)
#
#
# If you wish to process detected urls in your own scripts, you may
# register your own handler with:
#
#	urlcatch::addhandler <function>
#
# handler function gets "urllist nick handle uhost chan args" as parameters
# urllist consists: url protocol user pass host port path isipv6
# ipv6 urls have their host address quoted with [ ]
#
# It is strongly recommended that you add your handlers here
# in this file (see below)
#
#
#################################################################


package require http
package require tls
package require htmlparse

namespace eval ::urlcatch {
    set scriptversion 1.1.2
    ::http::register https 443 ::tls::socket

    # if cellgen package is available, let's use it for autoupdate
    if {[catch { ::cell::registerautoupdate $scriptversion "http://cell.isoveli.org/scripts/catchurl.tcl" } error]} {
	putlog "catchurl: cellgen not available - not using autoupdate"
    }

    ## LOAD CONFIGURATION
    ## if cellgen package is present, the configuration is loaded
    ## from it's conf path

    # dummy search :)
    catch { source catchurl.conf }
    catch { source scripts/catchurl.conf }
    catch { source scripts/config/catchurl.conf }
    catch { source $::cell::conf(confpath)/catchurl.conf }


    # we need sql package for default handler
    if {$sqlconf(type) == "mysql"} {
	package require mysqltcl
    } else {
	load libpgtcl[info sharedlibextension]
    }

    ###########################################################
    ################## HANDLER ################################
    ###########################################################

    proc echourl {urllist nick handle uhost chan text} {
	foreach url $urllist {
            putserv "PRIVMSG $chan :[lrange $url 1 end]"
	}
    }


    proc saveurldb {urllist nick handle uhost chan text} {
	variable conf
	variable sqlconf

	if {$conf(channel_specific_log)} { set check " and channel='$chan'" } else { set check "" }

	set sqlhand [urlcatch::opensql $sqlconf(host) $sqlconf(user) $sqlconf(pass) $sqlconf(db)]
	if {$sqlhand == 0} { return }
	set urldetected 0

	if {[matchattr $handle "b"] && !$conf(logbots) } { putlog "catchurl: Not logging bot's urls" }

	foreach foo $urllist {
            # check if the url is old (make sure you have columns 'nick', 'userhost' and 'entrydate')
            set url [urlcatch::escape [lindex $foo 0]]
            if {$sqlconf(type) == "mysql"} {
                set duplicate [mysqlsel $sqlhand "select nick,userhost,UNIX_TIMESTAMP(entrydate) as pvm from $sqlconf(table) where ((url='$url' or url='$url/')$check) order by entrydate" -list]
                if {$duplicate == "0"} { set duplicate "" }
            } else {
                set res [pg_exec $sqlhand "select nick from $sqlconf(table) where ((url='$url' or url='$url/')$check) order by entrydate"]
                set n [pg_result $res -numTuples]
                if {$n == 0} { set duplicate "" } else { set duplicate "yes" }
                pg_result $res -clear
            }

            if {$duplicate == ""} {

                putlog [urlcatch::escape $text]

                #############################################
                # Insert new entry to database
                #############################################
                if {$sqlconf(type) == "mysql"} {
                    mysqlexec $sqlhand "insert into $sqlconf(table) (url, nick, userhost, channel, comment) \
					values ('$url', '$handle', '$uhost', '$chan', '[urlcatch::escape $text]')"
                } else {

                    ## fix scandinavian characters
                    ## TCL Unicode and PSQL Unicode doesn't seem to play well together
                    ## If you find a solution to this, please contant me at cell@amigafin.org

                    regsub -nocase -all -- {�} $text {o} text
                    regsub -nocase -all -- {�} $text {a} text
                    regsub -nocase -all -- {�} $text {a} text

                    pg_exec $sqlhand "insert into $sqlconf(table) (url, nick, userhost, channel, comment, entrydate) \
					values ('$url', '$handle', '$uhost', '$chan', '[urlcatch::escape $text]', LOCALTIMESTAMP)"

                    putlog "insert into $sqlconf(table) (url, nick, userhost, channel, comment, entrydate) values ('$url', '$handle', '$uhost', '$chan', '[urlcatch::escape $text]', LOCALTIMESTAMP)"
                }

                incr urldetected
                lappend loggedurls $url

                if {$conf(createtinyurl) && $conf(urlminlength) <= [string length $url]} {
                    createtinyurl $url $chan
                }
            }

            if {$conf(youtube)} {
                if {[regexp -nocase -- "youtube.com/watch" $url]} {
                    createyoutube $url $chan
                }
            }
	}

	# if one or more url's are recorded, write something to the log
	if {$urldetected} { putlog "URL(s) detected ($nick) count:$urldetected ([join $loggedurls ","])" }
	closesql $sqlhand
    }


    proc opensql {host user pass db} {
	variable sqlconf
	if {$sqlconf(type) == "mysql"} {
            set sqlhand [mysqlconnect -host $host -user $user -pass $pass -db $db]
            return $sqlhand
	} else {
            set sqlhand [pg_connect -conninfo "host=$host user=$user password=$pass dbname=$db"]
            return $sqlhand
	}
    }


    proc closesql {sqlhand} {
	variable sqlconf
	if {$sqlconf(type) == "mysql"} { mysqlclose $sqlhand } else { pg_disconnect $sqlhand }
    }


    proc createtinyurl {url chan} {
	catch { ::cell::setproxy }
	set token [::http::geturl "http://tinyurl.com/create.php" -query [::http::formatQuery url $url] -command ::urlcatch::createtinyurl_cb]
	upvar #0 $token state
	set state(chan) $chan
    }


    proc createtinyurl_cb { token } {
	variable conf
	upvar #0 $token state

	if {[catch {
            set data [split $state(body) \n]
            foreach line $data {
                if {[regexp -nocase -- {<blockquote>http://tinyurl.com/} $line]} {
                    regsub -all -- {<blockquote>|</blockquote>|^[ \t]*|[ \t]$} $line {} url
                    putserv "PRIVMSG $state(chan) :$conf(tinysay)$url"
                    return
                }
            }
	} error] == 1} {
            putlog $error
	}
    }

    proc createyoutube {url chan} {
	set token [http::geturl $url -timeout 10000]
	upvar #0 $token st
	if {$st(status) == {ok} || $st(status) == {eof}} {
            set data [split $st(body) \n]
            for {set i 0} {$i < [llength $data]} {incr i} {
                if {[regexp -nocase -- {<meta property="og:title"} [lindex $data $i]]} {
                    set name [string trim [lindex $data $i]]
                    regsub {.* content="([^"]*)".*} $name {\1} name
				set name [::htmlparse::mapEscapes $name]
				set name [encoding convertto utf-8 $name]
				putmsg $chan "YouTube - $name"
				return
			}
		}
	}
}

########################
###################################
###########################################################
###########################################################

bind pubm - *.%* urlcatch::urlcatchpub
bind topc - *.%* urlcatch::urlcatchpub
bind msg - testurl urlcatch::urlcatchmsg

variable urlhandlers ""


proc escape {string} {
    regsub -all -- "'" $string "\\\\'" string
    return $string
}


proc addhandler {func} {
    variable urlhandlers
    lappend urlhandlers $func
}


proc sendtohandlers {urllist nick handle uhost chan text} {
    variable urlhandlers
    variable conf

    if {$conf(activechannels) != ""} { if { [lsearch -exact [split [string tolower $conf(activechannels)] " "] [string tolower $chan]] == -1} { return } }
    if {$handle == "*"} { set handle $nick }

    foreach handler $urlhandlers {
        set erno [catch {$handler $urllist $nick $handle $uhost $chan $text} error]
        if {$erno == 1} { putlog "catchurl: You have error on your url handler '$handler': $error" }
    }
}


proc urlcatchmsg {nick handle uhost args} {
    urlcatchpub $nick $handle $uhost $nick $args
}


proc urlcatchpub {nick uhost handle chan para} {
    set urllist [urlcatch::getpotentialurls $para]

    if {[llength $urllist]} {
	set urllist [urlcatch::parseworkingurls $urllist]
	if {[llength $urllist]} {
            urlcatch::sendtohandlers $urllist $nick $handle $uhost $chan $para
	}
    }
}


proc parseworkingurls {list} {
    variable conf

    if {$conf(tryresolve) == 0} { return $list }

    set urllist [list]
    foreach url $list {
        #ipv4
        if {[lindex $url 7] == 0} {
            set host [lindex $url 4]
            regsub -all -- {\$host} $conf(resolveipv4) $host cc
            if {![regexp -nocase -- $conf(resolvefail) [eval "$cc"]]} { lappend urllist $url } else { putlog "[lindex $url 0] does not resolve" }
        }
    }
    return $urllist
}


proc getpotentialurls {para} {
    variable prefixes
    variable conf

    set urllist ""
    set urllistlong ""
    set args [split $para " "]

    foreach para $args {

        set Umatch 0
        set Uurl ""
        set Ulogin ""

        # strip " and ' quotation marks
        if {[regexp -- {^["']} $para]} { regsub -all -- {^[\("']|[\)"']$} $para {} para }

		regexp -nocase -- {([^:]+://)*([^:]+[^@]+@+)([^:/]+)(:([0-9]+))?(/*.*)} $para \
		Uurl Uprotocol Ulogin Uhost Ux Uport Upath

		# no user/pass definition
		if {$Uurl == ""} {
			regexp -nocase -- {([^:]+://)*([^:/]+)(:([0-9]+))?(/*.*)} $para \
			Uurl Uprotocol Uhost Ux Uport Upath
		}

		set Uuser [lindex [split $Ulogin :] 0]
		set Upass [string range [lindex [split $Ulogin :] 1] 0 end-1] ; # strip @

		set mlevel 10
		foreach {proto pat} [array get prefixes] {
			set level 0
			foreach p [split $pat] {
				incr level
				if {[regexp -- $p $Uurl] && $mlevel > $level} {
					set Umatch 1
					set Uprotocol $proto
					set mlevel $level
					if {[string range $proto end end]==":"} {
						set Uoptions "noslash"
					} else { set Uoptions "" }
				}
			}
		}

		if {$Umatch == 1} {

			if {[info exists conf(strippostfix)]} {
				if {$conf(strippostfix) != ""} {
					regsub -all -- "$conf(strippostfix)\$" $Uurl {} Uurl
					regsub -all -- "$conf(strippostfix)\$" $Upath {} Upath
				}
			}

			# fix nonstandard urls & remove ()
			if {[regexp "noslash" $Uoptions]} { set s "" } else { set s "://" }
			regsub -- ".*$Uprotocol$s" $Uurl {} Uurl
			set Uurl "$Uprotocol$s$Uurl"
			if {$Upath == "" && $s != ""} {
				regsub -all -- {/$} $Uurl {} Uurl
				set Uurl "$Uurl/"
			}


			# check url if it's ignored by conf(ignoreurls)
			set ok 1; foreach is $conf(ignoreurls) { if {[regexp -nocase -- $is $Uurl]} { set ok 0 } }

			# add url to urllist
			if {$ok} {
				lappend urllist \
				[list $Uurl $Uprotocol $Uuser $Upass $Uhost $Uport $Upath 0]
			}
		}
	}

	return $urllist
}

putlog "Catchurl v$scriptversion by (c)cell"


}
#end namespace
set urlhandlers ""

#######################################################################################
#######################################################################################




### URL HANDLERS

## INSERT HERE: HANDLERS TO BE RUN BEFORE ADDING URLS TO urllog
source scripts/catchurl_wanha.tcl


## INSERT HERE: HANDLERS TO BE RUN AFTER ADDING URLS TO urllog
urlcatch::addhandler urlcatch::saveurldb
#urlcatch::addhandler urlcatch::echourl
#source scripts/catchurl_archive.tcl
