### procs
HTML_FILTER = $(FML)/bin/fwix.pl -m htmlconv 


### fundamental rules

.for file in ${DOC_EXAMPLE_SOURCES}
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${file}.html
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${file}-e.html

${WORK_EXAMPLES_DIR}/${file}.html: doc/examples/${file}.wix
	${HTML_FILTER} -L JAPANESE -n i \
		-o ${WORK_EXAMPLES_DIR}/${file}.html doc/examples/${file}.wix

${WORK_EXAMPLES_DIR}/${file}-e.html: doc/examples/${file}.wix
	${HTML_FILTER} -L ENGLISH -n i \
		-o ${WORK_EXAMPLES_DIR}/${file}-e.html doc/examples/${file}.wix
.endfor



### doc/examples/*txt
__HTML_EXAMPLES_TXT__ = makefml.cgi cgi-INSTALL cgi-TODO cgi-IMPLEMENTATION

.for file in ${__HTML_EXAMPLES_TXT__}
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${file}.txt
${WORK_EXAMPLES_DIR}/${file}.txt: doc/examples/${file}.txt
	${JCONV} doc/examples/${file}.txt > ${WORK_EXAMPLES_DIR}/${file}.txt
.endfor


### doc/examples/index{,-e}.html and doc/examples/*html
__HTML_EXAMPLES_HTML__ += index index-e
__HTML_EXAMPLES_HTML__ += ptr-customize-header

.for file in ${__HTML_EXAMPLES_HTML__}
__HTML_EXAMPLES__ += ${WORK_EXAMPLES_DIR}/${file}.html
${WORK_EXAMPLES_DIR}/${file}.html: doc/examples/${file}.html
	${JCONV} doc/examples/${file}.html > ${WORK_EXAMPLES_DIR}/${file}.html
.endfor
