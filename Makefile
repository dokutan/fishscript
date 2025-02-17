fishscript: fishscript.fnl fishlib.fnl
	echo "#!/usr/bin/env lua" > fishscript
	fennel --require-as-include --compile fishscript.fnl >> fishscript
	chmod +x fishscript
