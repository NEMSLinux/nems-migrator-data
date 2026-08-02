#!/usr/bin/env tclsh
# Modernized MOTD script for NEMS Linux

# --- Helper Procedures ---

# Safely run shell commands without crashing on error
proc safe_exec {args} {
    if {[catch {exec {*}$args} result]} {
        return ""
    }
    return [string trim $result]
}

# Generate ASCII progress gauge
proc make_bar {pct width} {
    set filled [expr {int(($pct * $width) / 100)}]
    if {$filled > $width} { set filled $width }
    if {$filled < 0} { set filled 0 }
    set empty [expr {$width - $filled}]

    set bar ""
    for {set i 0} {$i < $filled} {incr i} { append bar "█" }
    for {set i 0} {$i < $empty}  {incr i} { append bar "░" }
    return $bar
}

# --- Variables ---
set user [expr {[info exists env(USER)] ? $env(USER) : "nemsadmin"}]
set home [expr {[info exists env(HOME)] ? $env(HOME) : "/home/nemsadmin"}]
set path [expr {[info exists env(PWD)]  ? $env(PWD)  : "/"}]

# Only run for root or home directory logins
if {![string match "root" $user] && ![string match -nocase "/home*" $path] && ![string match -nocase "/usr/home*" $path]} {
    return 0
}

# --- System Data Gathering ---

# NEMS Information
set nemsplatform [safe_exec /usr/local/bin/nems-info platform-name]
if {$nemsplatform eq ""} { set nemsplatform "NEMS Linux" }

set nemsver [safe_exec /usr/local/bin/nems-info nemsver]
if {$nemsver eq ""} { set nemsver "Unknown" }

set nemsveravail [safe_exec /usr/local/bin/nems-info nemsveravail]

set nemsip [safe_exec /usr/local/bin/nems-info ip]
if {$nemsip eq ""} { set nemsip "127.0.0.1" }

# System Uptime from /proc/uptime
set uptime 0
if {[file exists /proc/uptime]} {
    set fp [open /proc/uptime r]
    gets $fp line
    close $fp
    set uptime [expr {int([lindex [split $line] 0])}]
}
set up_days  [expr {$uptime / 86400}]
set up_hours [expr {($uptime % 86400) / 3600}]
set up_mins  [expr {($uptime % 3600) / 60}]

# Disk Usage percentage
set usage_str [safe_exec /usr/local/bin/nems-info diskusage]
set usage 0
regexp {(\d+)} $usage_str -> usage
if {$usage eq ""} { set usage 0 }

# Process Count
set psa [safe_exec sh -c "ps -A h | wc -l"]
if {$psa eq ""} { set psa "0" }

# System Load Average
set sysload_1 "0.00"
set sysload_5 "0.00"
set sysload_15 "0.00"
if {[file exists /proc/loadavg]} {
    set fp [open /proc/loadavg r]
    gets $fp line
    close $fp
    set parts [split $line]
    set sysload_1  [lindex $parts 0]
    set sysload_5  [lindex $parts 1]
    set sysload_15 [lindex $parts 2]
}

# Memory Calculation directly from /proc/meminfo
set mem_total 0
set mem_avail 0
if {[file exists /proc/meminfo]} {
    set fp [open /proc/meminfo r]
    while {[gets $fp line] >= 0} {
        if {[regexp {MemTotal:\s+(\d+)\s+kB} $line -> val]} { set mem_total [expr {$val / 1024}] }
        if {[regexp {MemAvailable:\s+(\d+)\s+kB} $line -> val]} { set mem_avail [expr {$val / 1024}] }
    }
    close $fp
}
set mem_used [expr {$mem_total - $mem_avail}]
set mem_pct 0
if {$mem_total > 0} {
    set mem_pct [expr {int(($mem_used * 100.0) / $mem_total)}]
}

# --- ANSI Styling Palette ---
set C_RESET  "\033\[0m"
set C_LOGO_N  "\033\[01;32m"
set C_LOGO  "\033\[01;37m"
set C_GRAY   "\033\[01;90m"
set C_LABEL  "\033\[38;5;141m"
set C_VAL    "\033\[38;5;81m"
set C_ACCENT "\033\[38;5;220m"
set C_GREEN  "\033\[38;5;82m"

