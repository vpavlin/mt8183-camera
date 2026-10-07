# Userspace: libcamera, PipeWire, browser

Tested with Debian 13 (trixie) + trixie-backports: libcamera 0.7.1, PipeWire 1.6.9,
WirePlumber 0.5.12, xdg-desktop-portal 1.20, Brave 1.96 (Chromium 154).

## 1. Raw capture (no libcamera)

```sh
sudo scripts/load.sh
scripts/stream-test.sh ov8856 1632 1224 10      # rear -> /tmp/cam-ov8856.raw
scripts/stream-test.sh ov02a10 1600 1200 10     # front
python3 tools/raw2png.py /tmp/cam-ov8856.raw 1632 1224 BGGR    # needs numpy
```

The sensors have a colour-bar test pattern, which is the quickest way to tell a pipeline problem
from a dark scene (set it before streaming; sensor controls are applied at stream start):

```sh
v4l2-ctl -d $(media-ctl -d /dev/media1 -e "ov8856 2-0010") -c test_pattern=1
```

The CAMSV video nodes are media-controller-centric (`V4L2_CAP_IO_MC`, multi-planar): they are not
webcams that applications can open directly.

## 2. libcamera

```sh
sudo apt install -t trixie-backports libcamera-tools libcamera-ipa v4l-utils
mkdir -p ~/.config/libcamera
cp userspace/libcamera/configuration.yaml ~/.config/libcamera/   # or /etc/libcamera/
cam -l
cam -c /base/soc/i2c@11009000/camera@10 --capture=10 -s pixelformat=BGR888 --file=/tmp/rear-#.ppm
```

The simple pipeline handler already knows the `mtk-seninf` media device but has the software ISP
disabled for it; the configuration file turns it on.

Requirements on the kernel side:

- **a dma-buf provider** for the software ISP: `CONFIG_UDMABUF=y` and/or
  `CONFIG_DMABUF_HEAPS=y` + `CONFIG_DMABUF_HEAPS_SYSTEM=y`. Without them: "Could not open any
  dma-buf provider … disabling software debayering". `/dev/udmabuf` gets a uaccess ACL for the
  logged-in user on systemd systems; `/dev/dma_heap/system` is root-only by default.
- **the subdev streams/routing uAPI** (compile-time switch in 6.12, see
  `patches/linux/v6.12/0002-*`). Without it libcamera cannot see the seninf's internal routes and
  maps both sensors to the first CAMSV video node.
- **the ov8856 fix** (`patches/linux/`), or the rear camera fails with `-EPIPE` at stream start.

Expect warnings about missing sensor helpers and tuning files (`uncalibrated.yaml` is used);
images work, colours/exposure are not tuned.

## 3. PipeWire

```sh
sudo apt install -t trixie-backports pipewire pipewire-bin wireplumber libspa-0.2-libcamera
```

If the system uses PulseAudio for audio (as some Chromebook images do), run PipeWire for video
only so WirePlumber does not fight PulseAudio over ALSA and Bluetooth devices:

```sh
mkdir -p ~/.config/wireplumber/wireplumber.conf.d
cp userspace/wireplumber/90-camera-only.conf ~/.config/wireplumber/wireplumber.conf.d/
systemctl --user start pipewire wireplumber        # do NOT start pipewire-pulse in that setup
wpctl status                                       # Video -> Sources: ov02a10, ov8856
```

(If the pipewire user units are masked on your image, start the binaries instead, e.g.
`systemd-run --user pipewire` and `systemd-run --user wireplumber`.)

## 4. Browser (Chromium / Brave)

- enable `chrome://flags/#enable-webrtc-pipewire-camera` (Brave: `brave://flags/...`), or start
  with `--enable-features=WebRtcPipeWireCamera`
- the browser then asks xdg-desktop-portal's Camera portal, which needs PipeWire running and an
  Access dialog backend (e.g. xdg-desktop-portal-gtk). If a request was ever denied, the denial is
  stored for unsandboxed apps:

  ```sh
  gdbus call --session --dest org.freedesktop.impl.portal.PermissionStore \
    --object-path /org/freedesktop/impl/portal/PermissionStore \
    --method org.freedesktop.impl.portal.PermissionStore.Lookup devices camera
  # reset (prompt again):
  gdbus call --session --dest org.freedesktop.impl.portal.PermissionStore \
    --object-path /org/freedesktop/impl/portal/PermissionStore \
    --method org.freedesktop.impl.portal.PermissionStore.DeletePermission devices camera ""
  ```

- open [`userspace/camtest.html`](../userspace/camtest.html) (append `#auto` to cycle through
  all cameras and print a frame's mean brightness)

Measured on the Duet: both cameras enumerate as "ov02a10" and "ov8856", 640x480 @ 30 fps each
in the browser; `cam` reaches ~30 fps (front 1600x1200) and ~37 fps (rear 1632x1224), ~9-12 fps at
the full 3280x2464 (software debayer bound).
