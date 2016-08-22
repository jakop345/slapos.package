

template:

	./prepare_templates.sh

download_cache:

	./prepare_download_cache.sh || (echo "Impossible to build SlapOS, exiting." && exit 1)

tarball:

	./prepare_tarball.sh

deb:

	./prepare_debian.sh

obs:

	./prepare_obs_upload.sh


all: template download_cache tarball deb obs

.PHONY: template download_cache tarball deb obs
