// SPDX-License-Identifier: MIT
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <math.h>
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

#define DRM_WAIT_MS 50
#define WAIT_LIMIT_MS 15000
#define FRAME_INTERVAL_NS 33333333L
#define HANDOFF_POLL_FRAMES 3
#define ANIMATION_PERIOD_MS 2400
#define ANIMATION_HOLD_MS 300
#define ARC_SWEEP_MS 1300
#define MARK_LANDSCAPE_X_MIN 240
#define MARK_LANDSCAPE_X_MAX 620
#define MARK_LANDSCAPE_Y_MIN 449
#define MARK_LANDSCAPE_Y_MAX 749
#define ARC_GLINT_X_MIN 285
#define ARC_GLINT_X_MAX 575
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
	struct timespec delay = { .tv_sec = 0, .tv_nsec = DRM_WAIT_MS * 1000000L };
	nanosleep(&delay, NULL);
}

static void add_nanoseconds(struct timespec *time, long nanoseconds)
{
	time->tv_nsec += nanoseconds;
	if (time->tv_nsec >= 1000000000L) {
		time->tv_sec++;
		time->tv_nsec -= 1000000000L;
	}
}

static int timespec_after(const struct timespec *left,
			  const struct timespec *right)
{
	return left->tv_sec > right->tv_sec ||
		(left->tv_sec == right->tv_sec && left->tv_nsec > right->tv_nsec);
}

