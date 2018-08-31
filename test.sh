#!/bin/bash
set -eux

# Prepare env vars
OS=${OS:="centos"}
OS_VERSION=${OS_VERSION:="6"}
PYTHON_VERSION=${PYTHON_VERSION:="2"}
IMAGE="$OS:$OS_VERSION"
docker_mounts="-v $PWD:$PWD:z"
for dir in ${EXTRA_MOUNT:-}; do
  docker_mounts="${docker_mounts} -v $dir:$dir:z"
done

# Pull fedora images from registry.fedoraproject.org
if [[ $OS == "fedora" ]]; then
  IMAGE="registry.fedoraproject.org/$IMAGE"
fi


CONTAINER_NAME="osbs-client-$OS-$OS_VERSION-py$PYTHON_VERSION"
RUN="docker exec -ti $CONTAINER_NAME"
if [[ $OS == "fedora" ]]; then
  PIP_PKG="python$PYTHON_VERSION-pip"
  PIP="pip$PYTHON_VERSION"
  PKG="dnf"
  PKG_EXTRA="dnf-plugins-core"
  BUILDDEP="dnf builddep"
  PYTHON="python$PYTHON_VERSION"
else
  PIP_PKG="python-pip"
  PIP="pip"
  PKG="yum"
  PKG_EXTRA="yum-utils epel-release"
  BUILDDEP="yum-builddep"
  PYTHON="python"
fi
# Create or resurrect container if needed
if [[ $(docker ps -qa -f name=$CONTAINER_NAME | wc -l) -eq 0 ]]; then
  docker run --name $CONTAINER_NAME -d $docker_mounts -w $PWD -ti $IMAGE sleep infinity
elif [[ $(docker ps -q -f name=$CONTAINER_NAME | wc -l) -eq 0 ]]; then
  echo found stopped existing container, restarting. volume mounts cannot be updated.
  docker container start $CONTAINER_NAME
fi

# Install dependencies
$RUN $PKG install -y $PKG_EXTRA
$RUN $BUILDDEP -y osbs-client.spec
if [[ $OS != "fedora" ]]; then
  # Install dependecies for test, as check is disabled for rhel
  $RUN yum install -y python-flexmock python-six python-dockerfile-parse python-requests python-requests-kerberos
fi

# Install package
$RUN $PKG install -y $PIP_PKG
if [[ $PYTHON_VERSION == 3 ]]; then
  # https://fedoraproject.org/wiki/Changes/Making_sudo_pip_safe
  $RUN mkdir -p /usr/local/lib/python3.6/site-packages/
fi
$RUN $PYTHON setup.py install

# py >= 1.6.0 (py is a pytest dependency) is incompatible with Python 2.6
VERSIONED_PY=
if [[ $OS != "fedora" && $OS_VERSION == '6' ]] ; then
    VERSIONED_PY="py==1.5.4"
fi

$RUN $PIP install -r tests/requirements.txt $VERSIONED_PY

# CentOS needs to have setuptools updates to make pytest-cov work
if [[ $OS != "fedora" ]]; then
  if [[ $OS_VERSION != '6' ]] ; then
      $RUN $PIP install -U setuptools
  else
      # setuptools 40.0 is incompatible with Python 2.6 because of this change
      # https://github.com/pypa/setuptools/commit/7392f0#diff-c6950cefad8b244938b76f24a0db9a6aR51
      $RUN $PIP install -U setuptools==39.2.0
  fi

  # Watch out for https://github.com/pypa/setuptools/issues/937
  $RUN curl -O https://bootstrap.pypa.io/2.6/get-pip.py
  $RUN $PYTHON get-pip.py
fi
if [[ $PYTHON_VERSION -gt 2 ]]; then $RUN $PIP install -r requirements-py3.txt; fi

# Run tests
$RUN py.test --cov osbs --cov-report html -vv tests "$@"

echo "To run tests again:"
echo "$RUN py.test --cov osbs --cov-report html -vv tests"
