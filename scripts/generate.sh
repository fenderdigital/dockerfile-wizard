#!/bin/bash

echo "FROM buildpack-deps:$(awk -F'_' '{print tolower($2)}' <<< $LINUX_VERSION)"

echo "RUN apt-get update"
echo "ENV DEBIAN_FRONTEND noninteractive"

if [ ! -e $RUBY_VERSION_NUM ] ; then
    echo "RUN apt-get install -y libssl-dev && wget http://ftp.ruby-lang.org/pub/ruby/$(awk -F'.' '{ print $1"."$2 }' <<< $RUBY_VERSION_NUM)/ruby-$RUBY_VERSION_NUM.tar.gz && \
    tar -xzvf ruby-$RUBY_VERSION_NUM.tar.gz && \
    cd ruby-$RUBY_VERSION_NUM/ && \
    ./configure && \
    make -j4 && \
    make install && \
    ruby -v"
fi

if [ ! -e $NODE_VERSION_NUM ] ; then
    echo "RUN wget https://nodejs.org/dist/v$NODE_VERSION_NUM/node-v$NODE_VERSION_NUM.tar.gz && \
    tar -xzvf node-v$NODE_VERSION_NUM.tar.gz && \
    rm node-v$NODE_VERSION_NUM.tar.gz && \
    cd node-v$NODE_VERSION_NUM && \
    ./configure && \
    make -j4 && \
    make install && \
    cd .. && \
    rm -r node-v$NODE_VERSION_NUM"
fi

if [ $JAVA = "true" ] ; then
cat << EOF
RUN if [ \$(grep 'VERSION_ID="8"' /etc/os-release) ] ; then \\
    echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list && \\
    apt-get update && apt-get -y install -t jessie-backports openjdk-8-jdk ca-certificates-java \\
; elif [ \$(grep 'VERSION_ID="9"' /etc/os-release) ] ; then \\
    apt-get update && apt-get -y -q --no-install-recommends install -t stable openjdk-8-jdk ca-certificates-java \\
; elif [ \$(grep 'VERSION_ID="14.04"' /etc/os-release) ] ; then \\
    apt-get update && \\
    apt-get --force-yes -y install software-properties-common python-software-properties && \\
    echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \\
    echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections && \\
    cd /var/tmp/ && \\
    wget -O oracle_java8.deb debian.opennms.org/dists/opennms-23/main/binary-all/oracle-java8-installer_8u131-1~webupd8~2_all.deb && \\
    dpkg -i oracle_java8.deb || echo "ok" && apt-get -f install -yq \\
; elif [ \$(grep 'VERSION_ID="16.04"' /etc/os-release) ] ; then \\
    apt-get update && \\
    apt-get --force-yes -y install software-properties-common python-software-properties && \\
    echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \\
    echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections && \\
    cd /var/tmp/ && \\
    wget -O oracle_java8.deb debian.opennms.org/dists/opennms-23/main/binary-all/oracle-java8-installer_8u131-1~webupd8~2_all.deb && \\
    dpkg -i oracle_java8.deb || echo "ok" && apt-get -f install -yq \\
; fi
EOF
fi

## Fender-specific items ##

echo "RUN apt-get install -y zip unzip rsync parallel tar jq wget curl vim less htop apt-transport-https groff"

# Install Python
# default 3.5.2
echo "RUN apt-get install -y software-properties-common python-software-properties libffi-dev python3-dev netcat"

echo "ENV PYENV_ROOT /opt/circleci/.pyenv"
echo "ENV PATH $PYENV_ROOT/bin/shims:$PYENV_ROOT/bin:$PATH"
echo "RUN curl -fsSL https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash"
echo "RUN echo 'export PYENV_ROOT=\"/opt/circleci/.pyenv\"'                         >> ~/.bashrc"
echo "RUN echo 'export PATH=\"\$PYENV_ROOT/bin:\$PYENV_ROOT/bin/shims:\$PATH\"'     >> ~/.bashrc"
echo "RUN echo 'eval \"\$(pyenv init -)\"'                                          >> ~/.bashrc"
echo "RUN echo 'eval \"\$(pyenv virtualenv-init -)\"'                               >> ~/.bashrc"
echo "RUN cat ~/.bashrc"
echo "RUN bash -i -c \"source ~/.bashrc\""

for PYTHON_VERSION in $PYTHON_VERSION_NUM
    do
      echo "RUN pyenv install $PYTHON_VERSION \
            && rm -rf /tmp/*"
    done

DEFAULT_PYTHON_VERSION=$(echo $PYTHON_VERSION_NUM | cut -d" " -f1)

echo "RUN pyenv global $DEFAULT_PYTHON_VERSION"
echo "RUN pip install -U pip"

# Install Ansible
echo "RUN pip install 'PyYAML==3.12'  --ignore-installed \
    && pip install awscli simplejson boto boto3 botocore six 'cryptography>=2.5' 'ansible==2.8.6' google_compute_engine \
    && rm -rf /tmp/*"

# Install Golang
echo "RUN export GOPATH=\"/root/gowork$GOVERS\" && \
export GOROOT=\"/usr/local/go$GOVERS\" && \
wget https://storage.googleapis.com/golang/go$GOVERS.linux-amd64.tar.gz && \
tar -xzf go$GOVERS.linux-amd64.tar.gz && \
mv go /usr/local/go$GOVERS && \
rm go$GOVERS.linux-amd64.tar.gz && \
mkdir gowork$GOVERS && \
export PATH=\"/usr/local/go$GOVERS/bin:$PATH\" && \
go get golang.org/x/tools/cmd/cover && \
go get github.com/mattn/goveralls && \
wget -q -O honeymarker https://honeycomb.io/download/honeymarker/linux/1.9 && \
  echo 'e74514a2baaf63a5828ff62ca2ca1aa86b3a4ab223ab6a7c53f969d7b55e37fb  honeymarker' | sha256sum -c && \
  chmod 755 ./honeymarker && \
  mv honeymarker /usr/bin"

