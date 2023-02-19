# Spring Boot - Maven 3 - CentOS Docker image

[![Build Status](https://travis-ci.org/codecentric/springboot-maven3-centos.svg?branch=master)](https://travis-ci.org/codecentric/springboot-maven3-centos)

This repository contains the sources of the base image for deploying Spring Boot applications as reproducible Docker images. The resulting images can be run either by [Docker](http://docker.io) or using [S2I](https://github.com/openshift/source-to-image) with a prepared s2i.json file.

This image is heavily inspired by the awesome [codecentric/springboot-maven3-centos](https://github.com/codecentric/springboot-maven3-centos) builder image.

## Usage

To build a simple springboot-sample-app application using standalone S2I and then run the resulting image with Docker execute:

```
$ s2i build git://github.com/codecentric/springboot-sample-app skjolber/spring-boot-maven3-jdk8-centos springboot-sample-app
$ docker run -p 8080:8080 springboot-sample-app
```

**Accessing the application:**

```
$ curl 127.0.0.1:8080
```

## Import to Openshift
Add using
```
$ oc create -n <your project name> -f s2i.json
```
and remove using 
```
$ oc delete -n <your project name> -f s2i.json 
```

### Secrets
If you are using a private repository, add SSH keys using

```
$ oc secrets new-sshauth <secret name> --ssh-privatekey=$HOME/.ssh/my_openshift_key_rsa
```
and remember to use SSH style git repository URLs.

The secret must be manually configured on the generated build (under advanced options), or can be [automatically matched](https://docs.openshift.com/container-platform/3.6/dev_guide/builds/build_inputs.html) against your git repo.

## Environment variables

*  **APP_TARGET** (default: '')

    This variable specifies a relative location to your application binary inside the
    container.

*  **MVN_ARGS** (default: '')

    This variable specifies the arguments for Maven inside the container.
   
*  **JAVA_OPTS** (default: '')

    Additional Java options, like garbage collector and such.

*  **XMX** (default: '256')
   
    Java memory

*  **XMS** (default: '32')
   
    Java memory in megabytes.

*  **SPRING_ACTIVE_PROFILES** (default: 'default')
   
    Active spring profiles (comma-seperated). 

## Repository organization

* **`s2i/bin/`**

  This folder contains scripts that are run by [S2I](https://github.com/openshift/source-to-image):

  *   **assemble**

      Is used to restore the build artifacts from the previous built (in case of
      'incremental build'), to install the sources into location from where the
      application will be run and prepare the application for deployment (eg.
      using maven to build the application etc..)

  *   **run**

      This script is responsible for running a Spring Boot fat jar using `java -jar`.
      The image exposes port 8080, so it expects application to listen on port
      8080 for incoming request.

  *   **save-artifacts**

      Not currently supported

## Testing

In order to test your changes to this STI image or to the STI scripts, you can use the `test/run` script. Before that, you have to build the 'candidate' image:

```
$ docker build -t skjolber/spring-boot-maven3-jdk8-centos-candidate .
```

or 

```
$ docker build --ulimit nofile=1024000:1024000 --network host -t skjolber/spring-boot-maven3-jdk8-centos-candidate:v123 .
```

After that you can execute `./test/run`. You can also use `make test` to automate this.

# Tuning
I'm using a set of default JVM parameters:

    -Djava.security.egd=file:/dev/./urandom 
    -Djava.awt.headless=true 
    -Dfile.encoding=UTF-8
    -XX:+UseG1GC 

## Memory usage
My Openshift pods seem to be using more memory than expected. While this is a complex topic, I've come up with a few parameters for reducing the footprint. As in (almost) all optimization, measuring first is important.

#### Web container
The Undertow web container seems to be least memory hungry.

### JMX
To get an overview of the memory use Java Misson Control or JConsole with JMX. Enable JMX and run port-forwarding to your pod. Add Java parameters

```
-Dcom.sun.management.jmxremote.port=8090 -Dcom.sun.management.jmxremote.rmi.port=8090 -Djava.rmi.server.hostname=127.0.0.1 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false
```

and start port-forwarding using

```
oc port-forward <pod> 8090:8090
```

and connect to `localhost:8090`.

### JVM memory parameters
After making sure all code paths have been visited, and running some simple benchmarks, I arrived at the following:

|Name|Default|Parameter|
|----|------|---------|
|Compressed class size|1 GB|-XX:CompressedClassSpaceSize=16m|
|Metaspace|Unlimited|-XX:MaxMetaspaceExpansion=0 -XX:MaxMetaspaceSize=64m|
|[Reserved code cache]|32M/48M|-XX:ReservedCodeCacheSize=24m|

### Image memory parameters
While some memory leak has been fixed in the latest version of Java 8 (152), some [additional parameters] can be used to reduce memory. Add the following environment variables:

    export MALLOC_ARENA_MAX=2
    # disable dynamic mmap threshold, see M_MMAP_THRESHOLD in "man mallopt"
    export MALLOC_MMAP_THRESHOLD_=131072
    export MALLOC_MMAP_THRESHOLD_=131072
    export MALLOC_TOP_PAD_=131072
    export MALLOC_MMAP_MAX_=65536

### Result
Using these parameters, and 128m Xmx, I was able to get a 35 MB Spring Boot app to use about 360 MB (as reported by Openshift metrics). Obiously you'll want to add some margin, or the pod will be terminated with OOM error.


## Copyright

Released under the Apache License 2.0. See the [LICENSE](LICENSE) file.

## See also

  * http://trustmeiamadeveloper.com/2016/03/18/where-is-my-memory-java/
  * https://spring.io/blog/2015/12/10/spring-boot-memory-performance
   
[Reserved code cache]:		https://docs.oracle.com/javase/8/embedded/develop-apps-platforms/codecache.htm
[additional parameters]:	https://stackoverflow.com/questions/26041117/growing-resident-memory-usage-rss-of-java-process
