FROM centos:7.5.1804
LABEL maintainer="https://www.starburstdata.com/"

ARG presto_rpm
ARG presto_cli
ARG artifacts_dir="installdir"

RUN yum -y install java-11-openjdk less && \
    yum clean all && \
    rm -rf /var/cache/yum && \
    echo OK

COPY ./$artifacts_dir /$artifacts_dir

RUN set -xeu && \
    yum -y install "/${artifacts_dir}/${presto_rpm}" && \
    rpm -qa | grep -q presto-server && \
    cp -a "/${artifacts_dir}/${presto_cli}" /usr/local/bin/presto-cli; \
    chmod -v +x /usr/local/bin/presto-cli && \
    ln -vs /usr/local/bin/presto-cli / `# backwards compatibility ` && \
    yum clean all && \
    rm -vr /"${artifacts_dir}" && \
    echo OK

COPY etc /usr/lib/presto/etc

CMD /usr/lib/presto/bin/launcher run
