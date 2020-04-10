# AinD: Android (Anbox) in Docker

AinD launches Android apps in Docker, by nesting [Anbox](https://anbox.io/) containers inside Docker.

Unlike VM-based similar projects, AinD can be executed on IaaS instances without support for nested virtualization.

Docker Hub: [`aind/aind`](https://hub.docker.com/r/aind/aind)

## Purposes
* Anti-theft
* Android compatibility (via cloud) for iOS and Windows tablets

### Non-goals
* Cloud gaming

## Screenshots

```console
$ docker ps -a
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                    NAMES
950e3fa7d320        aind                "/docker-entrypoint.…"   7 minutes ago       Up 7 minutes        0.0.0.0:5900->5900/tcp   aind
$ docker exec aind ps -ef | tail -n 20
101023       323     138  0 11:18 pts/2    00:00:00 /system/bin/sdcard -u 1023 -g 1023 -m -w /data/media emulated
110020       347     154  0 11:18 pts/2    00:00:00 com.android.systemui
101001       397     154  0 11:18 pts/2    00:00:00 com.android.phone
user         403     154  0 11:18 pts/2    00:00:00 com.android.settings:CryptKeeper
user         448     154  0 11:18 pts/2    00:00:00 com.android.settings
110009       531     154  0 11:18 pts/2    00:00:00 android.ext.services
110032       546     154  0 11:18 pts/2    00:00:00 com.android.deskclock
110015       577     154  0 11:18 pts/2    00:00:00 com.android.provision
110047       583     154  0 11:18 pts/2    00:00:00 com.android.smspush
110000       615     154  0 11:18 pts/2    00:00:00 org.anbox.appmgr
110011       642     154  0 11:18 pts/2    00:00:00 com.android.managedprovisioning
110008       657     154  0 11:18 pts/2    00:00:00 android.process.media
110003       675     154  0 11:18 pts/2    00:00:00 com.android.providers.calendar
110002       694     154  0 11:18 pts/2    00:00:00 android.process.acore
110027       744     154  0 11:18 pts/2    00:00:00 com.android.calendar
110028       765     154  0 11:18 pts/2    00:00:00 com.android.camera2
110034       784     154  0 11:18 pts/2    00:00:00 com.android.email
110037       807     154  0 11:18 pts/2    00:00:00 com.android.gallery3d
110013       822     154  0 11:18 pts/2    00:00:00 com.android.onetimeinitializer
root        1003       0  0 11:25 ?        00:00:00 ps -ef
```

![docs/screenshot.png](docs/screenshot.png)

## Quick start
Tested on Ubuntu 19.10 (Kernel 5.3).
May not work on other distros.
If `modprobe ashmem_linux` or `modprobe binder_linux` fails, see https://github.com/anbox/anbox-modules .

```bash
sudo modprobe ashmem_linux
sudo modprobe binder_linux
```

```bash
docker run -td --name aind --privileged -p 5900:5900 -v /lib/modules:/lib/modules:ro aind/aind
```

> NOTE: `--privileged` is required for nesting an Anbox (LXC) inside Docker. But you don't need to worry too much because Anbox launches "unprivileged" LXC using user namespaces. You can confirm that all Android process are running as non-root users, by executing `docker exec aind ps -ef`.

Wait for 10-20 seconds until Android processes are shown up in `docker exec aind ps -ef`, and then connect to `5900` via `vncviewer`.

If the application manager doesn't shown up on the VNC screen, try `docker run ...` several times (FIXME).  Also make sure to check `docker logs aind`.

Future version will support connection from Web browsers (of phones and tablets) without VNC.

### Installing apk packages

APK files mounted as `/apk.d/*.apk` are automatically installed on start up.

You can also use [F-Droid](https://f-droid.org/).
To use F-Droid, enable "Settings" -> "Security" -> "Allow installation of apps from unknown sources".

## TODOs
* Map different UID range per containers
* Support remote connection from phones and tablets, ideally using Web browsers (noVNC?).
* Better touch screen experience
* Redirect camera, notifications, ...

## Similar projects
* https://github.com/budtmo/docker-android (VM-based)
* https://github.com/kubedroid/kubedroid (VM-based)
* https://anbox-cloud.io/ (Proprietary and different goals)
