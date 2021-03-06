#!/usr/bin/awk -f
#
# Creates a list of dependencies for compiling or linking.
#
# The command line arguments are used to produce a CPP command. The given
# files need to be processed by CPP in order to make sure macros and
# conditionals are (correctly) expanded.
#
# The output is filtered to only print files in the same directory or
# subdirectories of the given file. Paths can be added explicitly by using
# the -I argument.
#
# The following arguments receive special treatment:
#
# | Argument   | Description
# |------------|---------------------------------------------------
# | -compile   | Choose to produce a dependency list for compiling
# | -link      | Choose to produce a dependency list for linking
# | -I\<path\> | Paths are added to the output filter
#
# \section modes Modes of Operation
#
# The script can either create a dependency list for compiling or linking.
#
# In any mode the given file (multiple files can be chosen as well,
# but there is no useful use case) is passed to the CPP. The CPP resolves
# all includes.
#
# The includes are filtered from the CPP output by this script.
#
# In compile mode all files and includes are output once.
# In link mode includes are instead checked for heaving a corresponding
# C/C++ file that ends with the suffix \ref environment_SUFX.
# Only in that case is the file name printed and also recursively passed
# to the CPP.
#
# Modes can be combined.
#
# \section environment Environment
#
# If the following arguments are not set using AWK's -v argument, they can
# be set as environment variables.
#
# | Variable | Description
# |----------|-------------------------------------------------
# | DEBUG    | If set output debugging information on stderr
# | CPP      | The C/C++ preprocessor command, defaults to cpp
# | SUFX     | The file name suffix for c/c++ files
#
# \subsection environment_SUFX SUFX
#
# The SUFX variable defaults to the file ending of the first file name
# given in the arguments.
#
# Non-existing files are ignored during list-creation, this can be used
# to set the file ending by providing the desired file ending as the
# first argument:
#
#	awk -f depends.awk .c -link <file>
#

##
# Tests whether a file can be opened.
#
# @param file
#	The name of the file to test
# @retval 1
#	The file exists and can be read
# @retval 0
#	The file cannot be opened
#
function testf(file,
               retval, x) {
	retval = getline x <file
	close(file)
	return retval > 0
}

##
# Escape the given string for literal use in a regular expression.
#
# @param str
#	The string to escape
# @return
#	The escaped string
#
function rescape(str,
                 esc) {
	gsub(/\\/, "\\\\", str)
	for (esc in RESC) {
		gsub(esc, RESC[esc], str)
	}
	return str
}

##
# Escape the given string for command line use.
#
# @param str
#	The string to escape
# @return
#	The escaped string
#
function sescape(str,
                 esc) {
	gsub(/\\/, "\\\\", str)
	for (esc in ESC) {
		gsub(esc, SESC[esc], str)
	}
	return str
}

##
# Returns an arbitrary index from an array and deletes it.
#
# @param a
#	The array to fetch an arbitrary index from
# @return
#	An array index or nothing, if the array is empty
#
function extract(a,
                 i) {
	for (i in a) {
		delete a[i]
		return i
	}
}

##
# Returns whether any of the entries in a given array evalutate to true.
#
# @param a
#	The array to check for true entries
# @retval 0
#	No true entries
# @retval 1
#	At least one entry evaluates to true
#
function any(a,
             i) {
	for (i in a) {
		if (a[i]) {
			return 1
		}
	}
	return 0
}

