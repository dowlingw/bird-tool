[![Stories in Ready](https://badge.waffle.io/dowlingw/bird-tool.png?label=ready&title=Ready)](https://waffle.io/dowlingw/bird-tool)
bird-tool
=========

Useful scripts for BIRD Route Servers.


Dependencies
------------
These scripts rely on the following CPAN modules:
-    Date::Parse
-    DateTime
-    DateTime::Format::Duration
-    Net::IP
-    Switch
-    Template

You can install these dependencies via the following command:

    cpan Date::Parse DateTime DateTime::Format::Duration Net::IP Switch Template

Or, if you are running a Debian-based Linux system with the following:

    apt-get install libtimedate-perl libdatetime-perl libdatetime-format-duration-perl libnet-ip-perl libswitch-perl libtemplate-perl


bird_query.pl
-------------
Script to show peer and prefix information for configured sessions.

Currently assumes all interesting session names begin with R_AS - this can easily be changed later.

Useful arguments for the script - unless otherwise noted can be combined:
-    `-help`          Display full usage information
-    `-l`             Output a list of peered ASNs, one per line. Not compatible with any other option
-    `-a ASNUM`       Only query session information for the specified AS Number
-    `-s`             Show filtered/accepted prefixes, not compatible with `-n` or `-p`
-    `-p`             Output data in perfdata format for graphing
-    `-n`             Runs as a NAGIOS check, can be combined with `-p`
-    `-6`             Query on the socket for IPv6 BIRD
-    `-x`             Output a list of accepted prefixes, one per line. Not compatible with `-s`, `-n` or `-p`

This module now provides its own IPC with BIRD daemon via the birdc command.


generate_config.pl
------------------
Interactively prompts for information and generates a configuration fragment for a peer.

Configuration fragment is generated using the template `config_template.tt`


cacti/scripts/bird_peerinfo.pl
------------------------
A Cacti graph script to make the output of `bird_tool.pl` accessible for graphing in Cacti.

Because your network may work differently to others, we don't try and run bird-tool
(which must be run on the same machine as BIRD itself) on your Cacti server.

Instead, you must set up your own mechanism for exporting the output of `bird_tool.pl -p` to your Cacti host.
You can do this yourself via Nagios/NRPE, cron or a custom method each time `bird_peerinfo.pl` runs.

By doing this, we can:
-    Run Cacti on a separate host to BIRD
-    Avoid hitting BIRD directly for each graph item
-    Use whatever mechanism you feel comfortable with sending/receiving graphing data across your network

Script arguments explained:
-    `-pre SCRIPT`	Runs the specified executable prior to running
-    `-path PATH`	Path to look for bird-tool output files
-    `-host IPHOST`	IP/Host Name of the BIRD server used to load the bird-tool output file
-    `-6`		Indicates that we are interested in the bird-tool output for IPv6
-    `-index`		(Cacti) Outputs a list of BGP peers in bird-tool output
-    `-query PROPERTY`	(Cacti) Outputs the bird-tool field to be returned for all peers
-    `-get PROPERTY AS`	(Cacti) Outputs the bird-tool field to be returned for the specified AS

The `bird_peerinfo.pl` script will look for the file `PATH/IPHOST[_v6]` on the local Cacti host.

How to get started:
-    Run `bird-tool -p > somefile`
-    Ship the file to your Cacti host (or write a script to pull it with `-pre`
-    Edit the `cacti/resource/script_queries/bird_peers*.xml` files to set the `-pre` option Cacti will use
-    Import the XML files as 'Script Data Queries' in Cacti
-    Profit!

Coming Soon: Full set of templates for BIRD route servers using bird-tool



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
