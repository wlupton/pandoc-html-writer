PANDOC = pandoc --from=commonmark_x

all: sample-default-writer.html sample-custom-writer.html

sample-default-writer.html: sample.md
	$(PANDOC) $< --output $@

sample-custom-writer.html: sample.md
	$(PANDOC) --to=html-derived-writer.lua $< --output $@

clean:
	$(RM) sample-*.html
