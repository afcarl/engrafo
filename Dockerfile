# Version from https://hub.docker.com/_/debian/
FROM debian:testing-20180426

# Official CDN throws 503s
RUN sed -i 's/deb.debian.org/mirrors.kernel.org/g' /etc/apt/sources.list

# LaTeX stuff first, because it's enormous and doesn't change much
# Change logs here: https://packages.debian.org/buster/texlive
RUN apt-get update -qq && apt-get install -qy texlive-full=2018.20180505*

# Node.js and Python dependencies
RUN apt-get update -qq && apt-get install -qy curl gnupg2
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update -qq && apt-get install -qy \
  ca-certificates \
  nodejs=8.11.3* \
  git-core \
  python \
  python-pip \
  yarn=1.7.0*

# latexml dependencies
RUN apt-get update -qq && apt-get install -qy \
  libarchive-zip-perl libfile-which-perl libimage-size-perl  \
  libio-string-perl libjson-xs-perl libtext-unidecode-perl \
  libparse-recdescent-perl liburi-perl libuuid-tiny-perl libwww-perl \
  libxml2 libxml-libxml-perl libxslt1.1 libxml-libxslt-perl  \
  imagemagick libimage-magick-perl perl-doc

# Google Chrome for Puppeteer
# https://github.com/GoogleChrome/puppeteer/blob/master/docs/troubleshooting.md

# Make user so that Chrome can run
RUN groupadd -r engrafo && useradd -r -g engrafo -G audio,video engrafo \
    && mkdir -p /home/engrafo/Downloads \
    && chown -R engrafo:engrafo /home/engrafo

# See https://crbug.com/795759
RUN apt-get update && apt-get install -yq libgconf-2-4

# Install latest chrome dev package.
# Note: This Chrome is not actually used, it just installs the necessary libs
# to make Puppeteer's bundled version of Chromium work.
RUN curl -sSL https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
    && apt-get update -qq \
    && apt-get install -yq google-chrome-unstable fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /src/*.deb

RUN mkdir -p /usr/src/latexml
WORKDIR /usr/src/latexml
ENV LATEXML_COMMIT=601362316f7166c00960ebd9fb806f4b1bf3a233
RUN curl -L https://github.com/brucemiller/LaTeXML/tarball/$LATEXML_COMMIT | tar --strip-components 1 -zxf -
RUN perl Makefile.PL; make; make install

RUN mkdir -p /app /node_modules
RUN chown engrafo:engrafo /app /node_modules
WORKDIR /app

# server
COPY server/requirements.txt /app/server/
RUN pip install -r server/requirements.txt

# Run user as non privileged.
USER engrafo

# Node
COPY package.json yarn.lock /
# HACK: Install node_modules one directory up so they are not overwritten
# in development. The other workaround is using a volume for node_modules,
# but is really slow and hard to update.
RUN cd /; yarn install --pure-lockfile
ENV PATH /node_modules/.bin:$PATH

ENV PYTHONUNBUFFERED=1
ENV PATH="/app/bin:${PATH}"

COPY . /app
