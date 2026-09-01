// SPDX-License-Identifier: MIT
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <png.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#include <drm.h>
#include <drm_mode.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

#define WAIT_MS 50
#define WAIT_LIMIT_MS 15000
#define CARBON_R 0x07
#define CARBON_G 0x11
#define CARBON_B 0x1f

struct image {
	uint32_t width;
	uint32_t height;
	uint8_t *rgba;
};

struct framebuffer {
	uint32_t id;
	uint32_t handle;
	uint32_t pitch;
	uint64_t size;
	uint8_t *map;
};

static void sleep_poll_interval(void)
{
	struct timespec delay = { .tv_sec = 0, .tv_nsec = WAIT_MS * 1000000L };
	nanosleep(&delay, NULL);
}

static int open_drm_card(void)
{
	DIR *dir = opendir("/dev/dri");
	struct dirent *entry;
	char path[PATH_MAX];
	int fd = -1;

	if (!dir)
		return -1;

	while ((entry = readdir(dir))) {
		if (strncmp(entry->d_name, "card", 4) != 0)
			continue;
		snprintf(path, sizeof(path), "/dev/dri/%s", entry->d_name);
		fd = open(path, O_RDWR | O_CLOEXEC);
		if (fd >= 0)
			break;
	}
	closedir(dir);
	return fd;
}

static drmModeConnector *find_connector(int fd, drmModeRes *resources)
{
	int i;

	for (i = 0; i < resources->count_connectors; i++) {
		drmModeConnector *connector =
			drmModeGetConnector(fd, resources->connectors[i]);
		if (!connector)
			continue;
		if (connector->connection == DRM_MODE_CONNECTED && connector->count_modes)
			return connector;
		drmModeFreeConnector(connector);
	}
	return NULL;
}

static uint32_t find_crtc(int fd, drmModeRes *resources,
			  drmModeConnector *connector)
{
	int i, j;

	for (i = 0; i < connector->count_encoders; i++) {
		drmModeEncoder *encoder = drmModeGetEncoder(fd, connector->encoders[i]);
		if (!encoder)
			continue;
		if (encoder->crtc_id) {
			uint32_t crtc_id = encoder->crtc_id;
			drmModeFreeEncoder(encoder);
			return crtc_id;
		}
		for (j = 0; j < resources->count_crtcs; j++) {
			if (encoder->possible_crtcs & (1U << j)) {
				uint32_t crtc_id = resources->crtcs[j];
				drmModeFreeEncoder(encoder);
				return crtc_id;
			}
		}
		drmModeFreeEncoder(encoder);
	}
	return 0;
}

static int load_png(const char *path, struct image *image)
{
	png_image png = { .version = PNG_IMAGE_VERSION };

	if (!png_image_begin_read_from_file(&png, path))
		return -1;
	png.format = PNG_FORMAT_RGBA;
	image->width = png.width;
	image->height = png.height;
	image->rgba = malloc(PNG_IMAGE_SIZE(png));
	if (!image->rgba) {
		png_image_free(&png);
		return -1;
	}
	if (!png_image_finish_read(&png, NULL, image->rgba, 0, NULL)) {
		free(image->rgba);
		image->rgba = NULL;
		return -1;
	}
	return 0;
}

static int create_framebuffer(int fd, uint32_t width, uint32_t height,
			      struct framebuffer *fb)
{
	struct drm_mode_create_dumb create = { 0 };
	struct drm_mode_map_dumb map = { 0 };

	create.width = width;
	create.height = height;
	create.bpp = 32;
	if (ioctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &create) < 0)
		return -1;
	fb->handle = create.handle;
	fb->pitch = create.pitch;
	fb->size = create.size;
	if (drmModeAddFB(fd, width, height, 24, 32, fb->pitch, fb->handle,
			 &fb->id) != 0)
		return -1;
	map.handle = fb->handle;
	if (ioctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &map) < 0)
		return -1;
	fb->map = mmap(NULL, fb->size, PROT_READ | PROT_WRITE, MAP_SHARED, fd,
		       map.offset);
	return fb->map == MAP_FAILED ? -1 : 0;
}