# Version string check (using version comparison)
set ver_str "$nemsver"
if {$nemsveravail ne "" && ![catch {package vcompare $nemsveravail $nemsver} cmp] && $cmp > 0} {
    append ver_str " ${C_ACCENT}(Update available: $nemsveravail)${C_RESET}"
} else {
    append ver_str " ${C_GREEN}(Up to date)${C_RESET}"
}

# Progress Bars
set disk_bar [make_bar $usage 14]
set mem_bar  [make_bar $mem_pct 14]

# --- Output Rendering ---
puts ""
puts "  ${C_LOGO_N}███${C_GRAY}╗   ${C_LOGO_N}██${C_GRAY}╗${C_LOGO}███████${C_GRAY}╗${C_LOGO}███${C_GRAY}╗   ${C_LOGO}███${C_GRAY}╗${C_LOGO}███████${C_GRAY}╗"
puts "  ${C_LOGO_N}████${C_GRAY}╗  ${C_LOGO_N}██${C_GRAY}║${C_LOGO}██${C_GRAY}╔════╝${C_LOGO}████${C_GRAY}╗ ${C_LOGO}████${C_GRAY}║${C_LOGO}██${C_GRAY}╔════╝"
puts "  ${C_LOGO_N}██${C_GRAY}╔${C_LOGO_N}██${C_GRAY}╗ ${C_LOGO_N}██${C_GRAY}║${C_LOGO}█████${C_GRAY}╗  ${C_LOGO}██${C_GRAY}╔${C_LOGO}████${C_GRAY}╔${C_LOGO}██${C_GRAY}║${C_LOGO}███████${C_GRAY}╗"
puts "  ${C_LOGO_N}██${C_GRAY}║╚${C_LOGO_N}██${C_GRAY}╗${C_LOGO_N}██${C_GRAY}║${C_LOGO}██${C_GRAY}╔══╝  ${C_LOGO}██${C_GRAY}║╚${C_LOGO}██${C_GRAY}╔╝${C_LOGO}██${C_GRAY}║╚════${C_LOGO}██${C_GRAY}║"
puts "  ${C_LOGO_N}██${C_GRAY}║ ╚${C_LOGO_N}████${C_GRAY}║${C_LOGO}███████${C_GRAY}╗${C_LOGO}██${C_GRAY}║ ╚═╝ ${C_LOGO}██${C_GRAY}║${C_LOGO}███████${C_GRAY}║"
puts "  ${C_GRAY}╚═╝  ╚═══╝╚══════╝╚═╝     ╚═╝╚══════╝"
puts "                                  ${C_LOGO}LINUX${C_RESET}"
puts "${C_GRAY}           BY: ROBBIE FERGUSON\n              NEMSLINUX.COM${C_RESET}\n"
puts "  ${C_LABEL}Platform.....:${C_RESET} ${C_VAL}${nemsplatform}${C_RESET}"
puts "  ${C_LABEL}NEMS Version.:${C_RESET} ${C_VAL}${ver_str}"
puts "  ${C_LABEL}IP Address...:${C_RESET} ${C_VAL}${nemsip}${C_RESET}"
puts "  ${C_LABEL}Uptime.......:${C_RESET} ${C_VAL}${up_days}d ${up_hours}h ${up_mins}m${C_RESET}"
puts "  ${C_LABEL}System Load..:${C_RESET} ${C_VAL}${sysload_1} (1m)  ${sysload_5} (5m)  ${sysload_15} (15m)${C_RESET}"
puts "  ${C_LABEL}Memory.......:${C_RESET} ${C_VAL}\[${mem_bar}\] ${mem_pct}% (${mem_used} / ${mem_total} MB)${C_RESET}"
puts "  ${C_LABEL}Disk Usage...:${C_RESET} ${C_VAL}\[${disk_bar}\] ${usage}% (Root Partition)${C_RESET}"
puts "  ${C_LABEL}Processes....:${C_RESET} ${C_VAL}${psa} active processes${C_RESET}"
puts ""

if {[file exists /etc/changelog] && [file readable /etc/changelog]} {
    puts " ${C_ACCENT}─── System Messages ───────────────────────────────────────${C_RESET}"
    set fp [open /etc/changelog r]
    while {[gets $fp line] >= 0} {
        puts "   · $line"
    }
    close $fp
    puts ""
}
