FROM gotenberg/gotenberg:8

USER root

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      fontconfig \
      fonts-noto \
      fonts-noto-cjk \
      fonts-noto-color-emoji \
      fonts-noto-extra \
      fonts-firacode \
      bash curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/share/fonts/fira && \
    curl -L -o /usr/local/share/fonts/fira/FiraSans-Regular.ttf \
      https://github.com/mozilla/Fira/raw/master/ttf/FiraSans-Regular.ttf && \
    curl -L -o /usr/local/share/fonts/fira/FiraSans-Bold.ttf \
      https://github.com/mozilla/Fira/raw/master/ttf/FiraSans-Bold.ttf && \
    curl -L -o /usr/local/share/fonts/fira/FiraSans-Italic.ttf \
      https://github.com/mozilla/Fira/raw/master/ttf/FiraSans-Italic.ttf && \
    curl -L -o /usr/local/share/fonts/fira/FiraSans-BoldItalic.ttf \
      https://github.com/mozilla/Fira/raw/master/ttf/FiraSans-BoldItalic.ttf

RUN fc-cache -f -v

COPY md2pdf.sh /usr/local/bin/md2pdf
RUN chmod +x /usr/local/bin/md2pdf

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/md2pdf"]
