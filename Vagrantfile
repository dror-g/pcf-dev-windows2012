# -*- mode: ruby -*-
# vi: set ft=ruby :

#pcfdev_public_ip = ENV["PCFDEV_IP"] || "192.168.11.11"
#local_public_ip = ENV["WIN_PCFDEV_IP"] || "192.168.11.12"
pcfdev_public_ip = ENV["PCFDEV_IP"] || "192.168.50.4"
local_public_ip = ENV["WIN_PCFDEV_IP"] || "192.168.50.5"

module OS
  def OS.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end
end

# Configure the PCFDev instance to support a Windows cell
#
# 1. Grab the Consul certs and keys
# 2. Reconfigure all services to bind to the host only adapter
# 3. Add a windows2012R2 PCF stack
if ARGV[0] == 'up' then
    if OS.windows? then
          puts "Windows detected, running cmd script."
          system("update_pcfdev_vm.cmd #{pcfdev_public_ip}")
    else
      puts "Overriden: Non-Windows detected, running shell script."
      #system("./update_pcfdev_vm.sh #{pcfdev_public_ip}")
    end
end

Vagrant.configure(2) do |config|
  config.vm.box = "mwrock/Windows2012R2"
  config.vm.network "private_network", ip: local_public_ip
  config.vm.provider "virtualbox" do |v|
    #v.customize ["modifyvm", :id, "--memory", 2048]
    #v.customize ["modifyvm", :id, "--cpus", 2]
    v.gui = false
    v.customize ["modifyvm", :id, "--memory", 31232]
    v.customize ["modifyvm", :id, "--cpus", 4]
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

      Download-File 'https://github.com/cloudfoundry/diego-windows-release/releases/download/v0.457/DiegoWindows.msi' 'C:/Windows/Temp/DiegoWindows.msi'
      Download-File 'https://github.com/cloudfoundry/diego-windows-release/releases/download/v0.457/generate.exe' 'C:/Windows/Temp/generate.exe'
      Download-File 'https://github.com/cloudfoundry/garden-windows-release/releases/download/v0.169/setup.ps1' 'C:/Windows/Temp/setup.ps1'
      Download-File 'https://github.com/cloudfoundry/garden-windows-release/releases/download/v0.169/GardenWindows.msi' 'C:/Windows/Temp/GardenWindows.msi'
      Write-Output "Executing setup.ps1 script"
      powershell.exe -File C:/Windows/Temp/setup.ps1 -quiet
      if ($LastExitCode -ne 0) {
        Write-Output "setup.ps1 failed"
        exit 1
      }

      C:/Windows/Temp/generate.exe -outputDir=C:/Windows/Temp -boshUrl=https://admin:admin@192.168.50.4:25555 -machineIp="192.168.50.5"
      if ($LastExitCode -ne 0) {
        Write-Output "!!!!generate.exe failed!!!!!!"
        exit 1
      }

      powershell.exe Add-Content C:/Windows/Temp/install.bat ".168.50.5"
      C:/Windows/Temp/install.bat
      if ($LastExitCode -ne 0) {
        Write-Output "!!!!install.bat failed!!!!!!"
        exit 1
      }

      powershell.exe  Write-Output "10.244.16.2 bbs.service.cf.internal" | Add-Content C:/Windows/System32/drivers/etc/hosts -Encoding Default
      powershell.exe  Write-Output "10.244.0.130 blobstore.service.cf.internal" | Add-Content C:/Windows/System32/drivers/etc/hosts -Encoding Default
      if ($LastExitCode -ne 0) {
        Write-Output "!!!!install hosts file failed!!!!!!"
        exit 1
      }

      #Write-Output "Installing DiegoWindows"
      #msiexec /passive /norestart /i C:\\Windows\\Temp\\DiegoWindows.msi CONSUL_IPS=#{pcfdev_public_ip} CONSUL_DOMAIN=cf.internal CF_ETCD_CLUSTER=http://#{pcfdev_public_ip}:4001 STACK=windows2012R2 REDUNDANCY_ZONE=windows LOGGREGATOR_SHARED_SECRET=loggregator-secret MACHINE_IP=#{local_public_ip} CONSUL_ENCRYPT_FILE=C:\\vagrant\\consul_encrypt.key CONSUL_CA_FILE=C:\\vagrant\\consul_ca.crt CONSUL_AGENT_CERT_FILE=C:\\vagrant\\consul_agent.crt CONSUL_AGENT_KEY_FILE=C:\\vagrant\\consul_agent.key /log C:\\Windows\\Temp\\diegowindows.log

      #Write-Output "Installing GardenWindows"
      #msiexec /passive /norestart /i C:\\Windows\\Temp\\GardenWindows.msi MACHINE_IP=#{local_public_ip} /log C:\\Windows\\Temp\\gardenwindows.log

      # Replace the Diego installed rep.exe and RepService.exe with our special forked version
      # which supports a configurable listenAddr via MACHINE_IP
      #Service-Stop 'CF Rep'
      #Download-File 'https://github.com/sneal/rep/releases/download/NAT/rep.exe' 'C:/Program Files/CloudFoundry/DiegoWindows/rep.exe'
      #Download-File 'https://github.com/sneal/diego-windows-release/releases/download/NAT/RepService.exe' 'C:/Program Files/CloudFoundry/DiegoWindows/RepService.exe'
      #Service-Start 'CF Rep'

      # Ensure all the CloudFoundry Windows services are installed and running
      Check-Service-Running "CF Consul"
      Check-Service-Running "CF Containerizer"
      Check-Service-Running "CF GardenWindows"
      Check-Service-Running "CF Metron"
      Check-Service-Running "CF Rep"
    SCRIPT
  end
end
