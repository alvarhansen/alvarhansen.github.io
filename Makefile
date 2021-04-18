dev:
	docker run --rm \
		--volume="${PWD}:/srv/jekyll" \
		-p 4000:4000 \
		-p 35729:35729 \
		-it jekyll/jekyll:4.0 \
		jekyll serve --drafts --livereload