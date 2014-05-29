cmd_add genre genre

proc genre_rand {min max} {
    return [expr round($min + floor(rand() * ($max-$min+1)))]
}

proc genre {nick userhost handle channel cmd args} {
    set args [lindex $args 0]

    set mains {house trance ambient techno triphop hardcore rave drum'n'bass jungle goa kiksu disco acid electro dub nitku dubstep}

    set subs {kiksu kamppi kerava amis suomi tyttö disco italo synth garage classic acid hip freestyle vocal anthem euro happy jpop goth death epic nrg speed hard booty minimal latin deep funky industrial experimental intelligent futuristic psychedelic goa hardstyle german french ibiza progressive dubby tribal swedish brit gangsta soulful ghetto oldskool nuskool jazzstep liquid neuro dark ill wobble hipster}

    set res [lindex $mains [genre_rand 0 [expr [llength $mains]-1]]]

    set countsubs [genre_rand 2 3]

    for {set i 0} {$i < $countsubs} {incr i} {
        set testsub [lindex $subs [genre_rand 0 [expr [llength $subs]-1]]]
        if {[lsearch $res $testsub] == -1} {
            set res "$testsub $res"
        } else {
            incr i -1
        }
    }

    if {$args != {}} {
        set replaceat [genre_rand 0 [expr [llength $res]-2]]
        set res [join [lreplace $res $replaceat $replaceat $args] " "]
    }

    putmsg $channel $res
}
