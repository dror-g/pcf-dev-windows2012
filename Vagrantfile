# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "windows2012r2"

  config.vm.synced_folder ".", "/vagrant", disabled: true

  pcfdev_public_ip = ENV["PCFDEV_IP"] || "192.168.11.11"
  local_public_ip = ENV["WIN_PCFDEV_IP"] || "192.168.11.12"

  config.vm.network "private_network", ip: local_public_ip

  config.vm.provision "shell", run: "once" do |s|
    s.inline = <<-SCRIPT
      # Start and configure the Windows Time service to use a public NTP server
      Start-Service w32time
      Set-Service w32time -startuptype "automatic"
      W32tm /config /manualpeerlist:pool.ntp.org /syncfromflags:MANUAL
      W32tm /config /update

      # Download and run the Windows setup.ps1 script
      (New-Object System.Net.WebClient).DownloadFile('https://github.com/cloudfoundry/garden-windows-release/releases/download/v0.119/setup.ps1', 'C:/Windows/Temp/setup.ps1')
      powershell.exe -File C:/Windows/Temp/setup.ps1 -quiet

      # Download and install Diego
      (New-Object System.Net.WebClient).DownloadFile('https://github.com/cloudfoundry/diego-windows-release/releases/download/v0.331/DiegoWindows.msi', 'C:/Windows/Temp/DiegoWindows.msi')
      msiexec /passive /norestart /i C:\\Windows\\Temp\\DiegoWindows.msi CONSUL_IPS=#{pcfdev_public_ip} CF_ETCD_CLUSTER=http://#{pcfdev_public_ip}:4001 STACK=windows2012R2 REDUNDANCY_ZONE=windows LOGGREGATOR_SHARED_SECRET=loggregator-secret MACHINE_IP=#{local_public_ip} /log C:\\Windows\\Temp\\diegowindows.log

      # Download and install Garden
      (New-Object System.Net.WebClient).DownloadFile('https://github.com/cloudfoundry/garden-windows-release/releases/download/v0.119/GardenWindows.msi', 'C:/Windows/Temp/GardenWindows.msi')
      msiexec /passive /norestart /i C:\\Windows\\Temp\\GardenWindows.msi ADMIN_USERNAME=vagrant ADMIN_PASSWORD="""vagrant""" MACHINE_IP=#{local_public_ip} /log C:\\Windows\\Temp\\gardenwindows.log

      # Replace the Diego installed rep.exe with our special forked version
      Stop-Service RepService
      (New-Object System.Net.WebClient).DownloadFile('https://github.com/sneal/rep/releases/download/NAT/rep.exe', 'C:/Program Files/CloudFoundry/DiegoWindows/rep.exe')
      Start-Service RepService

    SCRIPT
  end
end