static int render(uint8_t *buffer, uint32_t pitch, uint32_t width,
		  uint32_t height, const struct image *splash)
{
	uint32_t x, y;

	if (splash->width != width || splash->height != height)
		return -1;

	for (y = 0; y < height; y++) {
		uint32_t *row = (uint32_t *)(buffer + y * pitch);

		for (x = 0; x < width; x++) {
			const uint8_t *pixel = splash->rgba + (y * width + x) * 4;
			uint32_t alpha = pixel[3];
			uint32_t red = (pixel[0] * alpha + CARBON_R * (255 - alpha)) / 255;
			uint32_t green = (pixel[1] * alpha + CARBON_G * (255 - alpha)) / 255;
			uint32_t blue = (pixel[2] * alpha + CARBON_B * (255 - alpha)) / 255;
			row[x] = (red << 16) | (green << 8) | blue;
		}
	}
	return 0;
}

int main(int argc, char **argv)
{
	drmModeRes *resources = NULL;
	drmModeConnector *connector = NULL;
	drmModeModeInfo mode;
	struct framebuffer fb = { 0 };
	struct image logo = { 0 };
	uint32_t crtc_id = 0;
	int waited, fd = -1, result = EXIT_FAILURE;

	if (argc != 2 || load_png(argv[1], &logo) != 0) {
		fprintf(stderr, "screen-splash: cannot load logo\n");
		return EXIT_FAILURE;
	}

	for (waited = 0; waited < WAIT_LIMIT_MS; waited += WAIT_MS) {
		fd = open_drm_card();
		if (fd >= 0) {
			resources = drmModeGetResources(fd);
			if (resources)
				connector = find_connector(fd, resources);
			if (connector) {
				crtc_id = find_crtc(fd, resources, connector);
				if (crtc_id)
					break;
				drmModeFreeConnector(connector);
				connector = NULL;
			}
			if (resources) {
				drmModeFreeResources(resources);
				resources = NULL;
			}
			close(fd);
			fd = -1;
		}
		sleep_poll_interval();
	}

	if (!connector) {
		fprintf(stderr, "screen-splash: no connected DRM output after %d ms\n",
			WAIT_LIMIT_MS);
		goto out;
	}

	mode = connector->modes[0];
	if (create_framebuffer(fd, mode.hdisplay, mode.vdisplay, &fb) != 0) {
		fprintf(stderr, "screen-splash: framebuffer creation failed: %s\n",
			strerror(errno));
		goto out;
	}
	if (render(fb.map, fb.pitch, mode.hdisplay, mode.vdisplay, &logo) != 0) {
		fprintf(stderr,
			"screen-splash: image is %ux%u, but DRM mode requires %ux%u\n",
			logo.width, logo.height, mode.hdisplay, mode.vdisplay);
		goto out;
	}
	if (drmModeSetCrtc(fd, crtc_id, fb.id, 0, 0, &connector->connector_id, 1,
			   &mode) != 0) {
		fprintf(stderr, "screen-splash: modeset failed: %s\n", strerror(errno));
		goto out;
	}
	fprintf(stdout, "screen-splash: displayed native %ux%u splash on connector %u\n",
		mode.hdisplay, mode.vdisplay, connector->connector_id);
	if (drmDropMaster(fd) != 0) {
		fprintf(stderr, "screen-splash: cannot release DRM master: %s\n",
			strerror(errno));
		goto out;
	}

	/*
	 * Keep the framebuffer alive without retaining DRM mastership. Once the UI
	 * replaces our scanout, exit and release the old dumb buffer automatically.
	 */
	for (;;) {
		drmModeCrtc *crtc;

		sleep_poll_interval();
		crtc = drmModeGetCrtc(fd, crtc_id);
		if (crtc && crtc->buffer_id != fb.id) {
			drmModeFreeCrtc(crtc);
			break;
		}
		if (crtc)
			drmModeFreeCrtc(crtc);
	}
	result = EXIT_SUCCESS;

out:
	/* Do not remove the framebuffer: it remains scanned out until the UI modesets. */
	free(logo.rgba);
	if (connector)
		drmModeFreeConnector(connector);
	if (resources)
		drmModeFreeResources(resources);
	if (fd >= 0)
		close(fd);
	return result;
}
