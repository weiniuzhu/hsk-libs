#!/usr/bin/awk -f

# Seperates C instructions into individual lines, streamlining the formatting

BEGIN {
	RS = "\0"
	# Collect parameters
	for (i = 1; i < ARGC; i++) {
		if (ARGV[i] ~ /^-.$/) {
			args = args " " ARGV[i] " " ARGV[i + 1] " "
			delete ARGV[i++]
			delete ARGV[i]
		} else if (ARGV[i] ~ /^-/) {
			args = args " " ARGV[i] " "
			delete ARGV[i]
		}
	}
}

#
# Accumulate and preprocess files so they become easier to parse
#
{
	# Preprocess file, so there is no trouble with unknown symbols
	cmd = (ENVIRON["CPP"] ? ENVIRON["CPP"] : "cpp") " " args incdirs FILENAME " 2> /dev/null"
	$0 = ""
	while (cmd | getline line) {
		$0 = $0 line "\n"
	}
	close(cmd)
	# Remove escaped newlines
	gsub(/\\(\r\n|\n)/, " ")
	# Remove comments
	gsub(/\/\*(\*[^\/]|[^\*])*\*\//, "")
	# Isolate preprocessor comments
	gsub("(^|\n)[[:space:]]*#[^\n]*", "&\177")
	# Collapse spaces
	gsub(/[[:space:]\r\n]+/, " ")
	# Remove obsolete spaces
	sub(/^ /, "")
	split("{}()|?*+^[].", ctrlchars, "")
	for (i in ctrlchars) {
		gsub(" ?\\" ctrlchars[i] " ?", ctrlchars[i])
	}
	split("#=!<>;:,/-%~\"\177", ctrlchars, "")
	ctrlchars["&"] = "\\&"
	for (i in ctrlchars) {
		gsub(" ?" ctrlchars[i] " ?", ctrlchars[i])
	}
	# Add newlines behind statements
	gsub(/\177/, "\n")
	gsub(/;/, "&\n")
	# Segregate nested code
	gsub(/[{}]/, "\n&\n")
	# Segregate labels from the code following them
	gsub(/:([[:alnum:]_]+|case [^:]+):/, "&\n")
	gsub(/(^|\n)([[:alnum:]_]+|case [^:]+):/, "&\n")
	# Remove empty lines
	gsub(/\n+/, "\n")
	printf "#1\"%s\"\n%s", FILENAME, $0
}

