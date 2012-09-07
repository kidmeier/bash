function etags() {

	if [ -n "$1" ];	then
	
		base=$1; shift

	else

		base=$PWD
		until [ -f "$base/.project" ]
		do
			base=$base/..
		done

	fi

	find "$base" -name '*.c' -o -name '*.cpp' -o -name '*.h' | xargs etags -o "$base/TAGS"

}
