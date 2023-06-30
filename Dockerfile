ARG TARGETPLATFORM
ARG BASE_JDK="amazonjre:17-alpine"

FROM alpine as base

RUN echo "TARGET PLATFORM: $TARGETPLATFORM"

RUN if [ "$TARGETPLATFORM" = "linux/arm/v7" ]; then \
        BASE_JDK="eclipse-temurin:11"; \
    fi

FROM ${BASE_JDK} as jre-deps

COPY target/alist-tvbox-1.0.jar /app/app.jar

RUN touch /modules.txt

RUN if [ "$TARGETPLATFORM" != "linux/arm/v7" ]; then \
    unzip /app/app.jar -d temp &&  \
    jdeps  \
      --print-module-deps \
      --ignore-missing-deps \
      --recursive \
      --multi-release 17 \
      --class-path="./temp/BOOT-INF/lib/*" \
      --module-path="./temp/BOOT-INF/lib/*" \
      /app/app.jar > /modules.txt; \
    fi

FROM ${BASE_JDK} as jre-build

COPY --from=jre-deps /modules.txt /modules.txt

RUN if [ "$TARGETPLATFORM" = "linux/arm/v7" ]; then \
    BASE_JDK="eclipse-temurin:11"; \
    $JAVA_HOME/bin/jlink \
         --add-modules java.base \
         --strip-debug \
         --no-man-pages \
         --no-header-files \
         --compress=2 \
         --output /jre; \
    else \
        apk add --no-cache binutils && \
        jlink \
         --verbose \
         --add-modules "$(cat /modules.txt),jdk.crypto.ec,jdk.crypto.cryptoki" \
         --strip-debug \
         --no-man-pages \
         --no-header-files \
         --compress=2 \
         --output /jre; \
    fi

FROM alpine:latest
ENV JAVA_HOME=/jre
ENV PATH="${JAVA_HOME}/bin:${PATH}"

COPY --from=jre-build /jre $JAVA_HOME

LABEL MAINTAINER="Har01d"

VOLUME /opt/atv/data/

WORKDIR /opt/atv/

COPY target/alist-tvbox-1.0.jar ./alist-tvbox.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "alist-tvbox.jar", "--spring.profiles.active=production,docker"]