WebLogic Server Administration Script
==============

wladmin is a shell script which is used to manage weblogic domains. The script is intended to administer multiple weblogic domains spread across multiple Linux hosts.

`The script has been tested in all flavours of unix OS, including AIX, Solaris, Darwin. The script is primarily developed for Linux on bash shell`

Remote administration capabilities of the script relies on ssh key sharing and expects the script library to be present in the PATH of the remote host as well.

It is recommended that the script be installed on a shared drive which is mounted on all the hosts which needs to be administered.

Script Installation Layout
--------------------------

The main directories in the script home are

- etc : All configuration files are maintained in this folder.
- libs : All additional script modules are located here.
- store : Application environment specific files are located here, this is a convention and is sometimes softlinked, included in the application bootstrap classpath.
- docs : Documentation related to the shell scripts are maintained here.

Configuration
-------------

The configuration of the wladmin script is sourced from two locations.

- etc/servers.conf
- etc/setEnv.sh

servers.conf file holds the configuration of all the servers adminstered by the wladmin script. This is a space separated config file where each line represents the configuration of a single weblogic server instance. Lines starting with a # character is treated as comments.

The columns in the servers.conf files in the order of appearance are

| Column Name | Description | Remarks |
|-------------|-------------|---------|
| Server Name | This is the name of the weblogic server as it given during domain creation, this can be either be the we


Usage
-----

The general usage syntax of the command is 

`wladmin <operation> <domain|cluster|instance> [<flags>]`

The first argument is the operation that has to be performed followed by the target. The target could be the weblogic domain, cluster or instance. Depending on the target the operation is performed on all the members of the group. The third argument is an optional flag the valid values are documented with the corresponding operation.