##
# Returns a compacted version of the path.
#
# This gets rid of ../ by removing the previous path.
#
# @param path
#	The path to compact
# @return
#	The compacted path
#
function compact(path) {
	# 1st regex: Remove at the beginning of the path
	# 2nd regex: Remove in the path
	#
	#             │ Single char
	#             │     │ Two chars, no dot at the beginning
	#             │     │           │ Two chars, no dot 2nd char
	#             │     │           │           │ Three or more chars
	while(sub( /^([^\/]|[^\/.][^\/]|[^\/][^\/.]|[^\/][^\/][^\/]+)\/\.\.\//, "", path));
	while(sub(/\/([^\/]|[^\/.][^\/]|[^\/][^\/.]|[^\/][^\/][^\/]+)\/\.\.\//, "/", path));
	return path;
}

##
# Perform recursive include and output C/C++ file names.
#
# - Setup environment setable globals
# - Initialize escape tables for the rescape() and sescape() funcitons
# - Read command line arguments
#	- Assemble the CPP command
#	- Collect files to pass to cpp
#	- Guess the project paths from the given files
#	- Detect SUFX using the first file encountered
# - Process files recursively
#
BEGIN {
	# Get environment settings
	DEBUG = (DEBUG ? DEBUG : ENVIRON["DEBUG"])
	CPP = (CPP ? CPP : ("CPP" in ENVIRON ? ENVIRON["CPP"] : "cpp"))
	SUFX = (SUFX ? SUFX : ENVIRON["SUFX"])

	# Running modes
	MODE["COMPILE"] = 0
	MODE["LINK"] = 0

	# String escapes for regular expressions
	# RESC[<regex>] = <replace>
	RESC["\\."] = "\\."
	RESC["\\?"] = "\\?"
	RESC["\\*"] = "\\*"
	RESC["\\+"] = "\\+"
	RESC["\\{"] = "\\{"
	RESC["\\}"] = "\\}"
	RESC["\\("] = "\\("
	RESC["\\)"] = "\\)"
	RESC["\\["] = "\\["
	RESC["\\]"] = "\\]"

	# String escapes for command line arguments
	# SESC[<regex>] = <replace>
	SESC[" "] = "\\ "
	SESC["\t"] = "\\\t"
	SESC["\n"] = "\\\n"
	SESC["\\?"] = "\\?"
	SESC["\\*"] = "\\*"
	SESC["\\{"] = "\\{"
	SESC["\\}"] = "\\}"
	SESC["\\("] = "\\("
	SESC["\\)"] = "\\)"
	SESC["\\["] = "\\["
	SESC["\\]"] = "\\]"
	SESC["\\\""] = "\\\""
	SESC["\\'"] = "\\'"

	#
	# Read command line arguments
	#

	# An array of C/C++ files to check for linking
	delete files
	# A string withe the full CPP command
	cmd = CPP
	# A regular expression filter for file names that should be output
	pass = "("
	for (i = 1; i < ARGC; i++) {
		# Set mode
		if (ARGV[i] == "-compile") {
			MODE["COMPILE"] = 1
			continue
		}
		if (ARGV[i] == "-link") {
			MODE["LINK"] = 1
			continue
		}
		# Join -I with the path
		if (ARGV[i] == "-I") {
			delete ARGV[i++]
			ARGV[i] = "-I" ARGV[i]
		}
		#
		# Extracts paths from -I arguments and file names and
		# appends arguments to cmd.
		#
		path = ""
		# Deal with -I
		if (ARGV[i] ~ /^-I.+/) {
			path = ARGV[i]
			sub(/^-I/, "", path)
			sub(/\/?$/, "/", path)
			cmd = cmd " " sescape(ARGV[i]) " "
		} else
		# Put file into files array
		if (ARGV[i] !~ /^-/) {
			path = ARGV[i]
			sub(/\/[^\/]*$/, "/", path)
			# Remove ..
			$2 = compact($2)
			# Store file in array
			files[ARGV[i]]
			# Fall back to auto-suffix if none is given
			if (!SUFX) {
				SUFX = ARGV[i]
				sub(/.*\./, ".", SUFX)
			}
		} else
		# Append argument to cmd
		{
			cmd = cmd " " sescape(ARGV[i]) " "
		}
		# Build the file name filter pass
		if (path) {
			# Remove ../
			path = compact(path)
			if (!(path in paths)) {
				paths[path]
				pass = pass "^" rescape(path) "|"
			}
		}
	}
	sub(/\|$/, ")", pass)
	delete paths
	delete ARGV
	if (DEBUG) {
		print "depends.awk: pass = " pass > "/dev/stderr"
	}

	#
	# Check for mode setting.
	#
	if (!any(MODE)) {
		print "depends.awk: error: No valid mode set! Please " \
		      "provide -compile or -link." > "/dev/stderr"
		exit 1
	}

	#
	# Hand files to CPP and get the linkable includes
	#
	FS = "\""
	while (file = extract(files)) {
		runcmd = cmd " " sescape(file) " 2> /dev/null"
		if (DEBUG) {
			print "depends.awk: " runcmd > "/dev/stderr"
		}

		while ((runcmd | getline) > 0) {
			# Skip lines that are not file references
			if ($0 !~ /# [0-9]+ "/) {
				continue
			}

			# Remove ../
			$2 = compact($2)
			# Skip files from wrong folders
			if ($2 !~ pass) {
				continue
			}
			# Print compile dependency
			if (MODE["COMPILE"] && !output[$2]++) {
				print($2)
			}
			# Only objects created from C/C++ files need
			# to be linked
			if (MODE["LINK"] && sub(/\.[^.]*$/, SUFX, $2) &&
			    !output[$2]++ && testf($2)) {
				if ($2 != file) {
					files[$2]
				}
				print($2)
			}
		}
		close(runcmd)
	}
	exit 0
}

