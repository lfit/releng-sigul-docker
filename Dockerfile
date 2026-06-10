# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
FROM centos:7
SHELL ["/bin/bash", "-c"]

# CentOS 7 reached EOL on 2024-06-30 and mirrorlist.centos.org no longer
# resolves. Repoint the base repositories at vault.centos.org so that yum
# continues to work for the package installs below.
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* \
    && sed -i 's@#baseurl=http://mirror.centos.org@baseurl=http://vault.centos.org@g' \
        /etc/yum.repos.d/CentOS-*

# git is required by `sigul sign-git-tag` to read and modify tag objects.
# Installed separately from sigul so that a sigul failure below is not masked
# by git installing successfully (a single combined "yum install" can exit 0
# even when the sigul package is skipped).
RUN yum install -y git && yum clean all

# Install sigul directly from its koji RPM. The Fedora infra repodata
# (repos-dist/epel$releasever-infra/.../repomd.xml) frequently returns
# HTTP 403, so a repository/includepkgs based install silently yields no
# package (skip_if_unavailable=True). Pinning the RPM URL is reliable.
ARG SIGUL_RPM="https://kojipkgs.fedoraproject.org//packages/sigul/0.207/1.el7/x86_64/sigul-0.207-1.el7.x86_64.rpm"
RUN yum install -y "${SIGUL_RPM}" && yum clean all

# Fail-fast: verify sigul is actually installed and runnable, rather than
# shipping a broken image when the upstream RPM was unreachable.
RUN sigul --version

RUN mkdir -p /w/workspace
