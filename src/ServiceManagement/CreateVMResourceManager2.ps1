#setup this session
$password = ConvertTo-SecureString -String "#####" -Force -AsPlainText
$username = "me@atmyord.org" #UPN for an Org account
$mycred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username,$password
Add-AzureAccount -Credential $mycred

Select-AzureSubscription -SubscriptionId "####"
Set-AzureSubscription -SubscriptionId "###"

# Switch to the Resource Manager mode   
Switch-AzureMode AzureResourceManager

# Set values for existing resource group and storage account names
$rgName="aatest"
$locName="West US"
$saName="aapremiumscicoria"

#Vnet creation ++
$singleSubnet=New-AzureVirtualNetworkSubnetConfig -Name singleSubnet -AddressPrefix 10.0.0.0/24
$vnet=New-AzurevirtualNetwork -Name TestNet -ResourceGroupName $rgName -Location $locName -AddressPrefix 10.0.0.0/16 -Subnet $singleSubnet


# Set the existing virtual network and subnet index
$vnetName="TestNet"
$subnetIndex=0
$vnet=Get-AzurevirtualNetwork -Name $vnetName -ResourceGroupName $rgName

#create AS
$avName="ES_AS"
$as = New-AzureAvailabilitySet -ResourceGroupName $rgName -Name $avName -Location $locName -PlatformUpdateDomainCount 5 -PlatformFaultDomainCount 2 


# Create the NIC
$nicName="AzureInterface"
$domName="contoso-vm-lob07"
$pip=New-AzurePublicIpAddress -Name $nicName -ResourceGroupName $rgName -DomainNameLabel $domName -Location $locName -AllocationMethod Dynamic
$nic=New-AzureNetworkInterface -Name $nicName -ResourceGroupName $rgName -Location $locName -SubnetId $vnet.Subnets[$subnetIndex].Id -PublicIpAddressId $pip.Id

# Specify the name, size, and existing availability set
$vmName="LOB07"
$vmSize="Standard_DS2"
$avName="ES_AS"
$avSet=Get-AzureAvailabilitySet –Name $avName –ResourceGroupName $rgName
$vm=New-AzureVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetId $avset.Id

# Add a 200 GB additional data disk
$diskSize=128
$diskLabel="APPStorage"
$diskName=$vmname + "_21050529-DISK02"
$storageAcc=Get-AzureStorageAccount -ResourceGroupName $rgName -Name $saName
$vhdURI=$storageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName + $diskName  + ".vhd"
Add-AzureVMDataDisk -VM $vm -Name $diskLabel -DiskSizeInGB $diskSize -VhdUri $vhdURI -CreateOption empty

# Specify the image and local administrator account, and then add the NIC
$pubName="MicrosoftWindowsServer"
$offerName="WindowsServer"
$skuName="2012-R2-Datacenter"
$cred=Get-Credential -Message "Type the name and password of the local administrator account." 
$vm=Set-AzureVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$vm=Set-AzureVMSourceImage -VM $vm -PublisherName $pubName -Offer $offerName -Skus $skuName -Version "latest"
$vm=Add-AzureVMNetworkInterface -VM $vm -Id $nic.Id

# Specify the OS disk name and create the VM
$diskName="OSDisk"
$storageAcc=Get-AzureStorageAccount -ResourceGroupName $rgName -Name $saName
$osDiskUri=$storageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName + $diskName  + ".vhd"
$vm=Set-AzureVMOSDisk -VM $vm -Name $diskName -VhdUri $osDiskUri -CreateOption fromImage
New-AzureVM -ResourceGroupName $rgName -Location $locName -VM $vm


