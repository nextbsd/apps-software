# Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
# SPDX-License-Identifier: BSD-2-Clause
#
# Software.app: NextBSD's app store. The catalog (Resources/Catalog.plist,
# made by ../catalog/make-catalog.py) and every listed app's icon
# (Resources/CatalogIcons, fetched by ../catalog/fetch-icons.py, with
# their CREDITS) are bundled, so it opens instantly and offline.
# Installed like the other desktop apps, in the USER domain
# (~/Applications) for now.

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES)
endif
include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Software
Software_OBJC_FILES = main.m SWController.m SWCatalog.m SWInstaller.m \
	SWViews.m
Software_HEADER_FILES = SWController.h SWCatalog.h SWInstaller.h SWViews.h
Software_RESOURCE_FILES = Resources/Software.png Resources/Catalog.plist \
	Resources/CatalogIcons
Software_APPLICATION_ICON = Software.png
Software_OBJCFLAGS = -Wall -Wextra -Wno-unused-parameter

include $(GNUSTEP_MAKEFILES)/application.make
