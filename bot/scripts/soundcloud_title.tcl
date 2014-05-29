set soundcloud(timeout)            "30000"
set soundcloud(oembed_location)    "http://soundcloud.com/oembed?format=json"
set soundcloud(tiny_url)           0
set soundcloud(response_format) "SoundCloud :: \"%title%\""

bind pubm - * public_soundcloud

set soundcloud(pattern) {https*://.*soundcloud.com/[a-zA-Z0-9_\-]+/[a-zA-Z0-9_\-]+}
set soundcloud(maximum_redirects)  2
set soundcloud(maximum_title_length) 256
###############################################################################

package require http
package require tls

::http::register https 443 ::tls::socket

set gTheScriptVersion "0.1"

proc note {msg} {
    putlog "% $msg"
}

###############################################################################

proc flat_json_decoder {info_array_name json_blob} {
    upvar 1 $info_array_name info_array
    # 0 looking for key, 1 inside key, 2 looking for value, 3 inside value
    set kvmode 0
    set cl 0
    set i 1
    set length [string length $json_blob]
    while { $i < $length } {
        set c [string index $json_blob $i]
        if { [string equal $c "\""] && [string equal $cl "\\"] == 0 } {
            if { $kvmode == 0 } {
                set kvmode 1
                set start [expr $i + 1]
            } elseif { $kvmode == 1 } {
                set kvmode 2
                set name [string range $json_blob $start [expr $i - 1]]
            } elseif { $kvmode == 2 } {
                set kvmode 3
                set start [expr $i + 1]
            } elseif { $kvmode == 3 } {
                set kvmode 0
                set info_array($name) [string range $json_blob $start [expr $i - 1]]
            }
        }
        set cl $c
        incr i 1
    }
}

proc filter_title {blob} {
    # Try and convert escaped unicode
    set blob [subst -nocommands -novariables $blob]
    set blob [string trim $blob]
    set blob
}

proc extract_title {json_blob} {
    global soundcloud
    array set info_array {}
    flat_json_decoder info_array $json_blob
    if { [info exists info_array(title)] } {
        set title [filter_title $info_array(title)]
    } else {
        error "Failed to find title.  JSON decoding failure?"
    }
    if { [string length $title] > $soundcloud(maximum_title_length) - 1 } {
        set title [string range $title 0 $soundcloud(maximum_title_length)]"..."
    } elseif { [string length $title] == 0 } {
        set title "No usable title."
    }
    return $title
}

###############################################################################

proc fetch_title {soundcloud_uri {recursion_count 0}} {
    global soundcloud
    if { $recursion_count > $soundcloud(maximum_redirects) } {
        error "maximum recursion met."
    }
    set query [http::formatQuery url $soundcloud_uri]
    set response [http::geturl "$soundcloud(oembed_location)&$query" -timeout $soundcloud(timeout)]
    upvar #0 $response state
    foreach {name value} $state(meta) {
        if {[regexp -nocase ^location$ $name]} {
            return [fetch_title $value [incr recursion_count]]
        }
    }
    if [expr [http::ncode $response] == 401] {
        error "Location contained restricted embed data."
    } else {
        set response_body [http::data $response]
        http::cleanup $response
        return [extract_title $response_body]
    }
}

proc public_soundcloud {nick userhost handle channel args} {
    global soundcloud botnick
    if {[regexp -nocase -- $soundcloud(pattern) $args match fluff video_id]} {
        note "Fetching title for $match."
        if {[catch {set title [fetch_title $match]} error]} {
            note "Failed to fetch title: $error"
        } else {
            set tinyurl $match
            if { $soundcloud(tiny_url) == 1 && \
                     [catch {set tinyurl [make_tinyurl $match]}]} {
                note "Failed to make tiny url for $match."
            }
            set tokens [list %botnick% $botnick %post_nickname% \
                            $nick %title% "$title" %soundcloud_url% \
                            "$match" %tinyurl% "$tinyurl"]
            set result [string map $tokens $soundcloud(response_format)]
            putserv "NOTICE $channel $result"
        }
    }
}

###############################################################################

note "soundcloud_title$gTheScriptVersion: loaded";
