# -*- mode: ruby -*-
# vi: set ft=ruby :

pcfdev_public_ip = ENV["PCFDEV_IP"] || "192.168.11.11"
local_public_ip = ENV["WIN_PCFDEV_IP"] || "192.168.11.12"

# Configure the PCFDev instance to support a Windows cell
#
# 1. Grab the Consul certs and keys
# 2. Reconfigure all services to bind to the host only adapter
# 3. Add a windows2012R2 PCF stack
script = <<-SCRIPT
cf pcfdev start
ssh -i ~/.vagrant.d/insecure_private_key vagrant@#{pcfdev_public_ip} "sudo ruby -e \\\"require 'json'; e = JSON.parse(IO.read('/var/vcap/jobs/consul_agent/config/config.json'))['encrypt']; IO.write('/var/vcap/jobs/consul_agent/config/certs/consul_encrypt.key', e)\\\""
scp -i ~/.vagrant.d/insecure_private_key vagrant@#{pcfdev_public_ip}:/var/vcap/jobs/consul_agent/config/certs/consul_encrypt.key consul_encrypt.key
scp -i ~/.vagrant.d/insecure_private_key vagrant@#{pcfdev_public_ip}:/var/vcap/jobs/consul_agent/config/certs/ca.crt consul_ca.crt
scp -i ~/.vagrant.d/insecure_private_key vagrant@#{pcfdev_public_ip}:/var/vcap/jobs/consul_agent/config/certs/agent.crt consul_agent.crt
scp -i ~/.vagrant.d/insecure_private_key vagrant@#{pcfdev_public_ip}:/var/vcap/jobs/consul_agent/config/certs/agent.key consul_agent.key
ssh -i ~/.vagrant.d/insecure_private_key vagrant@#{pcfdev_public_ip} "sudo sed -i.bak \\\"s#^ip=.*#ip=\\\\\\$(ifconfig eth1 | awk -F ' *|:' '/inet addr/{print \\\\\\$4}')#g\\\" /var/pcfdev/run"
ssh -i ~/.vagrant.d/insecure_private_key vagrant@#{pcfdev_public_ip} "echo -e \\\"default: cflinuxfs2\\\\\\nstacks:\\\\\\n- description: Cloud Foundry Linux-based filesystem\\\\\\n  name: cflinuxfs2\\\\\\n- description: Windows Server 2012 R2\\\\\\n  name: windows2012R2\\\" | sudo tee /var/vcap/jobs/cloud_controller_ng/config/stacks.yml"
cf pcfdev stop && cf pcfdev start
SCRIPT
system(script) if ARGV[0] == 'up'

