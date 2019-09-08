#!/usr/bin/env bash
source ~/.env.sh
cd ${HOME_DIR}

bosh upload-release https://bosh.io/d/github.com/concourse/concourse-bosh-release?v=5.5.0

bosh upload-release https://bosh.io/d/github.com/cloudfoundry/uaa-release?v=69.0

bosh upload-release https://bosh.io/d/github.com/cloudfoundry/bpm-release?v=1.1.3

bosh upload-release https://bosh.io/d/github.com/cloudfoundry/bosh-dns-aliases-release?v=0.0.3

bosh upload-release https://bosh.io/d/github.com/cloudfoundry/garden-runc-release?v=1.19.3

bosh upload-release https://bosh.io/d/github.com/pivotal-cf/credhub-release?v=2.5.4

bosh upload-release https://bosh.io/d/github.com/cloudfoundry/uaa-release?v=73.3.0
bosh upload-release https://bosh.io/d/github.com/cloudfoundry/postgres-release?v=39
bosh upload-stemcell https://bosh.io/d/stemcells/bosh-azure-hyperv-ubuntu-xenial-go_agent?v=315.89

bosh upload-release https://bosh.io/d/github.com/cloudfoundry-incubator/windows-utilities-release?v=0.11.0

bosh upload-release https://bosh.io/d/github.com/cloudfoundry/windowsfs-online-release?v=1.7.0

bosh upload-release https://bosh.io/d/github.com/cloudfoundry-incubator/winc-release?v=1.14.0

bosh upload-release https://bosh.io/d/github.com/cloudfoundry-incubator/garden-windows-bosh-release?v=0.16.0

bosh deploy -n -d control-plane ${HOME_DIR}/conductor/templates/control-plane-deployment-kb-5.yml \
   --vars-file=${HOME_DIR}/bosh-vars.yml \
   --ops-file=${HOME_DIR}/vm-extensions-control.yml \
   --vars-file=${HOME_DIR}/conductor/templates/versions.yml  