# spring-boot-maven3-jdk8-centos
#
# This image provide a base for running Spring Boot based applications. It
# provides a base Java 8 installation and Maven 3.

FROM centos/s2i-core-centos8

RUN cd /etc/yum.repos.d/
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

EXPOSE 8080

ENV JAVA_VERSON 11

RUN dnf install -y java-$JAVA_VERSON-openjdk-headless java-$JAVA_VERSON-openjdk-devel

RUN dnf update -y

RUN dnf clean all && rm -rf /var/cache/yum

ENV JAVA_HOME /usr/lib/jvm/java

# Add configuration files, bashrc and other tweaks
COPY ./s2i/bin/ $STI_SCRIPTS_PATH

RUN chown -R 1001:0 /opt/app-root
USER 1001

# Set the default CMD to print the usage of the language image
CMD $STI_SCRIPTS_PATH/usage

RUN cat /etc/redhat-release

