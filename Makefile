.PHONY: all gem push_gem test jrtest doc clean

all: | gem

gem: | fix_version
	gem build iomultiplex.gemspec

push_gem: | gem
	build/push_gem

test: | all vendor/bundle/.GemfileModT
	bundle exec rspec $(TESTS)

jrtest: | all vendor/bundle/.GemfileJRubyModT
	jruby -G vendor/bundle/jruby/1.9/bin/rspec $(TESTS)

doc:
	@npm --version >/dev/null || (echo "'npm' not found. You need to install node.js.")
	@npm install doctoc >/dev/null || (echo "Failed to perform local install of doctoc.")
	@node_modules/.bin/doctoc README.md
	@for F in docs/*.md; do node_modules/.bin/doctoc $$F; done

vendor/bundle/.GemfileModT: Gemfile
	bundle install --path vendor/bundle
	@touch $@

vendor/bundle/.GemfileJRubyModT: Gemfile
	jruby -S bundle install --path vendor/bundle
	@touch $@

clean:
	rm -rf vendor/bundle
	rm -f Gemfile.lock
	rm -f *.gem

fix_version:
	build/fix_version "${FIX_VERSION}"
