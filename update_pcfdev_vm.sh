#!/bin/bash

pcfdev_public_ip="$1"
echo "Starting pcf dev at $pcfdev_public_ip"
cf dev start
ssh -i ~/.vagrant.d/insecure_private_key vagrant@$pcfdev_public_ip "sudo ruby -e \"require 'json'; e = JSON.parse(IO.read('/var/vcap/jobs/consul_agent/config/config.json'))['encrypt']; IO.write('/var/vcap/jobs/consul_agent/config/certs/consul_encrypt.key', e)\""
scp -i ~/.vagrant.d/insecure_private_key vagrant@$pcfdev_public_ip:/var/vcap/jobs/consul_agent/config/certs/consul_encrypt.key consul_encrypt.key
scp -i ~/.vagrant.d/insecure_private_key vagrant@$pcfdev_public_ip:/var/vcap/jobs/consul_agent/config/certs/ca.crt consul_ca.crt
scp -i ~/.vagrant.d/insecure_private_key vagrant@$pcfdev_public_ip:/var/vcap/jobs/consul_agent/config/certs/agent.crt consul_agent.crt
scp -i ~/.vagrant.d/insecure_private_key vagrant@$pcfdev_public_ip:/var/vcap/jobs/consul_agent/config/certs/agent.key consul_agent.key
ssh -i ~/.vagrant.d/insecure_private_key vagrant@$pcfdev_public_ip "sudo sed -i.bak \"s#^ip=.*#ip=\$(sudo ifconfig eth1 | awk -F ' *|:' '/inet addr/{print \$4}')#g\" /var/pcfdev/run"
ssh -i ~/.vagrant.d/insecure_private_key vagrant@$pcfdev_public_ip "echo -e \"default: cflinuxfs2\\nstacks:\\n- description: Cloud Foundry Linux-based filesystem\\n  name: cflinuxfs2\\n- description: Windows Server 2012 R2\\n  name: windows2012R2\" | sudo tee /var/vcap/jobs/cloud_controller_ng/config/stacks.yml"
echo "Restarting pcf dev"
cf dev stop && cf dev start
