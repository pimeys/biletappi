### spotify.tcl eggedrop script
### v1.0.1 2010-04-30 deee

package require http

bind pubm - *spotify:* spotify_check
bind pubm - *open.spotify.com* spotify_check

proc spotify_check {nick userhost handle channel args} {
    set words [split $args " "]
    foreach word $words {
        regsub {\{|\}} $word "" word
        set reply ""
        set mode 0
        if {[regexp {^spotify:} $word]} {
            set reply [spotify_query $word]
            set mode 1
        } elseif {[regexp {^http://open.spotify.com/} $word]} {
            set reply [spotify_query_http $word]
            set mode 2
        }
        if {$reply != ""} {
            if {$mode == 1} {
                append reply ". [spotify_create_openurl $word]"
            }
            putserv "NOTICE $chan Spotify - $reply"
        }
    }
}

proc spotify_query {url} {
    if {![regexp {^spotify:(artist|album|track):([a-zA-Z0-9]+)$} $url foo mode hash]} {
        return ""
    }

    return [spotify_lookup $mode $hash]
}

proc spotify_create_openurl {word} {
    regexp {^spotify:(artist|album|track):([a-zA-Z0-9]+)$} $word foo mode hash
    return "http://open.spotify.com/$mode/$hash"
}

proc spotify_query_http {url} {
    if {![regexp {^http://open.spotify.com/(artist|album|track)/([a-zA-Z0-9]+)$} $url foo mode hash]} {
        return ""
    }

    return [spotify_lookup $mode $hash]
}

proc spotify_lookup {mode hash} {
    set lookupUrl {http://ws.spotify.com/lookup/1/?uri=spotify:}
    append lookupUrl $mode
    append lookupUrl ":"
    append lookupUrl $hash

    set token [http::geturl $lookupUrl -timeout 10000]
    upvar #0 $token st

    set name ""
    set artist ""
    set year ""

    if {$st(status) == {ok} || $st(status) == {eof}} {
        set data [split $st(body) \n]
        foreach line $data {
            if {$mode == "artist"} {
                if {[regexp {<name>} $line]} {
                    regsub -all -- {.*<name>|</name>.*} $line {} name
                    return $name
                }
            }
            if {$mode == "album"} {
                if {$name == "" && [regexp {<name>} $line]} {
                    regsub -all -- {.*<name>|</name>.*} $line {} name
                } elseif {$artist == "" && [regexp {<name>} $line]} {
                    regsub -all -- {.*<name>|</name>.*} $line {} artist
                }
                if {[regexp {<released>} $line]} {
                    regsub -all -- {.*<released>|</released>.*} $line {} year
                    return "$artist - $name ($year)"
                }
            }
            if {$mode == "track"} {
                if {$name == "" && [regexp {<name>} $line]} {
                    regsub -all -- {.*<name>|</name>.*} $line {} name
                } elseif {[regexp {<name>} $line]} {
                    regsub -all -- {.*<name>|</name>.*} $line {} artist
                    return "$artist - $name"
                }
            }
        }
    }

    return ""
}
