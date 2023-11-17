#!/bin/sh

if [ "$#" -ne 4 ]; then
	echo "Usage: $0 key value file assignation_operator"
	exit 1
fi

key="$1"
value="$2"
file="$3"
assignation="$4"

if [ ! -f "$file" ]; then
	echo "Error: File '$file' does not exist."
	exit 1
fi

if [ ! -w "$file" ]; then
	echo "Error: File '$file' is not writable."
	exit 1
fi

if grep -q "^[[:space:];#]*$key" "$file"; then
	sed -i "s|^[[:space:];#]*$key.*|$key$assignation$value|" "$file"
	echo "Updated key '$key' with value '$value' in '$file'."
else
	echo "$key$assignation$value" >> "$file"
	echo "Appended key '$key' with value '$value' to '$file'."
fi
