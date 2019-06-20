NULL = 
ACLOCAL_AMFLAGS = -I m4

SUBDIRS = \
	neighborhood \
	$(NULL)

bin_PROGRAMS =  \
	system_ntkd \
	$(NULL)

system_ntkd_SOURCES =  \
	system_ntkd.vala \
	$(NULL)

system_ntkd_VALAFLAGS = \
	--pkg gee-0.8 \
	$(NULL)

system_ntkd_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

system_ntkd_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(NULL)