# Install latest version of Terraform
echo "RUN git clone https://github.com/kamatama41/tfenv.git /root/.tfenv && \
export PATH=\"/root/.tfenv/bin:$PATH\" && \
tfenv install latest:$TF_VERSION_REGEX"

# Install Terraform linters
# Install tflint
echo "RUN curl https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash"

# Install terraform-compliance
echo "RUN pyenv global 3.8.5 && \
pip install terraform-compliance && \
pyenv global $DEFAULT_PYTHON_VERSION"

# Install tfsec
echo "RUN wget https://github.com/tfsec/tfsec/releases/download/$TFSEC_VERSION/tfsec-linux-amd64 -O /root/.tfenv/bin/tfsec && \
chmod +x /root/.tfenv/bin/tfsec"

# Install local DynamoDB
echo "RUN mkdir /root/DynamoDBLocal && \
wget https://s3-us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_latest.tar.gz -P /root/DynamoDBLocal/ && \
tar -xvf /root/DynamoDBLocal/dynamodb_local_latest.tar.gz -C /root/DynamoDBLocal/"

# Install local Elasticsearch
echo "RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - && \
apt-get -y install apt-transport-https && \
echo 'deb https://artifacts.elastic.co/packages/5.x/apt stable main' | tee -a /etc/apt/sources.list.d/elastic-5.x.list && \
apt-get update && apt-get -y install elasticsearch=5.5.3 && \
/usr/share/elasticsearch/bin/elasticsearch-plugin install analysis-icu"

# Install additional end2end-related items
echo "RUN pip install sh && \
apt-get -y install postgresql postgresql-contrib && \
mkdir -p /usr/local/pgsql/data && \
chown -R postgres:postgres /usr/local/pgsql && \
su -c '/usr/lib/postgresql/9.5/bin/initdb -D /usr/local/pgsql/data' postgres"

## END Fender-specific items ##

# if [ ! -e $PHP_VERSION_NUM ] ; then
#     wget "http://php.net/distributions/php-${PHP_VERSION_NUM}.tar.xz"
# fi

if [ $MYSQL_CLIENT = "true" ] ; then
    echo "RUN apt-get -y install mysql-client"
fi

if [ $POSTGRES_CLIENT = "true" ] ; then
    echo "RUN apt-get -y install postgresql-client"
fi

if [ $DOCKERIZE = "true" ] ; then
DOCKERIZE_VERSION="v0.6.1"

cat << EOF
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz && \\
    tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz && \\
    rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz
EOF
fi

# install bats for testing
echo "RUN git clone https://github.com/sstephenson/bats.git \
  && cd bats \
  && ./install.sh /usr/local \
  && cd .. \
  && rm -rf bats"

# install dependencies for tap-to-junit
echo "RUN perl -MCPAN -e 'install TAP::Parser'"
echo "RUN perl -MCPAN -e 'install XML::Generator'"

# install lsb-release, etc., for testing linux distro
echo "RUN apt-get update && apt-get -y install lsb-release unzip"

if [ $BROWSERS = "true" ] ; then
cat << EOF
RUN if [ \$(grep 'VERSION_ID="8"' /etc/os-release) ] ; then \\
    echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list && \\
    apt-get update && apt-get -y install -t jessie-backports xvfb phantomjs \\
; else \\
		apt-get update && apt-get -y install xvfb phantomjs \\
; fi
EOF
echo "ENV DISPLAY :99"

echo "# install firefox
RUN curl --silent --show-error --location --fail --retry 3 --output /tmp/firefox.deb https://s3.amazonaws.com/circle-downloads/firefox-mozilla-build_47.0.1-0ubuntu1_amd64.deb \
  && echo 'ef016febe5ec4eaf7d455a34579834bcde7703cb0818c80044f4d148df8473bb  /tmp/firefox.deb' | sha256sum -c \
  && dpkg -i /tmp/firefox.deb || apt-get -f install  \
  && apt-get install -y libgtk3.0-cil-dev libasound2 libasound2 libdbus-glib-1-2 libdbus-1-3 \
  && rm -rf /tmp/firefox.deb"

echo "# install chrome
RUN curl --silent --show-error --location --fail --retry 3 --output /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
  && (dpkg -i /tmp/google-chrome-stable_current_amd64.deb || apt-get -fy install)  \
  && rm -rf /tmp/google-chrome-stable_current_amd64.deb \
  && sed -i 's|HERE/chrome\"|HERE/chrome\" --disable-setuid-sandbox --no-sandbox|g' \
       \"/opt/google/chrome/google-chrome\""

echo "# install chromedriver
RUN apt-get -y install libgconf-2-4 \
  && curl --silent --show-error --location --fail --retry 3 --output /tmp/chromedriver_linux64.zip \"http://chromedriver.storage.googleapis.com/2.33/chromedriver_linux64.zip\" \
  && cd /tmp \
  && unzip chromedriver_linux64.zip \
  && rm -rf chromedriver_linux64.zip \
  && mv chromedriver /usr/local/bin/chromedriver \
  && chmod +x /usr/local/bin/chromedriver"
fi