Vagrant.configure(2) do |config|
  config.vm.box = "mwrock/Windows2012R2"
  config.vm.network "private_network", ip: local_public_ip
  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--memory", 2048]
    v.customize ["modifyvm", :id, "--cpus", 2]
  end

  # Ensure UAC is disabled so the MSI installers run non-interactively
  config.vm.provision "shell", run: "always" do |s|
    s.inline = <<-SCRIPT
      if ((Get-ItemProperty HKLM:Software/Microsoft/Windows/CurrentVersion/policies/system).EnableLUA -ne 0) {
        New-ItemProperty -Path HKLM:Software/Microsoft/Windows/CurrentVersion/policies/system -Name EnableLUA -PropertyType DWord -Value 0 -Force
        shutdown /r /f /t 5
      }
    SCRIPT
  end

  # Install Windows Diego/Garden
  config.vm.provision "shell", run: "always" do |s|
    s.inline = <<-SCRIPT
      function Check-Service-Running($svcName) {
        Write-Output "Checking $svcName service is running"
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc.Status -ne "Running") {
          Write-Output "$svcName service is not started"
          exit 1
        }
      }

      function Download-File($src, $target, $retryCount=0) {
        Write-Output "Downloading $src"
        (New-Object System.Net.WebClient).DownloadFile($src, $target)
        if ($? -ne $true) {
          Write-Output "$src download failed"
          if ($retryCount -gt 3) {
            exit 1
          } else {
            Start-Sleep -s 5
            $retryCount = $retryCount + 1
            Download-File $src $target $retryCount
          }
        }
      }

      function Service-Stop($svc, $retryCount=0) {
        Write-Output "Stopping $svc"
        net stop $svc
        Start-Sleep -s 5
        if ($LastExitCode -ne 0) {
          Write-Output "Stop $svc failed"
          if ($retryCount -lt 3) {
            $retryCount = $retryCount + 1
            Service-Stop $svc $retryCount
          }
        }
      }

      function Service-Start($svc) {
        Write-Output "Starting $svc"
        Start-Service $svc
      }

      Write-Output "Starting and configuring Windows Time service"
      Service-Start 'w32time'
      Set-Service w32time -startuptype "automatic"
      W32tm /config /manualpeerlist:pool.ntp.org /syncfromflags:MANUAL
      W32tm /config /update

      Download-File 'https://github.com/cloudfoundry/garden-windows-release/releases/download/v0.149/setup.ps1' 'C:/Windows/Temp/setup.ps1'
      Write-Output "Executing setup.ps1 script"
      powershell.exe -File C:/Windows/Temp/setup.ps1 -quiet
      if ($LastExitCode -ne 0) {
        Write-Output "setup.ps1 failed"
        exit 1
      }

      Download-File 'https://github.com/cloudfoundry/diego-windows-release/releases/download/v0.400/DiegoWindows.msi' 'C:/Windows/Temp/DiegoWindows.msi'
      Write-Output "Installing DiegoWindows"
      msiexec /passive /norestart /i C:\\Windows\\Temp\\DiegoWindows.msi CONSUL_IPS=#{pcfdev_public_ip} CONSUL_DOMAIN=cf.internal CF_ETCD_CLUSTER=http://#{pcfdev_public_ip}:4001 STACK=windows2012R2 REDUNDANCY_ZONE=windows LOGGREGATOR_SHARED_SECRET=loggregator-secret MACHINE_IP=#{local_public_ip} CONSUL_ENCRYPT_FILE=C:\\vagrant\\consul_encrypt.key CONSUL_CA_FILE=C:\\vagrant\\consul_ca.crt CONSUL_AGENT_CERT_FILE=C:\\vagrant\\consul_agent.crt CONSUL_AGENT_KEY_FILE=C:\\vagrant\\consul_agent.key /log C:\\Windows\\Temp\\diegowindows.log

      Download-File 'https://github.com/cloudfoundry/garden-windows-release/releases/download/v0.149/GardenWindows.msi' 'C:/Windows/Temp/GardenWindows.msi'
      Write-Output "Installing GardenWindows"
      msiexec /passive /norestart /i C:\\Windows\\Temp\\GardenWindows.msi MACHINE_IP=#{local_public_ip} /log C:\\Windows\\Temp\\gardenwindows.log

      # Replace the Diego installed rep.exe and RepService.exe with our special forked version
      # which supports a configurable listenAddr via MACHINE_IP
      Service-Stop 'RepService'
      Download-File 'https://github.com/sneal/rep/releases/download/NAT/rep.exe' 'C:/Program Files/CloudFoundry/DiegoWindows/rep.exe'
      Download-File 'https://github.com/sneal/diego-windows-release/releases/download/NAT/RepService.exe' 'C:/Program Files/CloudFoundry/DiegoWindows/RepService.exe'
      Service-Start 'RepService'

      # Ensure all the CloudFoundry Windows services are installed and running
      Check-Service-Running "ConsulService"
      Check-Service-Running "ContainerizerService"
      Check-Service-Running "GardenWindowsService"
      Check-Service-Running "MetronService"
      Check-Service-Running "RepService"
    SCRIPT
  end
end
