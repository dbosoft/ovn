EXTRA_DIST += \
	build-aux/calculate-schema-cksum \
	build-aux/cccl \
	build-aux/cksum-schema-check \
	build-aux/dist-docs \
	build-aux/dpdkstrip.py \
	build-aux/generate-dhparams-c \
	build-aux/initial-tab-whitelist \
	build-aux/libtool-deps \
	build-aux/sodepends.py \
	build-aux/soexpand.py \
	build-aux/text2c \
	build-aux/xml2nroff \
	build-aux/envdiff.ps1

FLAKE8_PYFILES += \
    $(srcdir)/build-aux/xml2nroff \
    build-aux/dpdkstrip.py \
    build-aux/sodepends.py \
    build-aux/soexpand.py
