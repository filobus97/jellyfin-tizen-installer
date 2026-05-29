# Base image
FROM ubuntu:latest

# Set locale using build arguments
ARG LANG
ARG LANGUAGE
ARG LC_ALL

# Install prerequisites
RUN apt-get update && apt-get install -y \
  ca-certificates \
  git \
  wget \
  zip \
  unzip \
  pciutils \
  locales \
  libssl-dev \
  curl \
  net-tools \
  gettext \
  nano \
  && rm -rf /var/lib/apt/lists/*

# Configure locale
RUN sed -i -e "s/^# ${LANG} UTF-8/${LANG} UTF-8/" /etc/locale.gen \
  && locale-gen ${LANG} \
  && update-locale LANG=${LANG} LANGUAGE=${LANGUAGE} LC_ALL=${LC_ALL}

# Set environment variables for locale
ENV LANG=${LANG}
ENV LANGUAGE=${LANGUAGE}
ENV LC_ALL=${LC_ALL}

# Add a user
ARG USER=developer
RUN useradd --create-home ${USER}
ENV HOME /home/${USER}

# Switch to the new user
USER ${USER}
WORKDIR ${HOME}

# Install Tizen Studio
ARG TIZEN_STUDIO_VERSION
ARG TIZEN_STUDIO_FILE=web-cli_Tizen_Studio_${TIZEN_STUDIO_VERSION}_ubuntu-64.bin
ARG TIZEN_STUDIO_URL=http://download.tizen.org/sdk/Installer/tizen-studio_${TIZEN_STUDIO_VERSION}/${TIZEN_STUDIO_FILE}
RUN wget ${TIZEN_STUDIO_URL} \
  && chmod +x ${TIZEN_STUDIO_FILE} \
  && echo y | ./${TIZEN_STUDIO_FILE} --accept-license \
  && rm ${TIZEN_STUDIO_FILE}

COPY certs/author.p12 /home/developer/tizen-studio-data/keystore/author/author.p12
COPY certs/distributor.p12 /home/developer/tizen-studio-data/keystore/distributor/distributor.p12
COPY tizen-profile/profiles.xml /home/developer/tizen-studio-data/profile/profiles-template.xml

# Switch back to root user for system-level changes
USER root

# Move Tizen Studio from home to avoid conflicts with mounted volumes
RUN mv ${HOME}/tizen-studio /tizen-studio \
  && ln -s /tizen-studio ${HOME}/tizen-studio

# Add Tizen CLI tools to PATH
ENV PATH $PATH:/tizen-studio/tools/:/tizen-studio/tools/ide/bin/:/tizen-studio/package-manager/

# Install Node.js and npm using NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@10

# Copy the scripts
COPY entrypoint.sh /entrypoint.sh
COPY jellyfin-tizen-build.sh /jellyfin-tizen-build.sh

# Make the script executable
RUN chmod +x /entrypoint.sh
RUN chmod +x /jellyfin-tizen-build.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
