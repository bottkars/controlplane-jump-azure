#!/usr/bin/env bash
source ~/.env.sh
cd ${HOME_DIR}

bosh upload-release --sha1 97410a92b3c2385b728a7414ad34520491701d4e \
  https://bosh.io/d/github.com/concourse/concourse-bosh-release?v=5.3.0


bosh upload-release --sha1 d04cc34547a6929b8eabbd0534891b0e60fd3309 \
  https://bosh.io/d/github.com/cloudfoundry/uaa-release?v=69.0

bosh upload-release --sha1 82e83a5e8ebd6e07f6ca0765e94eb69e03324a19 \
  https://bosh.io/d/github.com/cloudfoundry/bpm-release?v=1.1.0

bosh upload-release --sha1 b0d0a0350ed87f1ded58b2ebb469acea0e026ccc \
  https://bosh.io/d/github.com/cloudfoundry/bosh-dns-aliases-release?v=0.0.3

bosh upload-release --sha1 76810f5dd66d8320b344b3eca197c5b669a3a633 \
  https://bosh.io/d/github.com/cloudfoundry/garden-runc-release?v=1.19.3

bosh upload-release --sha1 2e08e5de86288f421fb7eff72a095adb78c31ea8 \
  https://bosh.io/d/github.com/pivotal-cf/credhub-release?v=2.4.0

bosh upload-release --sha1 56122002ce49af09b03b8c3a49bdb7578ee2868a \
  https://bosh.io/d/github.com/concourse/concourse-bosh-release?v=4.2.4

bosh upload-release --sha1 b6e8a9cbc8724edcecb8658fa9459ee6c8fc259e \
  https://bosh.io/d/github.com/cloudfoundry/uaa-release?v=73.3.0

bosh upload-release --sha1 23620deb20c34cefadff74c0e5bfdffaaea1a807 \
  https://bosh.io/d/github.com/cloudfoundry/postgres-release?v=38
bosh upload-stemcell --sha1 b20dca6641ab6bbf62e2265bc470ff3755c142d5 \
  https://bosh.io/d/stemcells/bosh-azure-hyperv-ubuntu-xenial-go_agent?v=315.45

bosh upload-release --sha1 efc10ac0f4acae23637ce2c6f864d20df2e3a781 \
  https://bosh.io/d/github.com/cloudfoundry-incubator/windows-utilities-release?v=0.11.0

bosh upload-release --sha1 aecb23d96247ff691c7313801add040d0741200d \
  https://bosh.io/d/github.com/cloudfoundry/windowsfs-online-release?v=1.7.0

bosh upload-release --sha1 f1d0ae10a48be36afae76a83526427330a40a737 \
  https://bosh.io/d/github.com/cloudfoundry-incubator/winc-release?v=1.14.0

bosh upload-release --sha1 1f70a862621b2d879277c0eee6147bb8bddda060 \
  https://bosh.io/d/github.com/cloudfoundry-incubator/garden-windows-bosh-release?v=0.16.0

bosh deploy -n -d control-plane ${HOME_DIR}/conductor/templates/control-plane-kb-5.yml \
   --vars-file=${HOME_DIR}/bosh-vars.yml \
   --ops-file=${HOME_DIR}/vm-extensions-control.yml \
   --vars-file=${HOME_DIR}/conductor/templates/versions.yml  