bird-tool
=========

Script for providing useful information from BIRD - shows BGP sessions and prefixes.

Currently assumes all interesting session names begin with R_AS - this can easily be changed later.
Hasn't been tested (yet) with BGPv6, but probably works just fine.

Useful arguments for the script:
-    -a ASNUM    Only query session information for the specified AS Number
-    -s                 Show filtered/accepted prefixes
-    -p                 Output data in perfdata format for graphing
-    -a ASNUM -n        Runs as a NAGIOS check, can be combined with -p

Written for the kind folks over at the WAIA for their Australian Internet Exchanges.
If you need peering in Australia, check them out: http://www.waia.asn.au/

Relies on birdctl perl module from here:

https://github.com/stephank/nagios-bird


[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/d9ffa8693e50ac0e1b3469d29b458974 "githalytics.com")](http://githalytics.com/dowlingw/bird-tool)