static void sleep_until(struct timespec *deadline)
{
	struct timespec now, delay;

	clock_gettime(CLOCK_MONOTONIC, &now);
	if (timespec_after(&now, deadline)) {
		/* Drop a late frame rather than spinning to catch up. */
		*deadline = now;
		return;
	}
	delay.tv_sec = deadline->tv_sec - now.tv_sec;
	delay.tv_nsec = deadline->tv_nsec - now.tv_nsec;
	if (delay.tv_nsec < 0) {
		delay.tv_sec--;
		delay.tv_nsec += 1000000000L;
	}
	while (nanosleep(&delay, &delay) != 0 && errno == EINTR)
		;
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

static const uint8_t *source_pixel(const struct image *splash, uint32_t x,
				   uint32_t y, uint32_t width, uint32_t height)
{
	uint32_t source_x, source_y;

	if (splash->width == width && splash->height == height) {
		source_x = x;
		source_y = y;
	} else {
		/* Rotate clockwise, then flip native Y for the physical panel mounting. */
		source_x = splash->width - 1 - y;
		source_y = splash->height - 1 - x;
	}
	return splash->rgba + (source_y * splash->width + source_x) * 4;
}

static int render(uint8_t *buffer, uint32_t pitch, uint32_t width,
		  uint32_t height, const struct image *splash)
{
	uint32_t x, y;

	if (!((splash->width == width && splash->height == height) ||
	      (splash->width == height && splash->height == width)))
		return -1;

	for (y = 0; y < height; y++) {
		uint32_t *row = (uint32_t *)(buffer + y * pitch);

		for (x = 0; x < width; x++) {
			const uint8_t *pixel = source_pixel(splash, x, y, width, height);
			uint32_t alpha = pixel[3];
			uint32_t red = (pixel[0] * alpha + CARBON_R * (255 - alpha)) / 255;
			uint32_t green = (pixel[1] * alpha + CARBON_G * (255 - alpha)) / 255;
			uint32_t blue = (pixel[2] * alpha + CARBON_B * (255 - alpha)) / 255;
			row[x] = (red << 16) | (green << 8) | blue;
		}
	}
	return 0;
}

/*
 * Animate only the coloured edge mark.  The source PNG remains the single
 * source of truth, so frame zero is pixel-identical to the U-Boot splash and
 * every loop returns to that exact frame before its short resting phase.
 */
static void render_animation_frame(uint8_t *buffer, uint32_t pitch,
				   uint32_t width, uint32_t height,
				   const struct image *splash,
				   unsigned int elapsed_ms)
{
	unsigned int cycle_ms = elapsed_ms % ANIMATION_PERIOD_MS;
	double arc_progress = 0.0;
	double frame_intensity = 0.0;
	double upper_arc_x = 0.0;
	double lower_arc_x = 0.0;
	uint32_t x, y, x_start, x_end, y_start, y_end;
	int landscape_output = splash->width == width;

	if (cycle_ms >= ANIMATION_HOLD_MS &&
	    cycle_ms < ANIMATION_HOLD_MS + ARC_SWEEP_MS) {
		double envelope;

		arc_progress = (double)(cycle_ms - ANIMATION_HOLD_MS) / ARC_SWEEP_MS;
		envelope = sin(M_PI * arc_progress);
		frame_intensity = 0.78 * envelope * envelope;
		upper_arc_x = ARC_GLINT_X_MIN + arc_progress *
			(ARC_GLINT_X_MAX - ARC_GLINT_X_MIN);
		lower_arc_x = ARC_GLINT_X_MAX - arc_progress *
			(ARC_GLINT_X_MAX - ARC_GLINT_X_MIN);
	}
	if (landscape_output) {
		x_start = MARK_LANDSCAPE_X_MIN;
		x_end = width < MARK_LANDSCAPE_X_MAX + 1 ? width : MARK_LANDSCAPE_X_MAX + 1;
		y_start = MARK_LANDSCAPE_Y_MIN;
		y_end = height < MARK_LANDSCAPE_Y_MAX + 1 ? height : MARK_LANDSCAPE_Y_MAX + 1;
	} else {
		x_start = splash->height - 1 - MARK_LANDSCAPE_Y_MAX;
		x_end = splash->height - MARK_LANDSCAPE_Y_MIN;
		y_start = splash->width - 1 - MARK_LANDSCAPE_X_MAX;
		y_end = splash->width - MARK_LANDSCAPE_X_MIN;
	}

	for (y = y_start; y < y_end; y++) {
		uint32_t *row = (uint32_t *)(buffer + y * pitch);

		for (x = x_start; x < x_end; x++) {
			uint32_t source_x = landscape_output ? x : splash->width - 1 - y;
			uint32_t source_y = landscape_output ? y : splash->height - 1 - x;
			const uint8_t *pixel;

			/* The central mark never animates; avoid reading or rewriting it. */
			if (source_y >= 540 && source_y <= 660)
				continue;
			pixel = splash->rgba +
				(source_y * splash->width + source_x) * 4;
			uint32_t alpha = pixel[3];
			uint32_t red = (pixel[0] * alpha + CARBON_R * (255 - alpha)) / 255;
			uint32_t green = (pixel[1] * alpha + CARBON_G * (255 - alpha)) / 255;
			uint32_t blue = (pixel[2] * alpha + CARBON_B * (255 - alpha)) / 255;

			uint32_t maximum = red > green ? red : green;
			uint32_t minimum = red < green ? red : green;
			double highlight = 0.0;

			maximum = maximum > blue ? maximum : blue;
			minimum = minimum < blue ? minimum : blue;
			/* Exclude the white diamond and carbon background. */
			/* Keep anti-aliased boundary pixels untouched: the silhouette must not grow. */
			if (maximum - minimum > 45 && maximum > 120) {
				if (arc_progress > 0.0) {
					double arc_x = source_y < 540 ? upper_arc_x : lower_arc_x;
					double profile = 1.0 - fabs((double)source_x - arc_x) / 68.0;

					if (profile > 0.0)
						highlight = frame_intensity * profile * profile;
				}
				/* Blend toward Cloud rather than multiplying saturated colours. */
				red += (uint32_t)((255 - red) * highlight);
				green += (uint32_t)((255 - green) * highlight);
				blue += (uint32_t)((255 - blue) * highlight);
			}
			row[x] = (red << 16) | (green << 8) | blue;
		}
	}
}

static int animation_is_active(unsigned int elapsed_ms)
{
	unsigned int cycle_ms = elapsed_ms % ANIMATION_PERIOD_MS;

	return cycle_ms >= ANIMATION_HOLD_MS &&
		cycle_ms < ANIMATION_HOLD_MS + ARC_SWEEP_MS;
}

static unsigned int elapsed_milliseconds(const struct timespec *start)
{
	struct timespec now;
	uint64_t milliseconds;

	clock_gettime(CLOCK_MONOTONIC, &now);
	milliseconds = (uint64_t)(now.tv_sec - start->tv_sec) * 1000;
	if (now.tv_nsec >= start->tv_nsec)
		milliseconds += (now.tv_nsec - start->tv_nsec) / 1000000;
	else
		milliseconds -= (start->tv_nsec - now.tv_nsec) / 1000000;
	return (unsigned int)milliseconds;
}

int main(int argc, char **argv)
{
	drmModeRes *resources = NULL;
	drmModeConnector *connector = NULL;
	drmModeModeInfo mode;
	struct framebuffer fb = { 0 };
	struct image logo = { 0 };
	struct timespec animation_start, next_frame;
	uint32_t crtc_id = 0;
	unsigned int frame_number = 0;
	int previous_active = 0;
	int waited, fd = -1, result = EXIT_FAILURE;

	if (argc != 2 || load_png(argv[1], &logo) != 0) {
		fprintf(stderr, "screen-splash: cannot load logo\n");
		return EXIT_FAILURE;
	}

	for (waited = 0; waited < WAIT_LIMIT_MS; waited += DRM_WAIT_MS) {
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
	clock_gettime(CLOCK_MONOTONIC, &animation_start);
	next_frame = animation_start;

	/*
	 * Keep the framebuffer alive without retaining DRM mastership. Once the UI
	 * replaces our scanout, exit and release the old dumb buffer automatically.
	 */
	for (;;) {
		unsigned int elapsed_ms;
		int active;

		add_nanoseconds(&next_frame, FRAME_INTERVAL_NS);
		sleep_until(&next_frame);
		if (frame_number++ % HANDOFF_POLL_FRAMES == 0) {
			drmModeCrtc *crtc = drmModeGetCrtc(fd, crtc_id);

			if (crtc && crtc->buffer_id != fb.id) {
				drmModeFreeCrtc(crtc);
				break;
			}
			if (crtc)
				drmModeFreeCrtc(crtc);
		}
		elapsed_ms = elapsed_milliseconds(&animation_start);
		active = animation_is_active(elapsed_ms);
		if (active || previous_active) {
			render_animation_frame(fb.map, fb.pitch, mode.hdisplay,
					       mode.vdisplay, &logo, elapsed_ms);
		}
		previous_active = active;
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
