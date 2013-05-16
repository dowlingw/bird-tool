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


bird_peerinfo.pl (cacti)
------------------------
A Cacti graph script to translate the output of `bird_tool.pl` for cacti.

It will then present the peers as data queries in Cacti - making adding peer graphs easy as clicking "Add Graphs for this Host".

This is useful for graphing the number of prefixes accepted/filtered.


The script reads in a file with the output of `bird_tool.pl -p` and enumerates the data for each peer.
By reading from a file we:
-    Avoid hitting BIRD directly for each graph item
-    Run Cacti on a separate host to BIRD
-    Use whatever mechanism you feel comfortable with sending/receiving graphing data across your network


To get things going, for each route server run `bird_tool.pl -p > /path/to/bird-tool/output/IPADDRESS`.
For graphing IPv6 information, do the same but with `bird_tool.pl -6 -p > /path/to/bird-tool/output/IPADDRESS_v6`.

Once you're shipping the files to the Cacti server, edit the two XML files and change the `-path /path/to/bird-tool/output` setting in `arg_prepend` to the location where you are storing the generated files.

Then you can import the XML files as 'Data Queries' in Cacti and build your graphs accordingly.

*COMING SOON:* Full dataquery/graph/host templates



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
