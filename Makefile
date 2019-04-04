ifeq ($(shell uname -s),Darwin)
SED := gsed
else
SED := sed
endif

INPUT := $(sort $(wildcard src/content/*.html))
OUTPUT := $(patsubst src/content/%.html,public/index-%.html,$(INPUT))

TEMP_TITLE_FILE := $(TMPDIR)/communitycodeofconduct-title
TEMP_CONTENT_FILE := $(TMPDIR)/communitycodeofconduct-content

.PHONY: all
all: $(OUTPUT)

public/index-%.html: src/content/%.html
	@ echo $< '->' $@
	@ if [[ -e 'src/titles/$*.html' ]]; then \
		$(SED) -r -e 's/^/    /' -e 's/\s+$$//' src/titles/$*.html > $(TEMP_TITLE_FILE); \
	else \
		$(SED) -r -e 's/^/    /' -e 's/\s+$$//' src/titles/en.html > $(TEMP_TITLE_FILE); \
	fi
	@ $(SED) -r -e 's/^/    /' -e 's/\s+$$//' $< > $(TEMP_CONTENT_FILE)
	@ $(SED) -r \
		-e '/^\s*\{\{title\}\}\s*$$/r $(TEMP_TITLE_FILE)' -e '//d' \
		-e '/^\s*\{\{content\}\}\s*$$/r $(TEMP_CONTENT_FILE)' -e '//d' \
		src/index.html > $@
