# Introduction
Building Micropython with the ESP8266 toolkit on MacOS is a bear trap.  Most painful of all, a dependency of the esp-open-sdk tool `crosstool-ng` is no longer supported on MacOS.  We're on our own.

Rather than wrestle with the numerous gotchas around building Micropython on a Mac, let's just move to a Docker container, where everything is happily Linux.

The basic pattern here is this: this project provides a `Dockerfile` which, when built, generates an image with the Micropython build environment pre-configured and several of the Micropython ports pre-built.  The idea is that you can instantiate an instance of the container, make whatever modifications you want, and rebuild the relevant port or ports, with an environment that already has the relevant build dependencies in place.

After the rebuilds are complete, you can copy the generated build binaries out to the Docker host via a volume mount, or attempt to flash the target device directly from inside the container.

# Use Cases
There's a few reasons you'd want to be doing this instead of just downloading the prebuild Micropython images:
- Bleeding edge testing of the Micropython master branch
- Custom compiling a Micropython firmware image packaged with your code
- I'm sure there's more, but those are the ones that come to mind

# How-To
## What You'll Need
Docker installed on your host machine.  For MacOS, the simplest way to do this is with `homebrew` installed:
```
brew cask install docker
```
Other than that, everything else is handled inside the Docker container which gets build from the `Dockerfile`.

## Initial Build of the Docker Image
Given our `Dockerfile`, we want to build a Docker image.  This image will serve as a template for containers we create afterwards.  The image will contain a default set of built ports, from a default version of the stock Micropython repository.

With Docker installed, from the root directory of this repository (i.e. where the `Dockerfile` is), do:
```
docker build -t micropython_build .
```
This will take quite a lot of time, as the various project sources and their dependencies are downloaded and compiled.  Note that once you've run this once on your machine, as long as you don't clear your Docker image cache or edit the `Dockerfile`, you won't have to rebuild every step in the build process again and it'll go much faster.

## Start a Container from the Built Image
Once the `Dockerfile` is built into an image and stored on your local machine, you can create a container from that image and get a shell into it with:
```
docker run -it --rm micropython_build -v /my/output/directory:/opt/micropython/artifacts
```
Be advised that this is an ephemeral container, and once you close the shell the container and any changes will disappear.  You should ensure that any build artifacts you wish to keep are safely copied to the `/opt/micropython/artifacts` volume mount inside the container.

# Rebuilding Micropython
At this point you have a shell inside a fresh container.  You can make whatver changes you want to the Micropython source, and easily recompile it the same way it was done in the `Dockerfile`:
```
cd micropython/ports/esp8266 && make
```
In this case we're building the ESP8266 port, and the resulting firmware binary will be put in `micropython/ports/esp8266/builds/firmware-combined.bin`.  To get this file out of the container and onto the host machine, you can copy it into the mounted volume we specified when we ran the container:
```
cp micropython/ports/esp8266/build/firmware-combined.bin /opt/micropython/artifacts
```

# Other Uses for This Image
## Automated Builds
In addition to creating a terminal shell inside a container, it's also useful for call one-liner commands from the host machine. For instance:
```
docker run -it --rm micropython_build -v /my/mpy/program:/opt/micropython/input:ro -v /my/output/directory:/opt/micropython/artifacts \
bash -c "cd /home/mpbuild/micropython && \
cp /opt/micropython/input/* ports/esp8266/modules && \
make -C ports/esp8266 && \
cp ports/esp8266/build/firmware-combined.bin /opt/micropython/artifacts"
```

Would create a fresh Docker container with a volume mount containing your custom Micropython modules, and another to containe the built Micropython binary.  It would then copy your modules into the micropython code, build it, and copy the binary back out to the mounted volume.  This would provide a nice one-liner for recompiling your project into a flash-able binary, without having to maintain a build environment directly on your machine.

## Base Image for Another Image
Also, if your build step got more complicated, it would be a simple matter to start from the Docker image generated above as a starting point for your own custom container.  Consider this Dockerfile:
```
FROM micropython_build:latest
LABEL maintainer="Your Name"

# DO SOMETHING HERE THAT WOULD MODIFY MICROPYTHON

# Build the various ports you might care about
RUN cd micropython/ports/unix && make
RUN cd micropython/ports/esp8266 && make
```
With this, we could build a derived Docker container with a customized version of Micropython, and extract the build binaries:
```
mkdir ./build && rm ./build/*
docker build -t mpy_project .
docker run -it --rm -v `pwd`/build/:/opt/micropython/artifacts mpy_project cp micropython/ports/esp8266/build/firmware-combined.bin /opt/micropython/artifacts
```
