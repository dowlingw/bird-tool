bird-tool
=========

Useful scripts for BIRD Route Servers.


bird_query.pl
-------------
Script to show peer and prefix information for configured sessions.

Currently assumes all interesting session names begin with R_AS - this can easily be changed later.

Useful arguments for the script - unless otherwise noted can be combined:
-    `-help`          Display full usage information
-    `-a ASNUM`       Only query session information for the specified AS Number
-    `-s`             Show filtered/accepted prefixes, not compatible with -n or -p
-    `-p`             Output data in perfdata format for graphing
-    `-n`             Runs as a NAGIOS check, can be combined with -p
-    `-6`             Query on the socket for IPv6 BIRD

Relies on birdctl perl module from here:
https://github.com/stephank/nagios-bird


generate_config.pl
------------------
Interactively prompts for information and generates a configuration fragment for a peer.

Configuration fragment is generated using the template `config_template.tt`



Copyright and license
---------------------
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.



[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/d9ffa8693e50ac0e1b3469d29b458974 "githalytics.com")](http://githalytics.com/dowlingw/bird-tool)
