op: var/doc/op.jp

var/doc/op.jp: doc/smm/*wix
	env FML=${FML} $(SH) distrib/bin/DocReconfigure.op

.for file in ${DOC_DRAFT_SOURCES}
__DOC_TARGETS__ += var/doc/drafts/${file}.jp
__DOC_TARGETS__ += var/doc/drafts/${file}.en
var/doc/drafts/${file}.jp: doc/drafts/${file}.wix
	${FWIX} -n i doc/drafts/${file}.wix > var/doc/drafts/${file}.jp

var/doc/drafts/${file}.en: doc/drafts/${file}.wix
	${FWIX} -L ENGLISH -n i doc/drafts/${file}.wix > var/doc/drafts/${file}.en
.endfor

.for file in ${DOC_RI_SOURCES} ${DOC_RI_EXCEPTIONAL_SOURCES}
__DOC_TARGETS__ += var/doc/${file}.jp
__DOC_TARGETS__ += var/doc/${file}.en
var/doc/${file}.jp: doc/ri/${file}.wix
	${FWIX} -n i doc/ri/${file}.wix > var/doc/${file}.jp

var/doc/${file}.en: doc/ri/${file}.wix
	${FWIX} -L ENGLISH -n i doc/ri/${file}.wix > var/doc/${file}.en
.endfor


### MAIN ###
__initplaindocbuild__:
	@ echo --plaindoc
	@ test -d var/doc/drafts || mkdir var/doc/drafts
	@ test -d var/doc || mkdir var/doc

plaindocbuild: __initplaindocbuild__ ${__DOC_TARGETS__} op
	@ echo --plaindoc done.
