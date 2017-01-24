FROM alpine:latest
MAINTAINER Shaun Murakami <stmuraka@gmail.com>

# binary characteristics
ENV os="linux" \
    arch="amd64"

RUN apk update \
 && apk add \
        curl \
        gnupg \
        ca-certificates \
        openssl

# This dockerfile will create an image for a hashicorp product
ARG PRODUCT
ENV PRODUCT=${PRODUCT:-""}
RUN [ -z "${PRODUCT+xxx}" ] || [ -z "${PRODUCT}" -a "${PRODUCT+xxx}" = "xxx" ] \
 && { \
        echo "ERROR: PRODUCT not specified"; \
        echo "Pass docker build parameter: --build-arg PRODUCT=<product>"; \
        exit 1; \
    } \
 ; [ $( echo ${PRODUCT} | tr '[:upper:]' '[:lower:]') == ${PRODUCT} ] || { echo "ERROR: Please specify product in all lowercase"; exit 1; }

ARG VERSION
ENV VERSION ${VERSION}

# Fix link to libc
RUN mkdir /lib64 \
 && ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2

 # Hashicorp web resources
ENV product_repo="https://releases.hashicorp.com/${PRODUCT}" \
    hashicorp_pgpkey="https://keybase.io/hashicorp/pgp_keys.asc?fingerprint=91a6e7f85d05c65630bef18951852d87348ffc4c"

# Get latest verision if not specified
RUN [ -z "${VERSION+xxx}" ] || [ -z "${VERSION}" -a "${VERSION+xxx}" = "xxx" ] \
 && { \
     echo "ERROR: No version specified"; \
     VERSION="$(curl -sSL ${product_repo} | grep 'href' | grep ${PRODUCT} | grep -v 'rc' | cut -d / -f3 | sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n | tail -n 1)"; \
     echo "latest ${PRODUCT} version: ${VERSION}"; \
     echo "Pass docker build parameter: --build-arg VERSION=${VERSION}"; \
     exit 1; \
 } || echo "Installing ${PRODUCT} version ${VERSION}"

ENV download_path="${product_repo}/${VERSION}" \
    zip_file="${PRODUCT}_${VERSION}_${os}_${arch}.zip" \
    product_signature="${PRODUCT}_${VERSION}_SHA256SUMS.sig" \
    product_sums="${PRODUCT}_${VERSION}_SHA256SUMS"

# Set workdir to the product dir
ENV install_dir="/opt/hashicorp/${PRODUCT}"
RUN mkdir -p ${install_dir}/config/ \
             ${install_dir}/bin/ \
             ${install_dir}/data/
WORKDIR ${install_dir}

# Download Hashicorp PGP key
ADD ${hashicorp_pgpkey} ${install_dir}/hashicorp.asc
# Download Nomad binary
ADD ${download_path}/${zip_file} ${install_dir}/
# Download Nomad checksums
ADD ${download_path}/${product_sums} ${install_dir}/
# Download Nomad signature
ADD ${download_path}/${product_signature} ${install_dir}/

# Import Hashicorp PGP key
RUN gpg --import hashicorp.asc

# Verify signature
RUN gpg --verify ${product_signature} ${product_sums}

# Verify binary
RUN sha256sum -c ${product_sums} 2>/dev/null | grep ${zip_file}

# Extract Nomad to /usr/bin

RUN unzip ${zip_file} \
 && mv ${PRODUCT} bin/ \
 && ln -s ${install_dir}/bin/${PRODUCT} /usr/bin/${PRODUCT}

# Cleanup
#RUN rm -f ${zip_file} ${product_sums} ${product_signature} ${hashicorp_pgpkey}

VOLUME ${install_dir}/data

#ENTRYPOINT ${PRODUCT} -data-dir ${install_dir}/data
#ENTRYPOINT ${PRODUCT}

#CMD -help
