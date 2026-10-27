# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation

# sigul 0.207 needs Python 2 and python-nss, so this image stays on CentOS 7
# until the Sigul infrastructure moves to a newer release. The base image is
# pinned by digest; the tag cannot be moved under us.
FROM centos:7@sha256:be65f488b7764ad3638f236b7b515b3678369a5124c47b8d32916d6487418ea4
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# CentOS 7 reached EOL on 2024-06-30 and mirrorlist.centos.org no longer
# resolves. Repoint the base repositories at vault.centos.org, over HTTPS:
# packages are GPG-checked, but repository metadata is not signed, so plain
# HTTP would let a network attacker hold the image on vulnerable versions.
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* \
    && sed -i 's@#baseurl=http://mirror.centos.org@baseurl=https://vault.centos.org@g' \
        /etc/yum.repos.d/CentOS-*

# Apply the final CentOS 7 updates. The base image predates them, and this
# image speaks TLS to the signing bridge through NSS.
RUN yum update -y && yum clean all

# The CentOS 7 vault ca-certificates package is frozen and carries stale
# root CAs, so yum update cannot refresh it. Install the current Mozilla
# bundle (dated, immutable curl.se URL) as a trust anchor, verified against a
# pinned SHA-256. Override both build args together to bump the bundle.
ARG CA_BUNDLE_URL="https://curl.se/ca/cacert-2026-10-20.pem"
ARG CA_BUNDLE_SHA256="796f1389bfea13c0ed78f663b765baaff54a508e5483786bd6ece73c5e3e3cbe"
RUN curl --fail --silent --show-error --location --proto '=https' \
        --output /tmp/cacert.pem "${CA_BUNDLE_URL}" \
    && echo "${CA_BUNDLE_SHA256}  /tmp/cacert.pem" | sha256sum --check --strict \
    && update-ca-trust force-enable \
    && install -m 0644 /tmp/cacert.pem \
        /etc/pki/ca-trust/source/anchors/mozilla-cacert.pem \
    && update-ca-trust extract \
    && rm -f /tmp/cacert.pem

# git is required by `sigul sign-git-tag` to read and modify tag objects.
# Installed separately from sigul so that a sigul failure below is not masked
# by git installing successfully (a single combined "yum install" can exit 0
# even when the sigul package is skipped).
RUN yum install -y git && yum clean all

# Install sigul directly from its koji RPM. The Fedora infra repodata
# (repos-dist/epel$releasever-infra/.../repomd.xml) frequently returns
# HTTP 403, so a repository/includepkgs based install silently yields no
# package (skip_if_unavailable=True). Pinning the RPM URL is reliable.
#
# The koji RPM is unsigned, and yum does not GPG-check a package installed
# from a URL, so verify it against a pinned SHA-256 before installing.
# Override both build args together to change the sigul version.
ARG SIGUL_RPM="https://kojipkgs.fedoraproject.org//packages/sigul/0.207/1.el7/x86_64/sigul-0.207-1.el7.x86_64.rpm"
ARG SIGUL_RPM_SHA256="a20e37d2e43db6733cf802f058f133388eb6da7f200dcb60ed71d28b1866abd3"
RUN curl --fail --silent --show-error --location --proto '=https' \
        --output /tmp/sigul.rpm "${SIGUL_RPM}" \
    && echo "${SIGUL_RPM_SHA256}  /tmp/sigul.rpm" | sha256sum --check --strict \
    && yum install -y /tmp/sigul.rpm \
    && rm -f /tmp/sigul.rpm \
    && yum clean all

# Fail-fast: verify sigul is actually installed and runnable, rather than
# shipping a broken image when the upstream RPM was unreachable.
RUN sigul --version

RUN mkdir -p /w/workspace
